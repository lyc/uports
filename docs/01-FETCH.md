# uports Fetch Architecture

## 1. Scope And Status

This document defines the fetch architecture and its migration contract.
Implementation tasks and verification gates are tracked separately in
[01-FETCH-TASKS.md](01-FETCH-TASKS.md). Proposed interfaces below are not
claims that the current framework already implements them.

Current uports supports archive fetching, grouped distfiles and patchfiles,
distinfo generation/verification, and raw Git through `USE_SCM=git`, including
mirror caches and submodule preparation. The first normalization implementation
adds family/path shorthand (including SF/GH aliases), group-specific expansion,
and missing-group diagnostics. A shared portable archive executor now replaces
the inline download loops. Single and grouped `USE_GITHUB` archives are
implemented, including `GH_TUPLE`, `nodefault`, and safe subdirectory placement.
The source selector and the single-repository GitHub Git adapter are now
implemented. GitLab remains migration work. Preserve existing ports until each
replacement is validated.

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

Internal source state is separate from package-dependency records, but explicit
source selections are included in the package provenance envelope. The state
records the selected mode, provider, repository/ref, source root, archive and
layout identity, plus the resolved Git commit. The slice 1 logical schema and
legacy baseline are recorded in [01-FETCH-CONTRACT.md](01-FETCH-CONTRACT.md).

## 3. Source Selection And Compatibility

With `USE_GLOBALBASE=yes`, `DISTDIR_SITE`, `PACKAGES_SITE`, and `SCMDIR_SITE`
provide the default effective archive, package, and Git-cache directories.
Explicit `DISTDIR`, `PACKAGES`, and `SCMDIR` settings take precedence. Existing
framework cache symlinks are preserved, but do not override the selected site.
Without global mode or a corresponding site setting, the framework-local
directory remains the default.

Public selector:

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

Explicit selections receive source-identity lifecycle cookies. Explicit Git
uses a `-git-<ref>` source-root suffix; archive mode retains the archive root.
Changing the selected ref therefore cannot reuse archive/Git stage or package
cookies. Explicit-source packages use PVER2 provenance even when dependency
provenance is disabled, so an existing package with another source identity is
rejected. Legacy/default selections keep their existing cookie and package
format for compatibility. Returning to a previously extracted explicit
selection restores its saved source record and preserves its checkout and
patch history, while refreshing configure/build/stage/package completion for
the shared output paths.

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

Implemented normalization uses `Mk/linux.fetch-sites.mk`: full URLs retain
their port/path, family/path declarations substitute the remote subdirectory,
and GNU defaults to PORTNAME only when MASTER_SITE_SUBDIR is undefined.
Explicit empty subdirectories suppress that default. Grouped subdirectories
accept both FreeBSD `path/:group` and uports convenience `path:group` spelling.
Only the selected group's subdirectories expand its mirrors; shared membership
does not multiply the same URL across unrelated groups. Missing `%SUBDIR%/`
is removed rather than discarding the base URL. Unknown families and reserved
groups fail clearly; missing named file groups fail before archive fetching.
Legacy USE_SCM host declarations bypass shorthand expansion.

The executor keeps override -> selected mirrors -> backup ordering. Backup is
empty unless explicitly configured; no automatic FreeBSD distcache is enabled.
`MASTER_SORT_REGEX` supplies ordered POSIX awk URL patterns (case-sensitive);
`MASTER_SORT` supplies ordered case-insensitive domain suffix preferences.
Regex buckets precede domain buckets; unmatched URLs remain in declaration
order. `RANDOMIZE_MASTER_SITES=yes` shuffles within preference buckets only;
override and backup ordering is preserved. The default is `no`, so normalized
lists and default attempts remain deterministic. This is intentionally more
conservative than randomizing the complete FreeBSD attempt list.

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

### Implemented Executor Contract

`Mk/linux.fetch.mk` supplies the environment and invokes
`Mk/Scripts/do-fetch.sh` separately for distfiles (`MASTER`) and patchfiles
(`PATCH`). Its positional arguments are `filename:group[,group]` declarations.
It consumes exported `_MASTER_SITES_<group>` or `_PATCH_SITES_<group>` URL
lists without overrides/backups; these are added once by the executor.
The older `__group_*`/`__patch_*` exports remain compatible.

