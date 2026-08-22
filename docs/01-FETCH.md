# uports Fetch Design And USE_SCM Redesign

## 1. Design Philosophy

uports fetch design should follow three principles:

1. Align with FreeBSD ports first.
2. Add uports-specific extensions on top of the FreeBSD model.
3. Let the uports wrapper/project system select how a real project build uses
   those declarations.

This means port Makefiles should be declarative. They should describe available
source locations and source backends, while the framework and wrapper decide
which backend is active for a particular project build.

## 2. FreeBSD Alignment

FreeBSD ports use `MASTER_SITES`, `DISTFILES`, `DISTNAME`, `EXTRACT_SUFX`, and
related variables for normal archive distfiles. For hosted source repositories,
FreeBSD also provides helper knobs such as:

```make
USE_GITHUB= yes
GH_ACCOUNT= account
GH_PROJECT= project
GH_TAGNAME= tag
```

and similarly for GitLab:

```make
USE_GITLAB= yes
GL_SITE= https://gitlab.com
GL_ACCOUNT= account
GL_PROJECT= project
GL_TAGNAME= tag
```

For GitHub and GitLab, the normal FreeBSD-style fetch path uses generated
archive distfiles. It does not use live `git clone` as the default packaging
source. This keeps fetches closer to the distfile model: cacheable, mirrorable,
and reproducible.

uports should follow that model before adding local extensions.

## 3. uports Extensions

uports has practical requirements beyond the base FreeBSD-style archive model.
The redesigned fetch layer should preserve these capabilities:

- raw SCM source mode for projects where archive distfiles are unavailable,
  unsuitable, or intentionally bypassed;
- coexisting tarball and SCM source declarations in one port;
- SCM mirror/cache repositories;
- bounded SCM fetch/update behavior with timeouts;
- explicit cache update policy, such as fail on update failure or use the
  existing cached repository when update fails;
- source mode selection by the wrapper/project system.

These should be extensions layered on top of FreeBSD-style fetch declarations,
not replacements for them.

## 4. Wrapper Selection

The uports wrapper/project system should decide which source backend is used for
the actual project build. It can pass that policy through environment or make
variables, the same way it already supplies values such as:

```text
DESTDIR
PREFIX
PORTSDIR
```

A source selector can be introduced as a framework variable:

```make
SOURCE_MODE ?= dist
```

Possible values:

```text
dist
github
gitlab
git
```

The exact names can evolve, but the ownership should be clear:

- the port declares available source backends;
- the wrapper selects one;
- the framework activates the selected backend.

Port Makefiles should avoid policy-heavy conditional rewrites such as:

```make
USE_SCM ?= git
ifeq ($(USE_SCM),git)
MASTER_SITES = git.example.org
MASTER_SITE_SUBDIR = git
SCM_DEST = $(PORTNAME)
endif
```

Instead, they should declare both source forms plainly.

## 5. Proposed Public Interface

### Archive Source

Keep the existing archive path:

```make
MASTER_SITES= https://example.org/releases/
DISTFILES= $(DISTNAME).tar.xz
USES+= tar:xz
```

### GitHub Archive Source

Add FreeBSD-style GitHub support:

```make
USE_GITHUB= yes
GH_ACCOUNT= python
GH_PROJECT= cpython
GH_TAGNAME= $(DISTVERSIONFULL)
```

Framework responsibilities:

- derive `MASTER_SITES` for GitHub archive download;
- derive `DISTFILES`;
- derive the expected extracted directory and `WRKSRC`;
- reject or warn for unstable branch names when appropriate, such as `master`;
- support future `GH_TUPLE`-style multi-distfile use.

### GitLab Archive Source

Add FreeBSD-style GitLab support later:

```make
USE_GITLAB= yes
GL_SITE= https://gitlab.com
GL_ACCOUNT= account
GL_PROJECT= project
GL_TAGNAME= $(DISTVERSIONFULL)
```

Framework responsibilities should mirror the GitHub helper.

### Raw Git Source

Keep raw git clone as an explicit uports extension. It should not be the default
model for GitHub/GitLab packages.

Possible interface:

```make
USE_GIT= yes
GIT_REPO= https://git.savannah.gnu.org/git/gforth.git
GIT_TAGNAME= $(DISTVERSIONFULL)
GIT_DEST= $(PORTNAME)
WRKSRC_GIT= $(WRKDIR)/$(GIT_DEST)
```

The current `USE_SCM=git` behavior can be kept temporarily as compatibility
glue, but new ports should move toward `USE_GIT` or another final raw-git
interface.

## 6. Coexisting Source Declarations

A port should be able to declare both a canonical archive source and a raw SCM
source.

Example:

```make
PORTNAME= gforth
DISTVERSION= 0.7.9_20260513

SOURCE_MODE ?= dist

MASTER_SITES= https://www.complang.tuwien.ac.at/forth/gforth/Snapshots/current/
DISTFILES= $(PORTNAME).tar.xz
DIST_SUBDIR= $(PORTNAME)-$(DISTVERSIONFULL)
USES+= tar:xz

USE_GIT= yes
GIT_REPO= https://git.savannah.gnu.org/git/gforth.git
GIT_TAGNAME= $(DISTVERSIONFULL)
GIT_DEST= $(PORTNAME)
WRKSRC_GIT= $(WRKDIR)/$(GIT_DEST)
```

The wrapper can choose:

```sh
SOURCE_MODE=dist make V=1 gforth.extract
SOURCE_MODE=git make V=1 gforth.extract
```

The port should not rewrite `MASTER_SITES` based on source mode. The framework
should activate only the selected backend.

## 7. SCM Cache Requirements

