# uports Fetch Architecture

## 1. Scope And Status

This document defines the fetch architecture and its migration contract.
Implementation tasks and verification gates are tracked separately in
[01-FETCH-TASKS.md](01-FETCH-TASKS.md). Proposed interfaces below are not
claims that the current framework already implements them.

Current uports supports archive fetching, grouped distfiles and patchfiles,
distinfo generation/verification, and raw Git through `USE_SCM=git`, including
mirror caches and submodule preparation. FreeBSD-style shorthand expansion,
`USE_GITHUB`, the new source selector, and the consolidated fetch script are
migration work. Preserve existing ports until each replacement is validated.

The FreeBSD reference checkout is `/home/lyc/pj/08-OSS/freebsd-ports`.
Relevant sources are `Mk/bsd.sites.mk`, the fetch sections of `Mk/bsd.port.mk`,
and `Mk/Scripts/do-fetch.sh` with its required `functions.sh` helpers.
Record the reference revision when importing behavior and retain applicable
attribution/license notices.

## 2. Ownership And Source Model

Follow FreeBSD archive semantics first, with SCM as a first-class uports
extension for development and source trees that require Git.

- Ports declare available archives, repositories, revisions, and bootstrap needs.
- Projects choose source mode through make/environment settings and group or
  instance environment overlays.
- The framework normalizes declarations and dispatches the selected backend.
- Explicit operator commands control updates to development worktrees.

Archive builds are useful for checksum-verified package production; Git builds
provide history, branches, submodules, and editable worktrees. Neither mode
should require a second independent copy of the same repository metadata.
Release archives and repository snapshots can have different generated files
and bootstrap requirements, so equivalence must be tested per port.

Proposed flow:

```text
Port declarations + project policy
               |
               v
Normalized source records
  kind, identity, URL, revision, cache key, source root, placement, bootstrap
               |
        +------+-------+
        |              |
   SOURCE_MODE=dist  SOURCE_MODE=git
        |              |
   mirror/archive   mirror repository + checkout
   fetch script     SCM backend
        |              |
   checksum/extract  verify commit/submodules
        +------+-------+
               |
       selected WRKSRC
               |
       bootstrap -> patch -> configure -> build
```

Internal source records are separate from package-dependency records. Document
their schema before implementation; preserve deterministic grouping and order.
The slice 1 logical schema and legacy baseline are recorded in
[01-FETCH-CONTRACT.md](01-FETCH-CONTRACT.md); serialization is not implemented.

## 3. Source Selection And Compatibility

Proposed public selector:

```make
SOURCE_MODE = dist  # archive distfiles, including hosted-repository archives
SOURCE_MODE = git   # raw Git checkout
```

`github` and `gitlab` identify archive helpers, not additional source modes.
Other SCM backends can be added later with explicit contracts.

Selection precedence:

1. An explicitly selected `SOURCE_MODE` controls the backend.
2. If it is absent, existing `USE_SCM=git` selects Git for compatibility.
3. Otherwise the framework default is `dist`.

Ordinary GNU make precedence still applies to project/environment assignments;
the framework must not use `override` to defeat command-line policy.
Unsupported modes or unavailable declarations fail clearly. A failed archive
download must not silently switch to Git, or vice versa.

Keep existing `USE_SCM`, `SCM_REPO_URL`, `SCM_DETACH`, `SCM_BRANCH`, cache,
and submodule behavior during migration. New declarations should not rewrite
`MASTER_SITES` conditionally to represent a Git host.

The earlier `USE_GIT=yes` proposal is deferred: a repository declaration plus
`SOURCE_MODE=git` is sufficient. Do not introduce another public switch unless
a concrete requirement needs it. Existing `USES=git:ownership` remains a
separate worktree helper.

## 4. FreeBSD Archive And Mirror Compatibility

Preserve `MASTER_SITES`, `DISTFILES`, `PATCH_SITES`, `PATCHFILES`, `DISTNAME`,
`EXTRACT_SUFX`, and their documented defaults.

| Interface | Required behavior |
| --- | --- |
| `MASTER_SITE_<family>` | Mirror templates from the maintained sites catalog |
| `MASTER_SITES` | Full URLs, family names, abbreviations, and family/path shorthand |
| `MASTER_SITE_SUBDIR` | Remote `%SUBDIR%` substitution, including group-specific paths |
| `DIST_SUBDIR` | Local cache namespace and distinfo key prefix; not the remote path |
| Named groups | Distfile-to-mirror association, comma-separated groups, implicit `DEFAULT` |
| Overrides/backups | Overrides first, selected mirrors next, backups last |
| Patch sources | Same grouping/expansion model, independently selected |

