# Install And Plist Notes

## Cached Package Installation And DESTDIR

`install` first considers compatible shared-cache and work-directory packages,
unless `FORCE_REBUILD=yes`. `FORCE_DEVELOPMENT_INSTALL` defaults to `yes`: a
compatible candidate retains fetch/extract/patch for development review, then
installs without configure/build/stage/package. Set it to `no` to install a
compatible cached package without source preparation. If no compatible package
exists, either setting follows the normal source build/install lifecycle.
Missing local state or changed markers
alone do not override that candidate. Required package provenance still must
match the current request. Existing install cookies retain normal reuse rules.
Changing this flag alone does not invalidate package compatibility or dependency
build state; it controls installation workflow rather than package contents.

```sh
make V=1 cmake.install FORCE_DEVELOPMENT_INSTALL=yes
make V=1 cmake.install FORCE_DEVELOPMENT_INSTALL=no
```

Package provenance comparisons normalize instance-local `PORTSDIR` and
`DESTDIR`, and omit cache-site settings. Prefix, provider identities, build
options and available source identity remain compared. Other dependency paths
are not broadly rewritten: a genuine provider difference may still require
rebuilding. This is compatibility checking, not proof every port's binaries
are relocatable. Ports remain responsible for excluding staging paths from
their runtime configuration and for maintaining package revisions.

`PACKAGE_BUILD_ID` optionally adds a port-defined compatibility record to
PVER 2 packages. Changing it rejects packages without the matching record;
it is not an automatically computed recipe hash. CMake now uses runtime
`PREFIX` for bootstrap and normal `DESTDIR` staging, replacing its former
checkout-prefix substitution for future builds. The existing CMake package
passed installation/module-discovery checks in a different destination, so
this correction does not force a package revision or rebuild by itself.

Under verbose install execution, rejected cached candidates print `PKG REJECT` with
the compatibility categories checked; a selected archive prints `PKG REUSE`.
An incompatible candidate does not hide a compatible second candidate.
Internal metadata/state probes and package-only requests do not emit this
install-selection diagnostic: they may not carry the current provider report
and are not selecting an archive for installation. Compatibility checks remain
in force independently of this diagnostic.

For `pkg.sh`, creation reads `STAGEDIR` + runtime `PREFIX` and stores a
prefix-relative payload, including hidden entries. Installation extracts that
payload under `DESTDIR` + the recorded runtime prefix, while its database and
plist reside under `DESTDIR/var/db`. Neither the stored runtime prefix nor
package identity is changed to include `DESTDIR`.

Package archive/destination arguments retain quoting, including destination
roots containing spaces. Temporary payloads use a portable private directory.
Deletion resolves installed paths, including absolute `@rmdir` entries,
through the selected `DESTDIR`; it does not interpret them as host paths.
Deletion previews do not modify files or the database. Keep runtime prefixes
and package metadata within the existing whitespace-delimited database format.

Package queries/removal match an exact installed full name or package base.
The base is derived using the version stored in the database, rather than
matching every name beginning with the requested text. Removing gforth must
therefore preserve gforth-bootstrap and gforth-libffcall registrations.
Origin queries remain supported separately.

An install cookie alone is insufficient after removal through another work
tree or pkg.sh. Provider metadata suppresses install-cookie reuse when the
versioned installed manifest is absent, and install dispatch regenerates the
installation sequence despite a stale cookie. A compatible cached package
can restore the installation using the usual development-source preparation
policy. This receipt check is not a complete executable/library payload audit.

## Standalone Package Management

pkg.sh is self-contained with respect to uports files. Matching, plist parsing
and inventory comparison are internal functions, so copying only this script
to /usr/local/bin (under any command name) is supported. It still uses ordinary
host utilities such as sh, awk, find, sort, diff, tar, xz and mktemp.
It neither needs an adjacent helper directory nor a uports source checkout.

For example, after copying the script as /usr/local/bin/uports-pkg:

```sh
DESTDIR=/path/to/root /usr/local/bin/uports-pkg add /path/to/package.pkg
DESTDIR=/path/to/root /usr/local/bin/uports-pkg info -e gforth
DESTDIR=/path/to/root /usr/local/bin/uports-pkg delete -n gforth
```

DESTDIR must remain explicitly set for package management; use / for the
host root only when intentionally managing that installation. The read-only
check-plist operation takes staged-prefix, manifest and runtime-prefix arguments
without requiring DESTDIR. Framework check-plist calls this same operation.
Standalone management consumes the resolved manifest embedded in an archive;
PLIST_SUB expansion remains a port-build responsibility.

## Installation Conflict Preflight