| Environment | Meaning |
| --- | --- |
| `dp_DISTDIR` | Effective local cache directory, including DIST_SUBDIR |
| `dp_DIST_SUBDIR`, `dp_DISTINFO_FILE`, `dp_DISTINFO_REQUIRED` | Distinfo key namespace, absolute metadata path, and missing-file policy |
| `dp_SITE_FLAVOR` | MASTER or PATCH |
| `dp_TARGET` | do-fetch, fetch-list, or fetch-url-list |
| `dp_FETCH_CMD`, `dp_FETCH_TOOL` | Downloader command and wget/curl argument dialect |
| `dp_FETCH_ENV`, `dp_FETCH_BEFORE_ARGS`, `dp_FETCH_AFTER_ARGS` | Whitespace-delimited environment/options; not shell code |
| `dp_FETCH_TIMEOUT`, `dp_FETCH_REGET` | Positive timeout seconds and attempt count |
| `dp_FORCE_FETCH_ALL`, `dp_FORCE_FETCH_LIST` | Force-all flag or basename-matched file list |
| `dp_NO_CHECKSUM`, `dp_DISABLE_SIZE` | Explicit checksum/size opt-outs |
| `dp_NO_CHECK_CERTIFICATE` | Explicit TLS-verification opt-out |
| `dp_MASTER_SITE_OVERRIDE`, `dp_MASTER_SITE_BACKUP` | Ordered outer mirror lists |
| `dp_MASTER_SORT`, `dp_MASTER_SORT_REGEX`, `dp_RANDOMIZE_SITES` | Executor preference/randomization policy |

`FETCH_CMD` defaults to available wget, then curl. `FETCH_TOOL` defaults to
the command basename; set it explicitly for a wrapper. The executor supplies
backend-specific explicit output arguments instead of wget directory/naming
flags or FreeBSD fetch flags. Extra argument/environment lists support plain
whitespace-separated words, not embedded shell quoting, pipelines, expansion,
or environment values containing spaces; use a wrapper script for those cases.
Cache paths are quoted, and printed commands shell-quote their settings.

`FETCH_TIMEOUT` defaults to 30 seconds and `FETCH_REGET` to one attempt.
Wget uses its I/O timeout and bounded try count; curl uses max-time and bounded
retry count/retry window. Wget's timeout is not an absolute whole-download
deadline: a continuously progressing download can exceed it. Neither setting
changes the independent SCM timeout controls. TLS verification remains enabled
unless `NO_CHECK_CERTIFICATE=yes` is explicitly selected.

Downloads go to uniquely named temporary files in the destination directory.
Available distinfo size and SHA256 evidence is checked before atomic rename;
failed force-fetch leaves an existing archive untouched. Concurrent fetches
may download twice but never publish partial data; they do not use persistent
locks. Temporary-file readability follows the caller's umask. Broken/forced
symlink destinations and unsafe relative filenames fail explicitly. Existing
cached files (including legacy basename lookup) retain the existing checksum
phase as their integrity check.

Direct-port `fetch-url-list` prints normalized candidate URLs; `fetch-list`
prints executable invocations of this same executor. Neither creates cache
directories or downloads files. Printed commands retain normal cache/force
semantics when executed later. Wrapper aliases for these new inspection
targets are not yet added. Both listing targets skip raw SCM sources.

Run `make -C Tools/tests slice6` for real Mini-XML wrapper fetching, cache
reuse, deleted-archive refetch, source transitions, packaging and runtime
checks. See [the test catalog](../Tools/tests/README.md) for requirements and
the implementation-commit mapping. Previous loopback regressions are archived
under `Tools/tests-backup` and are not part of active validation. Python is
test-only, not an archive-fetch runtime dependency. Darwin remains deferred.

## 6. GitHub Archives And Easy Git Development

Implemented single-repository declaration:

```make
USE_GITHUB = yes
GH_ACCOUNT = python
GH_PROJECT = cpython
GH_TAGNAME = $(DISTVERSIONFULL)
```

`Mk/linux.github.mk` applies FreeBSD defaults: `PORTNAME` for account/project,
`DISTVERSIONFULL` for tag. It feeds the existing fetch/checksum/extract phases;
it is not another downloader or a Git checkout request.