Match FreeBSD's handling of absent `%SUBDIR%/` values instead of dropping
otherwise usable mirrors. Validate missing groups and reserved group names.
Keep mirror preference sorting and optional randomization separate from source
declarations. Define whether FreeBSD distcache is applicable to a given uports
distfile; do not assume private/generated sources exist there.

Do not replace the entire mirror catalog mechanically. Import relevant
families and validate changes to actual URLs independently of syntax alignment.

## 5. Portable do-fetch.sh Integration

Adapt FreeBSD's procedural structure behind a documented environment contract:

- One script handles distfiles and patchfiles through a site-flavor parameter.
- Make normalizes groups/mirrors and exports the required `dp_*` variables.
- Shared helpers cover environment validation, distinfo lookup, and quoting.
- Fetch, command-list, and URL-list operations use the same normalized inputs.

Preserve override -> selected mirrors -> backup ordering, force-fetch policy,
local-cache checks, missing-group diagnostics, and expected-size validation.
Retain SHA256 verification in the checksum phase; size alone is not integrity.

Linux/Darwin portability must address shell `pipefail`, `env -S`, `stat`
arguments, hash utilities, and downloader-specific flags such as FreeBSD
`fetch -S`. Do not pass those flags directly to wget or curl.

Required refinements:

- Explicit output filenames, including redirects and hosted-repository archives.
- Temporary download files; publish only completed, validated downloads.
- Bounded attempts/timeouts and reliable failure propagation.
- TLS verification enabled by default; preserve explicit project opt-outs.
- Concurrent fetches of the same cache entry without exposing partial files.
- Correct nested filenames, quoting, and broken-symlink diagnostics.
- Listing targets that neither download nor modify existing source trees.

Keep raw Git retrieval outside this archive-download script.

## 6. GitHub Archives And Easy Git Development

Proposed FreeBSD-compatible declaration:

```make
USE_GITHUB = yes
GH_ACCOUNT = python
GH_PROJECT = cpython
GH_TAGNAME = $(DISTVERSIONFULL)
```

Implement FreeBSD defaults (`PORTNAME` for account/project and
`DISTVERSIONFULL` for tag), codeload URLs, collision-resistant `_GH0` distfile
names, tag sanitization, and extracted-directory naming. Prefer immutable
commits or release tags; branch-based archive inputs are unsuitable as stable
package sources. Match the reference's validation behavior and document any
stronger uports policy explicitly.

Support grouped `GH_*` values, `GH_TUPLE`, `USE_GITHUB=nodefault`, and
`GH_SUBDIR` placement. Nested placements must be ordered by path depth and
confined beneath the selected source tree.

The same default GitHub declaration also supplies Git defaults:

```text
SCM_REPO_URL = https://github.com/<GH_ACCOUNT>/<GH_PROJECT>.git
SCM_DETACH   = <GH_TAGNAME>
```

Explicit SCM declarations take precedence over these derived defaults.
This permits the common development selection without repeating the URL:

```sh
# Proposed commands, available after source-selector implementation:
make SOURCE_MODE=dist cpython.build
make SOURCE_MODE=git cpython.build
make SOURCE_MODE=git SCM_REPO_URL=https://github.com/my-account/cpython.git \
  SCM_BRANCH=my-feature cpython.build
```

An explicit `SCM_BRANCH` selects branch checkout semantics instead of an
implicitly derived detached archive tag. Define precedence for conflicting
explicit branch/detach settings and reject ambiguous combinations.
A tracking branch is a deliberate development choice; record its resolved
commit and require an immutable revision for reproducible package policy.

Initially derive only the default/main repository. Multi-repository GitHub
archive declarations must not silently become Git submodules. Define a later
grouped-checkout mapping, or fail clearly when Git mode cannot materialize
the declared layout.

## 7. GitLab And Other Repositories

Reserve FreeBSD-compatible GitLab declarations for a later slice:

```make
USE_GITLAB = yes
GL_SITE = https://gitlab.com
GL_ACCOUNT = account
GL_PROJECT = project
GL_COMMIT = <full-commit-hash>
```

The reference uses `GL_COMMIT`, not `GL_TAGNAME`. Add grouped tuples and
subdirectory placement only with matching extraction/layout tests. Account
for self-hosted sites, nested namespaces, ports, and webroot paths when
deriving repository URLs.

Non-hosted or explicitly overridden Git sources remain straightforward:

```make
MASTER_SITES = https://example.org/releases/
# DISTFILES / USES describe the canonical release archive.
SCM_REPO_URL = https://git.example.org/project.git
SCM_DETACH = <full-commit-hash>
```

The project selects `SOURCE_MODE=dist` or `SOURCE_MODE=git`; the port retains
both declarations. A Git-only port declares its repository and the caller
selects Git explicitly, or uses the legacy selector during migration.