Before changing the destination, pkg.sh add unpacks the payload in private
temporary storage, checks it against the manifest, and reads ownership from
the installed manifests under DESTDIR/var/db. Matching uses normalized runtime
paths, so packages with different names or prefixes cannot silently overwrite
the same destination path. Missing or invalid installed manifests stop the
operation rather than assuming their files are unowned.

| Incoming path | Existing destination | Result |
| --- | --- | --- |
| Real directory | Real directory | Allow sharing |
| File/symlink | Owned by the same exact installed package | Allow reinstall |
| File/symlink | Owned by another package | Reject, even for identical bytes |
| File/symlink | Unmanaged file/symlink | Reject |
| File/symlink | Directory | Reject |
| Directory | File/symlink | Reject |

A different version is another full package identity and must not overwrite
the old version's files. Remove the previous package first. Reinstalling an
exact package into a changed PREFIX likewise requires removal first. Directory
symlinks in destination parents reject, preventing extraction through them;
an explicitly chosen DESTDIR directory alias is supported.

Known conflicts are reported before destination directories, payload files or
registration data are written. Existing directories can be shared, but this
does not permit shared file ownership. Gforth default/libffcall packages reject
each other while their bootstrap package can coexist using distinct files.

Same-user installs into the same canonical DESTDIR are serialized from ownership
inspection through registration using a temporary mkdir lock under /tmp,
independent of caller TMPDIR. A busy/stale lock times out after 30 attempts;
the installer does not delete another process's lock. Deletion does not yet
participate in this coordination; do not run add and delete concurrently.
There is no cross-user or cross-version transaction guarantee.

Preflight requires temporary space for an unpacked payload. It prevents known
conflict writes, but does not roll back a later I/O failure during destination
extraction and is not an untrusted-archive sandbox. Ownership-aware removal
remains separate work. Prefix-stripping add -p stores normalized relative
directory directives so later removal follows the effective root prefix.

## Conditional Plist Processing

`PLIST_SUB` accepts shell-quoted `KEY=value` words. Input manifests may use
`%%KEY%%` tokens; undefined or malformed tokens and duplicate keys fail before
package creation. Substitution values are literal. Lines beginning with
`@comment` after substitution are omitted from the concrete manifest.

```make
ifeq ($(FLAVOR),libffcall)
PLIST_SUB += LIBFFCALL=""
else
PLIST_SUB += LIBFFCALL="@comment "
endif
```

The read-only `PLIST` is resolved to `WRKDIR/.PLIST.resolved` for packaging.
`TMPPLIST` remains the concrete staged inventory generated by makeplist or
generate-plist. `check-plist` compares the sorted resolved manifest and staged
inventory and fails on missing or extra entries. This comparison uses uports'
existing explicit file/directory inventory format and bounded directives below.
Each Flavor's generated files stay in its own work directory.

Package creation always compares that concrete manifest against a fresh scan
of STAGEDIR/PREFIX before writing archive bytes, including direct pkg.sh create
calls. Missing/unlisted files, symlinks or directories reject the package with
an inventory diff. The same checker is used by check-plist. This does not rely
on a previously generated TMPPLIST or run compiler/dependency phases.

The writer creates an archive in a unique sibling temporary file and renames
it to the work-package path only after successful compression. Validation or
archive-write failures retain the previous work archive and any published
archive sharing its old hard link. A successful replacement becomes a separate
inode until the existing publication rule copies/links it into the cache.
Archive format and provenance records are unchanged. This is not a claim of
transactional publication across filesystems or protection against a concurrent
process changing staged contents between validation and compression.

## Bounded Plist Directives

The shared plist parser inside pkg.sh is used by inventory comparison,
package installation and deletion. Archives and installed manifests retain validated
directives; inventory comparison uses normalized relative paths.

| Entry | Packaging | Removal |
| --- | --- | --- |
| `./path` or `path` | Must appear in the staged inventory | Remove file/symlink, or try empty-directory removal |
| `@comment text` | Ignore, including literal substitution text in raw comments | Ignore |
| `@dir path` | Require a real directory, excluding directory symlinks | Try empty-directory removal only |
| `@rmdir path` | Cleanup-only directory may be absent; if present, require a real directory | Try empty-directory removal only |

Paths are relative to the package runtime PREFIX. An optional leading `./`
and trailing slash are normalized. Legacy absolute @rmdir paths are accepted
only below that PREFIX and translated to the same relative representation.
Empty paths, root entries, dot/dot-dot components, repeated separators,
whitespace, record separators, unresolved tokens and duplicate paths reject.
This remains an explicit inventory: replace the ordinary directory entry with
its directive rather than listing both. Parent directories are not inferred.

