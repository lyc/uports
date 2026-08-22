# Configure And Prefix Migration Notes

This note records the current evaluation for changing package builds from
`PREFIX=/usr` to `PREFIX=/usr/local`.

## 1. Principle

`PREFIX` is the final runtime install prefix. It is not only a staging path.

For packages that embed runtime paths, building with one prefix and then moving
the installed tree to another prefix is not equivalent. The package should be
configured and built with the same `PREFIX` that the final runtime environment
will use.

Examples:

```sh
# Correct for a /usr/local runtime package
make V=1 package DESTDIR=/path/to/root PREFIX=/usr/local

# Risky for path-sensitive packages
make V=1 package DESTDIR=/path/to/root PREFIX=/usr
# then moving /path/to/root/usr into /usr/local
```

The second pattern can leave stale paths in launchers, saved images, `.la`
files, pkg-config files, scripts, rpaths, or runtime search defaults.

## 2. Plist Impact

Current `pkg-plist*` files are relative to `$(STAGEDIR)$(PREFIX)`.

Example plist entries:

```text
./bin/tool
./lib/libfoo.so
./include/foo.h
```

Because the entries are relative, changing `PREFIX=/usr` to
`PREFIX=/usr/local` should not by itself require changing plist files, as long
as the installed file set is unchanged.

The required check is still:

```sh
make V=1 check-plist PREFIX=/usr/local ...
```

Regenerate or edit plist files only when the file set changes.

## 3. What Must Be Checked

Even when plist files are unchanged, generated artifacts can embed the selected
prefix. For each package with an existing plist, verify:

- generated pkg-config files (`*.pc`);
- libtool archive files (`*.la`);
- scripts and config helper commands;
- rpath/runpath in ELF or Mach-O binaries;
- language runtime image/core/header files;
- launcher binaries that embed library directories;
- staged files that still contain the old prefix.

Useful checks:

```sh
rg -n '/usr($|/)' work*/stage
rg -n '/usr/local($|/)' work*/stage
find work*/stage -type f -name '*.pc' -o -name '*.la'
```

The `/usr` matches need review, not automatic removal. Some references may be
valid system tool paths, but install-prefix references should match the selected
`PREFIX`.

## 4. Package Risk Groups

The following packages currently have `pkg-plist*` files and should be checked
when changing the project prefix convention.

### Low Risk

These packages appear to be mostly standard autotools, cmake, or simple manual
install packages. They still need rebuild, `check-plist`, and metadata
inspection, but they are less likely to have complex runtime prefix embedding.

```text
converters/libiconv
databases/gdbm
devel/libffcall
devel/libffi
devel/libltdl
devel/ncurses
devel/pcre2
devel/readline
lang/lua
lang/quickjs
net/libyang2
security/openssl
textproc/expat2
textproc/ezxml
textproc/json-c
textproc/libcsv
```

Notes:

- `devel/pcre2` contains `/usr/bin/limits` in its Makefile, but this is a test
  command path, not an install prefix.
- Packages that generate pkg-config files from templates must still be checked
  to ensure `prefix=` matches the selected `PREFIX`.

### Medium Risk

These packages intentionally rewrite `PREFIX` to install below a tools
subdirectory:

```text
math/gmp
math/mpfr
math/mpc
```

Current pattern:

```make
override PREFIX := $(PREFIX)/tools
```

Therefore changing the global prefix from `/usr` to `/usr/local` changes their
actual install prefix from:

```text
/usr/tools
```

to:

```text
/usr/local/tools
```

That may be acceptable, but all dependent packages must use the same final
dependency root.

### High Risk

Language runtimes need package-specific runtime tests after rebuild because
they often embed or derive runtime paths from the configure prefix.

```text
lang/chezscheme
lang/clisp
lang/cpython
lang/gforth-0.7.3
lang/gforth
lang/sbcl
```

Known concerns:

- `lang/chezscheme`: boot files and runtime binary layout.
- `lang/clisp`: launcher and runtime library directory.
- `lang/cpython`: `sys.prefix`, config scripts, pkg-config files, extension
  module search paths.
- `lang/gforth-0.7.3`: bootstrap package must be installed under the same
  prefix expected by `lang/gforth`.
- `lang/gforth`: saved image header, `envos.fs`, libcc `.la` `libdir`, engine
  rpath, and `libccdir` behavior.
- `lang/sbcl`: core and contrib discovery.

### Needs Fix Or Review

`lang/librep` currently has suspicious libffi paths:

```make
LIBFFI_CFLAGS=$(DESTDIR)$(PREFIX)/usr/include
LIBFFI_LIBS=$(DESTDIR)$(PREFIX)/usr/lib
```

With `PREFIX=/usr/local`, those expand to:

```text
/usr/local/usr/include
/usr/local/usr/lib
```

That is likely wrong. It should be reviewed and probably changed to use
`$(DESTDIR)$(PREFIX)/include` and `$(DESTDIR)$(PREFIX)/lib`, with `-I` and
`-L` flags if upstream expects compiler/linker flags.