Raw SCM mode should preserve and refine the cache behavior that already exists
in uports.

Recommended variables:

```make
SCM_CACHE ?= yes
SCM_CACHE_UPDATE ?= yes
SCM_CACHE_UPDATE_REQUIRED ?= no
SCM_TIMEOUT ?= 10s
SCM_FETCH_ENV ?= GIT_TERMINAL_PROMPT=0
```

Behavior:

- if cache is enabled, maintain a local mirror repository;
- if cache update fails and `SCM_CACHE_UPDATE_REQUIRED=no`, warn and use the
  existing cache;
- if cache update fails and `SCM_CACHE_UPDATE_REQUIRED=yes`, fail the fetch;
- apply `SCM_TIMEOUT` to network operations such as mirror clone, remote update,
  and direct clone;
- verify requested tag/commit exists in the cache before extract/clone.

## 8. Current Distinfo Support

uports now has initial FreeBSD-style `distinfo` support for archive distfiles.
This is implemented in the normal fetch/checksum path and is intentionally
non-breaking for existing ports that do not yet have a `distinfo` file.
The public targets stay in `linux.port.mk`, while the procedural work is handled
by helper scripts under `Mk/Scripts`, matching the FreeBSD ports framework
style more closely.

Supported variables:

```make
DISTINFO_FILE ?= $(MASTERDIR)/distinfo
DISTINFO_REQUIRED ?= no
NO_CHECKSUM ?= no
```

Current behavior:

- `make makesum` depends on `fetch` and writes `$(DISTINFO_FILE)`.
- `make makesum` delegates generation to `Mk/Scripts/makesum.sh`.
- `make checksum` delegates verification to `Mk/Scripts/checksum.sh`.
- The generated file uses FreeBSD-style entries:

  ```text
  TIMESTAMP = <unix-time>
  SHA256 (<distfile-key>) = <sha256>
  SIZE (<distfile-key>) = <bytes>
  ```

- `make checksum` verifies every file in `$(ALLFILES)`, which currently covers
  normal distfiles and patchfiles.
- The checksum key is `$(DIST_SUBDIR)/<file>` when `DIST_SUBDIR` is set, and
  `<file>` otherwise.
- Verification checks both `SHA256` and `SIZE`.
- Hash calculation uses the first available command from `sha256 -q`,
  `sha256sum`, or `shasum -a 256`.
- If `NO_CHECKSUM=yes`, checksum verification is skipped.
- If `$(DISTINFO_FILE)` is missing and `DISTINFO_REQUIRED=no`, checksum prints a
  skip message and succeeds. This keeps old ports building while ports are
  migrated.
- If `$(DISTINFO_FILE)` is missing and `DISTINFO_REQUIRED=yes`, checksum fails.
- `USE_SCM` ports currently skip `makesum` and checksum verification, because
  raw SCM sources do not map cleanly to archive distinfo yet.
- The wrapper target list includes `makesum`, so project-level targets such as
  `compiler@port.makesum` can call into a port's `make makesum`.

Operator workflow:

1. For an archive-backed port, fetch and generate `distinfo` from the port
   directory:

   ```sh
   make V=1 makesum PORTSDIR=/path/to/uports
   ```

2. Review the generated `distinfo`. It should contain one `TIMESTAMP`, one
   `SHA256` line, and one `SIZE` line for each file in `$(ALLFILES)`.

3. Verify the cached distfiles against `distinfo`:

   ```sh
   make V=1 checksum PORTSDIR=/path/to/uports
   ```

4. For wrapper/project builds, run the wrapper target instead of entering the
   port directory directly:

   ```sh
   make USE_GLOBALBASE=yes compiler@port.makesum
   make USE_GLOBALBASE=yes compiler@port.fetch
   ```

   `compiler@port.fetch` reaches the normal fetch sequence, including checksum
   verification before extract.

5. To enforce checksums during migration or CI, pass:

   ```sh
   DISTINFO_REQUIRED=yes
   ```

   Without this, missing `distinfo` is still allowed for compatibility with old
   ports.

Open items:

- Add `distinfo` files to archive-backed ports as they are migrated.
- Decide when project policy should switch `DISTINFO_REQUIRED` from `no` to
  `yes`.
- Extend or separately define integrity metadata for raw SCM mode, likely by
  verified tag or commit identity rather than archive `SHA256` and `SIZE`.
- Improve multi-source support as `USE_GITHUB`, `USE_GITLAB`, and tuple-style
  distfiles are added.

## 9. Migration Plan

1. Implement FreeBSD-style `USE_GITHUB` and `GH_*` archive support.
2. Implement or reserve `USE_GITLAB` and `GL_*` archive support.
3. Introduce `SOURCE_MODE` as the wrapper-controlled selector.
4. Move raw git implementation out of generic `linux.port.mk` internals into a
   clearer source backend module.
5. Keep `USE_SCM=git` as compatibility glue during migration.
6. Convert current ports such as `cpython`, `sbcl`, and `gforth` to declare
   archive and SCM sources separately.
7. Warn on new direct `USE_SCM=git` use after replacement variables exist.
8. Remove public `USE_SCM` only after existing ports have moved.

## 10. Open Naming Decision

The final raw-git public API still needs one decision:

```make
USE_GIT= yes
```

or:

```make
USES+= scm:git
```

For strongest FreeBSD alignment, `USE_GIT=yes` fits better beside
`USE_GITHUB=yes` and `USE_GITLAB=yes`. `USES+=scm:git` is more mechanically
generic but less FreeBSD-like.

Current recommendation:

```make
USE_GIT= yes
```

Keep existing `USES=git:ownership` as a separate worktree helper and do not
reuse it as the source retrieval interface.
