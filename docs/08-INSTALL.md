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

Under verbose execution, rejected cached candidates print `PKG REJECT` with
the compatibility categories checked; a selected archive prints `PKG REUSE`.
An incompatible candidate does not hide a compatible second candidate.

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

The notes below describe a separate, still-proposed plist/Flavor extension.

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
the default plist omits these files, `WITH_LIBFFCALL=yes` fails plist checks. If
the plist always includes them, the default build fails plist checks.

## 3. Proposed `PLIST_SUB` Support

Add `PLIST_SUB` support to uports, modeled after FreeBSD ports.

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

ifeq ($(WITH_LIBFFCALL),yes)
PLIST_SUB += LIBFFCALL=""
endif
```

After substitution:

- default build comments out `libgffflib.*`;
- libffcall build includes `libgffflib.*`.

## 4. Framework Behavior

During plist processing, uports should generate `$(TMPPLIST)` from the selected
`$(PLIST)` and apply substitutions before `check-plist` and package creation.

Conceptually:

```text
pkg-plist.linux + PLIST_SUB -> TMPPLIST
```

Then:

```text
TMPPLIST <-> staged file tree
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

For `lang/gforth`, the recommended long-term model is:

```make
FLAVORS = default libffcall
FLAVOR ?= default

WITH_LIBFFCALL = no
PLIST_SUB += LIBFFCALL="@comment "

ifeq ($(FLAVOR),libffcall)
WITH_LIBFFCALL = yes
PKGNAMESUFFIX += -libffcall
PLIST_SUB += LIBFFCALL=""
endif
```

Configure/build logic should then use `WITH_LIBFFCALL`, while package identity
and wrapper selection use `FLAVOR`.

This gives:

- separate configure variants;
- separate package identity when needed;
- one maintainable plist;
- correct install manifests for each variant.

## 6. Short-Term Fix For `lang/gforth`

Until full flavor support exists, `lang/gforth` can keep `WITH_LIBFFCALL` as the
manual selector and use `PLIST_SUB` once the framework supports it:

```make
WITH_LIBFFCALL ?= no
PLIST_SUB += LIBFFCALL="@comment "

ifeq ($(WITH_LIBFFCALL),yes)
LIB_DEPENDS += libavcall.so:devel/libffcall
GFORTH_LIBCC_IMAGE_DEPS += $$(buildccdir)/libgffflib.la
PLIST_SUB += LIBFFCALL=""
else
CONFIGURE_ENV += ac_cv_lib_avcall___builtin_avcall=no
endif
```

Then update `pkg-plist.linux` so only `libgffflib.*` uses the `%%LIBFFCALL%%`
prefix.

This keeps the default package behavior unchanged while allowing the optional
ffcall package to pass plist checks.

## 7. Open Questions

The exact uports syntax can be refined, but the design target should remain:

- use flavors for configure/build variants;
- use plist substitution for install file-set differences;
- keep default package output unchanged unless a flavor or option explicitly
  selects another variant.