## 5. Proposed Migration Flow

1. Choose the final runtime prefix, for example:

   ```sh
   PREFIX=/usr/local
   ```

2. Rebuild the dependency chain from the bottom up using the same `PREFIX`.

3. For each package with `pkg-plist*`, run:

   ```sh
   make V=1 package check-plist PREFIX=/usr/local ...
   ```

4. Inspect staged metadata and binaries for stale prefix values.

5. For language runtimes, run the test commands documented in each package
   `REPORT.md`.

6. Regenerate plist files only if the installed file set changes.

## 6. Current Assessment

Changing the prefix convention from `/usr` to `/usr/local` is moderate effort.

The plist files themselves are likely not the main problem because they are
relative. The main effort is rebuild and verification of generated artifacts.
The highest risk is in language runtimes and packages that intentionally alter
`PREFIX` or embed runtime paths.

## 7. C23 And Modern Compiler Compatibility

Newer compilers can expose old C compatibility problems during the configure
and build phases. This is especially visible for bootstrap packages that carry
old generated autoconf, gnulib, or bundled dependency sources.

The failures are not always caused by the uports configure framework itself,
but configure decides which compiler, flags, generated headers, and probe
results flow into the build:

```make
GNU_CONFIGURE = yes
CONFIGURE_ENV += CC="$(CC)" CFLAGS="$(CFLAGS)" CPPFLAGS="$(CPPFLAGS)"
CONFIGURE_ARGS += --prefix=$(PREFIX)
```

Therefore C standard compatibility is part of configure policy for uports.

Observed examples:

- `devel/m4`: GNU m4 1.4.19's bundled gnulib selected a C23-style
  `[[__nodiscard__]]` spelling in a position that was not valid for the old
  generated inline definitions. The port carries a patch that prefers the GNU
  `__attribute__((__warn_unused_result__))` spelling when available.
- `devel/pkg-config`: pkg-config 0.29.2 builds with `--with-internal-glib`.
  The bundled old GLib used `bool` as a private union member name in
  `glib/glib/goption.c`. C23 makes `bool` a keyword, so the port carries a
  patch that renames the private member to `boolean`.

Common C23 or modern-C breakage patterns include:

- new C23 keywords such as `bool`, `true`, `false`, `alignas`, `alignof`,
  `static_assert`, and `thread_local` colliding with old identifiers;
- old-style or unprototyped function declarations;
- implicit `int` and implicit function declarations becoming hard errors under
  newer compiler defaults or distro hardening flags;
- generated autoconf or gnulib headers selecting newer syntax that the old
  source placement rules cannot support;
- configure probes that succeed or fail differently after the compiler default
  C dialect changes.

Preferred uports policy:

1. Prefer upstream or distro patches when they are available and narrow.

2. Patch the package source when the incompatibility is small and local. This is
   the right approach for private identifiers, missing prototypes, and generated
   header mistakes in old release tarballs.

3. Patch generated release files when the bootstrap package should not require
   maintainer tools. For early bootstrap packages, avoid forcing `autoreconf`
   unless the port already has that dependency and flow.

4. Use a per-port compiler dialect override only when source patching would be
   too invasive. For example:

   ```make
   CFLAGS += -std=gnu17
   ```

   This should be documented in the port Makefile or `REPORT.md`, including why
   the source was not patched.

5. Do not globally downgrade the uports compiler dialect. A global
   `-std=gnu17` or similar setting would hide real package bugs and could change
   newer packages unexpectedly.

6. If the same compatibility pattern appears across many ports, add a narrow
   framework knob or `USES` helper later. The knob should be opt-in per port and
   should not silently change every build.

This matches the general direction used by larger source-based packaging
systems: patch package sources or backport upstream fixes first, use per-package
language-standard flags as a fallback, and avoid global compiler downgrades.

## 8. Multiple Configure Variants

Some packages need more than one valid configure result. `lang/gforth` is the
current example:

- default build: libffi foreign interface enabled, libffcall disabled;
- optional build: libffi foreign interface enabled, libffcall enabled with
  `WITH_LIBFFCALL=yes`.

The default package should stay small and stable, but the framework should also
support building the optional variant without carrying local Makefile hacks or
manual plist edits.

The preferred uports direction is:

1. align with FreeBSD ports first;
2. add uports extensions only where FreeBSD-compatible concepts are not enough;
3. let the wrapper/project layer select the actual variant for a build.

For configure-time variants, the preferred model is FreeBSD-style flavors.

### Proposed Flavor Model

Add a `FLAVORS` mechanism to uports for packages that need multiple configure
variants from one package directory.

Example target shape for `lang/gforth`:

```make
FLAVORS = default libffcall
FLAVOR ?= default

WITH_LIBFFCALL = no

ifeq ($(FLAVOR),libffcall)
WITH_LIBFFCALL = yes
PKGNAMESUFFIX += -libffcall
endif
```

The package Makefile can then keep one configure policy:

