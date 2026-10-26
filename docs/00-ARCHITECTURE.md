# uports Architecture And Design Goals

## 1. Purpose And Status

uports aims to provide a reproducible software development and package-building
workspace. It combines FreeBSD-style port declarations and lifecycle phases
with Git-managed source worktrees and project-level build orchestration.

Package production and active software development are both primary uses.
A developer should be able to acquire upstream source, apply maintained
patches, edit and test the result, export changes, and produce an installable
package through one coherent workflow.

This document records that overall direction and provides a place for further
architecture discussion. It does not claim that every proposed operation is
already implemented. Phase-specific interfaces, algorithms, compatibility
rules, and implementation checklists remain in their own reports. Live status
and verification evidence belong in `../HANDOFF.md`.

## 2. Core Design Principles

1. Follow FreeBSD Ports declarations, lifecycle concepts, names, and defaults
   first; add uports extensions for development and project requirements.
2. Separate source acquisition from source worktree management. A release
   archive is a valid input to a Git-managed development workspace.
3. Preserve developer work. Routine build operations must not discard edits,
   reset branches, or replace existing development worktrees.
4. Keep port intent separate from project policy. Ports describe how software
   can be obtained and built; projects select instances and build policy.
5. Make identities and transitions inspectable: source revision, applied
   patches, build profile, dependency providers, and produced artifacts.
6. Reuse artifacts only when the available identity evidence justifies reuse.
   Failed operations must not advance the last successful recorded state.
7. Prefer explicit, reviewable source updates and patch maintenance over
   hidden network updates or automatic mutation of developer work.

## 3. A Common Git Worktree Model

The central development workflow is:

```text
Source acquisition             Worktree preparation          Development

release archive -> extract ----> initialize Git baseline --+
                                                         |
upstream Git ----> checkout ---> retain upstream history --+
                                                         |
                                                         v
                                              apply maintained patches
                                                         |
                                                         v
                                              edit -> build -> test
                                                         |
                                            +------------+------------+
                                            |                         |
                                            v                         v
                                      export patches          stage -> package
                                                                      |
                                                                      v
                                                                    install
```

The source backend describes transport and upstream identity. Git worktree
management provides the common interface for reviewing changes, applying
patches, and developing the software after materialization.

For an archive, the pristine extracted source can be committed as a local
baseline. That commit is not an upstream Git commit: the archive URL and
checksum remain the evidence for its upstream contents.

For a Git source, preserve the upstream repository identity and selected
commit. Branches may support development, but a branch name alone is not an
immutable source identity.

Git-based patch application is already part of uports. A uniform development
worktree contract and convenient patch export/refresh operations are design
goals whose detailed behavior must be specified and verified separately.

## 4. Source Forms And Lifecycle Boundaries

An archive and a checkout may represent the same release without containing
the same files. Release archives often include generated configure scripts,
documentation, or bootstrap outputs that upstream Git omits.

Source mode therefore affects more than the fetch URL. It may affect bootstrap
tools, patches, source layout, and the identity of build outputs. Mode selection
must be resolved before dependency planning and source preparation.

The conceptual phase responsibilities are:

| Responsibility | Architectural role |
| --- | --- |
| Fetch | Acquire/cache source inputs without silently modifying active development work |
| Extract/materialize | Create the selected source tree and establish its baseline |
| Bootstrap | Produce prerequisites missing from that source form using declared tools |
| Patch | Apply the maintained port patch series against a known baseline |
| Configure/build/test | Produce and verify artifacts for the selected build instance |
| Stage/package | Assemble a manifest-driven payload and record artifact provenance |
| Install/deinstall | Deploy or remove that payload in the selected destination root |

This table expresses ownership, not a replacement for existing target names
or hook ordering. Detailed lifecycle changes belong in the relevant reports.

## 5. Baselines, Patches, And Developer Changes

The workspace should distinguish:

- pristine upstream source: identified by archive checksum or upstream commit;
- maintained port changes: the reviewed patch series applied to that source;
- developer changes: subsequent local commits, tracked edits, and untracked work.

These are conceptual boundaries; branch names, references, and export commands
remain to be designed. Patch export must have an explicit base and scope so it
does not accidentally include the imported source tree, already maintained
patches, generated files, or unrelated developer edits.