The generated URL is
`https://codeload.github.com/<account>/<project>/tar.gz/<tag>?dummy=/`.
The executor appends the local archive filename to the harmless query string
and explicitly sets the output path. `GH`/`GITHUB` mirror tokens resolve to
this URL only when the helper is active; legacy catalog use is unchanged.

Default cache names match the reference:

- Tag equals DISTVERSIONFULL: `<account>-<project>-<sanitized-tag>_GH0.tar.gz`.
- Otherwise: `<account>-<project>-<DISTVERSIONFULL>-<sanitized-tag>_GH0.tar.gz`.

Tag sanitization replaces `/` with `-`. Extraction naming additionally removes
a leading `v`/`V` before a digit, replaces `+` with `-`, and collapses repeated
hyphens. Default WRKSRC is `<WRKDIR>/<project>-<extraction-tag>`, independent
of the account-qualified cache filename. GitHub archives are always `.tar.gz`.
DIST_SUBDIR still controls the local namespace and distinfo key, not the URL.

The helper sets DISTNAME and appends its archive to file-defined DISTFILES;
additional distfiles remain supported. An explicit WRKSRC remains authoritative.
Normal GNU make command-line precedence permits intentional DISTNAME/DISTFILES
and mirror overrides. File-defined alternative mirrors remain before the added
GH mirror; command-line MASTER_SITES can select a mirror alone. An explicit
archive list must name the intended GitHub archive if the default is replaced.

Package sources must use a release tag or immutable commit, not a moving
branch. Unlike the reference's explicit `master` check, uports also rejects
`main`, `HEAD`, and `refs/heads/*`. Other arbitrary branch names cannot be
distinguished from tags offline: the port author must select a tag/commit and
maintain distinfo; use DISTINFO_REQUIRED=yes when missing evidence must fail.
Release tags can be moved upstream, so distinfo remains important even for tags.
This slice does not add online ref classification or signed-tag verification.

Grouped declarations and placement are described below. With legacy USE_SCM
set, a single-repository helper leaves archive names/roots/mirrors alone and
does not derive a repository URL; existing SCM declarations remain required.
Grouped GitHub sources reject legacy USE_SCM rather than silently interpreting
archives as submodules or materializing an incomplete layout.

The active slice 6 real-world case validates archive/Git selection through the
parent Mini-XML port, with source state, package provenance, repeat reuse and
staged shared-library runtime checks. Former grouped/synthetic GitHub fixtures
are preserved under `Tools/tests-backup`; their earlier results are historical
evidence, not current active coverage.

With explicit source selection, source/ref/layout changes use distinct
lifecycle identities and package provenance. No dirty developer worktree is
reset by this feature; checkout update and dirty-tree policy remain slice 7.

### Grouped GitHub Sources

Values can carry a group suffix, including comma-separated group lists:

```make
USE_GITHUB = yes
GH_ACCOUNT = owner
GH_PROJECT = main-project parser:parser unicode:data
GH_TAGNAME = v1.0 v2.0:parser 0123456789abcdef:data
GH_SUBDIR = vendor/parser:parser vendor/parser/data:data
```

Ungrouped account/project/tag values describe DEFAULT. A group missing one of
those fields inherits the effective DEFAULT value, not a value from another
named group. GH_SUBDIR is never inherited. Group names contain ASCII letters,
digits, or underscores; `all`, `ALL`, and lowercase `default` are reserved.
Repeated fields for the same group use the last declaration. Group discovery
is deterministic: account, project, tag, subdir declarations, then tuples.

`GH_TUPLE` is shorthand for `account:project:tag[:group[,group]][/subdir]`:

```make
GH_TUPLE = owner:parser:v2.0:parser/vendor/parser \
           other:unicode:0123456789abcdef:data/vendor/parser/data
```

Tuple declarations are applied after the corresponding GH_* lists and thus
override earlier values for their groups. A three-field tuple supplies DEFAULT;
the fourth field can be `DEFAULT/path` or `/path` for a default self-alias.
Slashes inside the third field belong to the tag, not the placement path.

`USE_GITHUB=nodefault` (also `yes nodefault`) suppresses the implicit main
GitHub archive while preserving DEFAULT inheritance for named groups. Existing
explicit DISTFILES remain available for a non-GitHub primary source. With no
primary archive, the generic WRKSRC is created for grouped assembly. An
unplaced grouped archive can itself be WRKSRC, without any move.