```make
LIB_DEPENDS = libffi.so:devel/libffi \
              libltdl.so:devel/libltdl

ifeq ($(WITH_LIBFFCALL),yes)
LIB_DEPENDS += libavcall.so:devel/libffcall
GFORTH_LIBCC_IMAGE_DEPS += $$(buildccdir)/libgffflib.la
else
CONFIGURE_ENV += ac_cv_lib_avcall___builtin_avcall=no
endif
```

The framework should make `FLAVOR` part of the build identity so different
configure variants do not collide:

- work directory or type suffix;
- package name;
- package artifact name;
- plist substitutions;
- dependency resolution once `BUILD_DEPENDS` and `LIB_DEPENDS` are automated.

For example, the default flavor can produce:

```text
gforth-0.7.9.20260513
```

and the libffcall flavor can produce:

```text
gforth-libffcall-0.7.9.20260513
```

The exact package naming rule can be refined, but separate package identity is
important because both variants have different dependency and file-set
contracts.

### Why Not Only `WITH_LIBFFCALL=yes`

A raw `WITH_LIBFFCALL=yes` variable is useful for local testing, but it is not
enough as the long-term package model because it does not automatically provide:

- distinct package identity;
- distinct dependency metadata;
- distinct build directories;
- install-manifest substitution;
- wrapper-level selection policy.

The wrapper can still set `WITH_LIBFFCALL=yes` internally, but the user-facing
and framework-visible selector should be `FLAVOR=libffcall`.

### Wrapper Role

The project wrapper should decide which flavor is active during a real build.
That can be exposed through environment variables or higher-level project
configuration, in the same spirit as `DESTDIR`, `PREFIX`, and source-selection
variables.

Example:

```sh
make V=1 package FLAVOR=libffcall PREFIX=/usr/local ...
```

For packages without flavors, the default behavior remains unchanged.

## 9. Flavor Implementation Effort

Adding `FLAVORS` support to uports is medium to high effort, depending on how
complete the first implementation should be.

### Minimal Useful Version

Estimated effort: medium.

The goal is to allow one port directory to build multiple variants with
different package identity and configure options.

Required pieces:

1. Add and validate flavor variables:

   ```make
   FLAVORS =
   FLAVOR ?=
   ```

   `FLAVOR` should be empty/default or one of the entries in `FLAVORS`.

2. Make `FLAVOR` affect build identity.

   Flavor-specific builds must not reuse the same work, stage, plist, or package
   artifacts. At minimum, the framework should separate:

   ```text
   WRKDIR
   STAGEDIR
   TMPPLIST
   build cookies
   install cookies
   package artifact path
   ```

3. Let package Makefiles branch on `FLAVOR`.

   Example:

   ```make
   ifeq ($(FLAVOR),libffcall)
   WITH_LIBFFCALL = yes
   PKGNAMESUFFIX += -libffcall
   endif
   ```

4. Make package identity flavor-aware.

   This can be explicit through `PKGNAMESUFFIX`, or the framework can provide a
   default naming rule. For example:

   ```text
   gforth-0.7.9.20260513
   gforth-libffcall-0.7.9.20260513
   ```

5. Let the wrapper/project layer pass the selected flavor:

   ```sh
   make V=1 package FLAVOR=libffcall ...
   ```

This minimal version is enough for gforth-style configure variants, assuming
`PLIST_SUB` also exists for install-manifest differences.

### Complete Version

Estimated effort: high.

A full framework-level implementation should also handle:

- flavor-aware dependency resolution;
- flavor-aware package repository and index metadata;
- flavor-aware cache and package lookup;
- targets such as `all-flavors`, `package-all-flavors`, and `clean-flavors`;
- flavor-specific plist substitution;
- flavor-specific conflicts and package metadata;
- documentation and examples.

### Main Risk

The hard part is not parsing `FLAVOR`; it is preventing cross-flavor artifact
reuse.

If any generated state is shared by mistake, one flavor can silently reuse stale
configure, build, stage, or plist results from another flavor. Therefore flavor
must be part of every build identity boundary that affects output.

Important boundaries:

```text
WRKDIR
STAGEDIR
TMPPLIST
PKGNAME
PKGFILE
configure/build/stage/package cookies
package metadata
```

### Recommended Phasing

1. Implement `PLIST_SUB` first or alongside `FLAVORS`.

   For `lang/gforth`, flavor support without plist substitution still leaves
   the `libgffflib.*` manifest problem.

2. Implement minimal `FLAVOR` support:

   - validation;
   - flavor-specific work/stage/plist/package artifacts;
   - package identity;
   - wrapper pass-through.

3. Convert `lang/gforth` as the first real test case:

   ```make
   FLAVORS = default libffcall
   FLAVOR ?= default
   ```

4. Add `package-all-flavors` and repository/index integration later.

Practical estimate:

- focused minimal version: 1-2 days;
- robust framework-level implementation: several days to one week, depending on
  dependency/index/package repository coverage.