A useful round trip is to develop a change in the managed worktree, export it
as a reviewed patch, add it to the port series, and reproduce it against a
fresh baseline. Updating upstream source and refreshing a patch series are
explicit operations with validation and recoverable failure behavior.

An ordinary rebuild must not reset the worktree. Until source-edit tracking is
specified and implemented, developers may need explicit rebuild/restage targets;
automatic detection of every dirty-source change is not an existing guarantee.

## 6. Ports, Projects, Groups, And Build Instances

Ports describe reusable software-building intent. A project selects ports from
the framework and feeds, then applies policy through groups and instance
settings. Dependency providers and lifecycle dispatch are resolved above the
individual port layer.

A group is a project-owned build profile and selection boundary, not a
different upstream package. Current groups already support differing build
environments and destination roots. The same port can participate in several
groups with separate build-instance identities.

This provides a foundation for development workflows: host tools, compiler
runtimes, application dependencies, and target-platform libraries can be built
under appropriate profiles within one project. Future source-mode policy can
use the same project/group/instance selection boundary rather than embedding
project-specific choices in each port.

Further discussion is needed before defining how source worktrees relate to
multiple build instances:

- Should groups share a pristine source cache only, or also a developer worktree?
- Which configurations require separate source trees for in-tree builds or
  conflicting patch sets?
- How should one edited worktree feed several out-of-tree builds safely?
- Where should group-specific source, dependency, toolchain, and install policy
  be declared and how should overrides be reported?
- How should cleanup distinguish disposable build output from developer-owned
  source work, especially with alternative source directories?

Sharing upstream downloads or mirror repositories does not imply that mutable
worktrees or build outputs can safely be shared. The group reports own these
decisions; this overview establishes the questions and ownership boundary.

## 7. Reproducibility And Artifact Identity

Development workflows permit changing and dirty source trees. Reproducible
package workflows require enough evidence to identify the actual inputs.
A clean upstream commit alone does not identify a dirty worktree's contents.

The architecture should connect source identity, maintained patches, group
profile, relevant build settings, and dependency providers to artifact reuse.
In particular, switching archive/Git mode or changing the selected source
revision must not reuse incompatible configure/build cookies or binary packages.
Source-identity integration is proposed work; existing dependency-state and
archive-provenance checks cover the inputs currently represented by that system.

Distinfo verifies archive inputs. Dependency state and PVER 2 provenance record
dependency/build identity and support cache decisions. Git history supports
source review and patch maintenance. These mechanisms complement one another;
none alone proves that a binary was built correctly or passed runtime tests.

Dirty-tree package policy and the representation of local changes require
further design. Avoid recording volatile cache paths or fetch timestamps as
if they changed source contents.

## 8. Phase Reports And Implementation Plans

Keep this document focused on goals, boundaries, and relationships. Maintain
the detailed design in the relevant reports:

| Topic | Report |
| --- | --- |
| Source acquisition, hosted archives, SCM, and worktree safety | [01-FETCH.md](01-FETCH.md) |
| Fetch implementation slices and acceptance gates | [01-FETCH-TASKS.md](01-FETCH-TASKS.md) |
| Patch application and patch maintenance | [03-PATCH.md](03-PATCH.md) |
| Configuration behavior | [04-CONFIGURE.md](04-CONFIGURE.md) |
| Installation and package manifests | [08-INSTALL.md](08-INSTALL.md) |
| Project groups and build-instance architecture | [10.1-GROUP.md](10.1-GROUP.md) |
| Project tools and orchestration | [10.2-TOOLS.md](10.2-TOOLS.md) |
| Group design discussion | [10.3-GROUP-DISCUSSION.md](10.3-GROUP-DISCUSSION.md) |
| Dependency policy, state, execution, and provenance | [10.4-DEPENDENCY.md](10.4-DEPENDENCY.md) |

Add separate reports for other lifecycle topics when their design needs them;
do not turn this overview into a combined fetch/patch/build/install specification.
Implementation checklists should reference the responsible design and remain
separate from architectural goals.

## 9. Topics For Further Discussion

The next architecture discussions should address group support for development
workspaces, mutable worktree ownership, patch export/refresh, source-change
tracking, and the boundary between development and reproducible packaging.

Resolve each topic with concrete workflows, compatibility constraints, and
verification criteria before adopting new commands or changing defaults.