Each named group adds an independent codeload mirror and
`<account>-<project>-<sanitized-tag>_GH0.tar.gz:<group>` distfile. `GH:group`
and `GITHUB:group[,group]` explicitly select declared hosted groups; unknown
groups fail. Overrides precede all group mirrors, while an ordinary DEFAULT
mirror does not implicitly apply to named groups. Use MASTER_SITE_OVERRIDE to
reroute all groups to a common mirror. Explicit grouped GH tokens do not add
the same automatic mirror again.

For inspection/build recipes, the helper derives GH_ACCOUNT_<group>,
GH_PROJECT_<group>, GH_TAGNAME_<group>, GH_SUBDIR_<group>,
GH_TAGNAME_<group>_SANITIZED/EXTRACT, DISTNAME_<group>, DISTFILE_<group>, and
WRKSRC_<group>. Declare policy through the GH_* lists or GH_TUPLE, not by
assigning these derived helpers. Unlike the BSD-make implementation, GNU make
retains the public input lists; inspect the *_DEFAULT helpers for their
effective ungrouped values. With alternative sources, group WRKSRC helpers
refer to the physical extraction base. Moved roots remain reachable through
symlinks at their original group locations.

`github-normalize.awk` emits internal read-only
`group|account|project|tag|subdir` records, with `-` representing no placement.
This is a hosted-declaration adapter, not the future source/artifact identity
schema. It rejects conflicting extraction-root identities before fetching.
Groups can alias the same archive/root only with identical coordinates and
placement; one source root cannot be moved into two different destinations.

### Placement Safety And Lifecycle

At extraction priority 690, before post-extract/alternative-source linking,
`github-place.sh` assembles groups shallow-to-deep. The main physical source
root and group extraction base are selected consistently with USE_ALTERNATIVE.
Placement stays beneath that main root; absolute paths, `.`/`..`, empty path
components, duplicate destinations, unexpected symlinks, and populated
destinations fail rather than being replaced. The preflight also checks future
nested parents inside the extracted group archives, before the first move.

Ungrouped GH_SUBDIR creates a relative self-alias to the main root, matching
the reference concept. It cannot overlap a grouped placement or replace a
populated directory. Safe repeat placement accepts only its expected aliases
and preserves developer edits; it never resets/stashes a tree or recursively
deletes a destination. Filesystem failures during moves can still leave a
partially assembled tree requiring inspection; this is not a transactional
rollback mechanism. Existing force-extract/cleanup behavior remains outside
this phase's preservation guarantee and is addressed in the worktree slice.

Placed groups enter the main archive-derived Git baseline before maintained
patch application. They are ordinary files, not upstream Git checkouts or
submodules. Unplaced group roots stay separate; this slice does not initialize
an independent Git repository for each one. Explicit source selection provides
source identity/state tracking; legacy/default selections still require a
fresh work tree when changing source coordinates or layout.

The grouped loopback fixture covers defaults, comma groups, tuple overrides,
nested placement in reverse declaration order, nodefault, alternative roots,
self-aliases, real Git patch/stage/runtime behavior, repeat edit preservation,
and conflict/symlink failures before mutation. GitLab remains a separate
follow-up; Darwin execution is still pending closeout validation.

The same default GitHub declaration supplies Git defaults in explicit Git
mode:

```text
SCM_REPO_URL = https://github.com/<GH_ACCOUNT>/<GH_PROJECT>.git
SCM_DETACH   = <GH_TAGNAME>
```

Explicit SCM declarations take precedence over these derived defaults.
This permits the common development selection without repeating the URL:

```sh
make SOURCE_MODE=dist cpython.build
make SOURCE_MODE=git cpython.build
make SOURCE_MODE=git SCM_REPO_URL=https://github.com/my-account/cpython.git \
  SCM_BRANCH=my-feature cpython.build
```

An explicit `SCM_BRANCH` selects branch checkout semantics instead of an
implicitly derived detached archive tag. Supplying both branch and detach in
explicit Git mode is rejected.
A tracking branch is a deliberate development choice; record its resolved
commit and require an immutable revision for reproducible package policy.

Only the default/main repository is derived. Multi-repository GitHub archive
declarations fail clearly in Git mode rather than silently becoming submodules.

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