## 8. SCM Caches And Developer Worktrees

Preserve current controls:

```make
SCM_CACHE = yes
SCM_CACHE_UPDATE = yes
SCM_CACHE_UPDATE_REQUIRED = no
SCM_FETCH_ENV = GIT_TERMINAL_PROMPT=0
```

Separate mirror refresh from active checkout mutation:

- Fetch refreshes the repository cache according to explicit update policy.
- A failed optional refresh may use the cache only if the requested revision
  is present; a required refresh failure stops the operation.
- Verify the requested ref resolves to a commit before materialization.
- Bound network clone/update/submodule operations on Linux and Darwin.

`SCM_TIMEOUT` currently inherits `SCM_RETRIEVE_TIMEOUT`, whose default is 0;
do not describe a nonzero bounded default as already implemented. The new
design needs a documented finite default and an explicit opt-out, including
clear behavior when a timeout utility is unavailable.

Developer checkout contract:

- Repeated fetch/build operations reuse the checkout without resetting a branch
  or discarding tracked or untracked edits.
- Moving between source modes uses separate work/source roots and lifecycle
  identities; never reuse archive build cookies for a Git tree.
- Checkout creation and updates must not recursively replace an existing
  developer worktree through alternative-source directory handling.
- Define a dedicated explicit update operation. It fails on local changes
  unless the operator resolves them; it does not force-reset or auto-stash.
- Submodule revisions and patch-series state are validated before mutation.
- Source changes require explicit rebuild/restage until reliable dirty-tree
  change tracking is implemented; do not promise automatic edit detection.

A Git checkout used for packaging records the resolved commit. Dirty-tree
packaging needs an explicit policy and cannot claim the clean commit alone
fully identifies its source. Provenance extension and state schema changes
must be reviewed together with dependency/archive identity handling.

## 9. Bootstrap, Patch, And Artifact Identity

A Git checkout can require autoconf, automake, libtool, gettext, parser
generators, or an existing language runtime even when a release archive does
not. Ports must declare those tools for the selected source mode.

Normalize source selection before dependency metadata collection. The planner
must see SCM bootstrap requirements before `pre-init-repo`/bootstrap executes.
Preserve existing bootstrap hooks during migration; do not infer that every
repository should run `autogen.sh` unconditionally.

Include source mode and resolved revision in the artifact identity used by
dependency state and package provenance. Mode/revision changes invalidate
configure/build and downstream artifacts and reject incompatible archives.
Do not add volatile cache paths or fetch timestamps to this identity.

## 10. Existing Distinfo Contract

Preserve these implemented controls:

```make
DISTINFO_FILE ?= $(MASTERDIR)/distinfo
DISTINFO_REQUIRED ?= no
NO_CHECKSUM ?= no
```

`makesum` depends on fetch and delegates to `Mk/Scripts/makesum.sh`.
`checksum` delegates to `Mk/Scripts/checksum.sh`. Both cover `ALLFILES`
(normal distfiles and patchfiles), using the FreeBSD layout:

```text
TIMESTAMP = <unix-time>
SHA256 (<distfile-key>) = <sha256>
SIZE (<distfile-key>) = <bytes>
```

The key is `DIST_SUBDIR/file` when a local namespace is set, otherwise `file`.
Hash tools are selected from `sha256 -q`, `sha256sum`, or `shasum -a 256`.
`NO_CHECKSUM=yes` skips verification. Missing distinfo remains allowed when
`DISTINFO_REQUIRED=no`, and fails when it is `yes`.

Raw SCM mode currently skips archive makesum/checksum. Its integrity contract
is verified revision/submodule identity rather than hashing a generated
archive. Future signed-tag verification is a separate policy extension.

Operator workflow, with archive mode selected using currently supported knobs:

```sh
make -C feeds/category/port USE_SCM= PORTSDIR=/path/to/uports makesum
make -C feeds/category/port USE_SCM= PORTSDIR=/path/to/uports checksum
make USE_SCM= compiler@port.makesum
make USE_SCM= DISTINFO_REQUIRED=yes compiler@port.fetch
```

Do not silently accept changed checksums during migration. Review generated
distinfo after a completed download and maintain it as port-owned source.

## 11. Migration And Acceptance

Use the separate task checklist for implementation order and evidence.
Each framework slice must preserve legacy archive and SCM ports; port
conversions are separate reviewable changes. Remove no legacy selector until
its replacement covers actual users and migration is explicitly approved.

Required verification includes local HTTP and Git fixtures, Linux/Darwin
portability, archive and SCM alternatives of representative ports, real
bootstrap/build/runtime tests, cache repeat behavior, and failure recovery.
FreeBSD-like variable names alone do not establish compatibility.