Unsupported or malformed directives reject explicitly. Ownership/mode
annotations, @sample and executable hooks are outside this subset. Directory
directives never unlink a file or symlink substituted at that location, and
nonempty directories remain. This is directory cleanup, not shared-file
ownership enforcement (separate work).

Installation validates manifest syntax before extracting files. Deletion
validates each selected package's complete saved manifest before removing its
files, including previews. A malformed manifest therefore cannot silently
skip entries while dropping that package's registration. This is per-package
validation, not a transaction across all packages selected by delete -a.
generate-plist continues to emit concrete paths, never directive templates.

The following sections retain the original design rationale and examples.
Substitution/manifest comparison are now implemented as described above;
port-specific build/runtime validation and coinstallation remain separate.

This note records the current proposal for install manifests when one package
can produce multiple valid configure/install variants.

## 1. Principle

uports should align with FreeBSD ports first, then add small uports extensions
where needed.

For configure-time variants, prefer a FreeBSD-style `FLAVORS` model. For
install manifests, prefer FreeBSD-style `PLIST_SUB` so one plist can describe
multiple related install layouts without duplicating the whole file.

The wrapper/project layer should select the active flavor or option during the
real build.

## 2. Current Problem: `lang/gforth`

`lang/gforth` supports two foreign-interface configurations:

- default: libffi enabled, libffcall disabled;
- optional: libffi enabled, libffcall enabled.

The default package does not install `libgffflib.*`.

When libffcall is enabled, gforth builds and installs the optional ffcall libcc
wrapper files:

```text
./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.so.0.0.0
./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.so.0
./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.so
./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.la
./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.a
```

Therefore a static `pkg-plist.linux` is correct for only one configuration. If
the default plist omits these files, the libffcall build fails plist checks. If
the plist always includes them, the default build fails plist checks.

## 3. `PLIST_SUB` Design

The `PLIST_SUB` interface is modeled after FreeBSD ports.

The package plist should allow substitution tokens such as:

```text
%%LIBFFCALL%%./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.so.0.0.0
%%LIBFFCALL%%./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.so.0
%%LIBFFCALL%%./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.so
%%LIBFFCALL%%./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.la
%%LIBFFCALL%%./lib/gforth/0.7.9_20260513/amd64/libcc-named/libgffflib.a
```

The package Makefile should define whether that token expands to an active
entry or a comment.

Example:

```make
PLIST_SUB += LIBFFCALL="@comment "

ifeq ($(FLAVOR),libffcall)
PLIST_SUB += LIBFFCALL=""
endif
```

After substitution:

- default build comments out `libgffflib.*`;
- libffcall build includes `libgffflib.*`.

## 4. Framework Behavior

During plist processing, uports resolves the selected `$(PLIST)` into
`$(WRKDIR)/.PLIST.resolved` before comparison and package creation.

Conceptually:

```text
pkg-plist.linux + PLIST_SUB -> .PLIST.resolved
```

Then:

```text
.PLIST.resolved <-> TMPPLIST (staged file tree)
```

`check-plist` should compare the staged tree against the substituted plist, not
the raw plist file.

Required behavior:

- undefined substitution tokens should be reported as an error;
- substitutions should work for all plist variants, such as `pkg-plist.linux`
  and `pkg-plist.darwin`;
- `makeplist` or `generate-plist` should continue to output the concrete staged
  file set, not tokenized entries;
- tokenized plist maintenance remains a package author responsibility.

## 5. Relationship With Flavors

`PLIST_SUB` solves the install-manifest difference. It does not replace
flavors.

For `lang/gforth`, the model is:

```make
FLAVORS = default libffcall
FLAVOR ?= default

ifeq ($(FLAVOR),libffcall)
PLIST_SUB += LIBFFCALL=""
else
PLIST_SUB += LIBFFCALL="@comment "
endif
```

Configure/build logic, package identity and wrapper selection use `FLAVOR`
directly. An intermediate WITH_* option is not required. The framework adds
the nondefault package suffix automatically; recipes must not add a second copy.

This gives:

- separate configure variants;
- separate package identity when needed;
- one maintainable plist;
- correct install manifests for each variant.

## 6. Gforth Manifest Mapping

Gforth platform plists mark only optional libgffflib wrapper entries with
`%%LIBFFCALL%%`. The selected Flavor controls the substitution and optional
library dependency. Real staged inventories must confirm each platform's
wrapper filenames. Both Flavors still install overlapping executable/image
paths and must not be treated as safely coinstallable in one prefix.

## 7. Open Questions

The exact uports syntax can be refined, but the design target should remain:

- use flavors for configure/build variants;
- use plist substitution for install file-set differences;
- keep default package output unchanged unless a flavor or option explicitly
  selects another variant.