`SCM_TIMEOUT` inherits `SCM_RETRIEVE_TIMEOUT`, defaulting to 15 minutes.
This is a total deadline for each network command, including active transfers;
it is not an inactivity timeout. The former 120-second default interrupted
healthy initial mirrors of real ports. Large initial mirrors may also exceed
15 minutes: CPython's full mirror took about 21 minutes in live validation.
Select a longer project budget, for example `SCM_TIMEOUT=30m`, for those
fetches. Git clone/fetch and submodule commands
force transfer progress even when output is redirected, so completion of the
remote compression phase is followed by visible receiving/indexing progress.
Durations such as `60s` remain supported. Network commands use `timeout` or
`gtimeout` (or an explicit `SCM_TIMEOUT_BIN`) with a five-second kill grace.
If the required utility is unavailable, the operation fails rather than
silently running without a bound. Set `SCM_TIMEOUT=0` or `no` to opt out.
Framework-managed submodule initialization uses the same bound; port-owned
custom hooks invoking Git themselves remain the port's responsibility.

Mirror mutation and checkout creation/update use directory locks, with
`SCM_LOCK_TIMEOUT=30` seconds of waiting by default. New mirrors/checkouts
are built in unique adjacent temporary directories and published only after
Git/ref validation succeeds. Failure or a handled signal removes only that
operation's temporary directory and lock. SIGKILL or a host crash can leave
a lock or temporary directory: inspect its owner and active processes before
manual recovery. The framework never steals a lock based only on PID checks.
Cache origins must match the selected repository; branch matching is exact.

Developer checkout contract:

- Repeated fetch/build operations reuse the checkout without resetting a branch
  or discarding tracked or untracked edits.
- Moving between source modes uses separate work/source roots and lifecycle
  identities; never reuse archive build cookies for a Git tree.
- Checkout creation and updates must not recursively replace an existing
  developer worktree through alternative-source directory handling.
- `scm-update` is a direct-port operation. It requires a clean checkout,
  initialized/aligned submodules, and no unfinished Git operations. It keeps
  the selected branch (or detached HEAD) and permits fast-forward movement
  only; it does not force-reset, auto-stash, or discard local commits.
- Submodule revisions and patch-series state are validated before mutation.
  Initialized submodules at the recorded gitlink are reused without checkout,
  preserving local edits and branches. A different existing HEAD is rejected
  and preserved; the framework does not silently rewind it to the gitlink.
- Source changes require explicit rebuild/restage until reliable dirty-tree
  change tracking is implemented; do not promise automatic edit detection.

For example, retaining the same settings used to create the checkout:

```sh
make -C feeds/textproc/mxml PORTSDIR="$PWD/make/uports" \
  SOURCE_MODE=git SCM_BRANCH=my-branch scm-update
```

The parent planner does not add an `mxml.scm-update` alias. Update rejects
changes to `.gitmodules` or gitlinks before moving HEAD; manage those updates
manually. Cache refresh and FETCH_HEAD may change on a rejected update, but
checkout files and HEAD remain intact. A successful update refreshes source
state and invalidates its lifecycle cookies/work package for the next build.

An existing checkout carries its repository/branch/ref request in Git metadata.
An incompatible request fails instead of reusing a colliding source-root name.
Legacy checkouts without that marker are checked before adoption. Existing
alternative-source links must point to the selected location; occupied paths
are not replaced. Archive directory preparation also refuses to delete a Git
tree, protecting a developer checkout when legacy declarations share a root.

Explicit Git packages record actual HEAD as `resolved-commit` and the optional
source-state v1 field `worktree-dirty|yes` or `no`. The default
`SCM_DIRTY_PACKAGE=record` permits ordinary generated build files and records
dirty status; this does not make a dirty package reproducible or identify all
its changed bytes. `SCM_DIRTY_PACKAGE=reject` requires a clean tree/submodules.
Unfinished Git operations are always rejected. Legacy package formats remain
unchanged. Dirty status is inspected when creating a package, not as automatic
edit tracking: use explicit rebuild/restage when editing sources. Reusing an
existing package does not imply that current unbuilt edits were packaged.

Run `make -C Tools/tests slice7` for real Mini-XML and ad-libitum validation.
It covers developer edits/branches, alternative roots, explicit updates using
real upstream history, offline/failed refreshes, missing refs, interrupted and
concurrent clones, finite timeouts, and actual submodules/maintained patches.
See [the test catalog](../Tools/tests/README.md) for scope and evidence paths.

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
