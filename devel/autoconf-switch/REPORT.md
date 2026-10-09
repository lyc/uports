# Autoconf command wrappers

This package provides the unsuffixed Autoconf command interface and declares
the `devel/autoconf` capability. Its runtime dependency installs
`devel/autoconf-2.72`, whose executables and macro directory use version
suffixes. Consumers therefore resolve through the wrapper package, with the
versioned implementation installed first.

The wrapper derives its bin and data directories from its own installed path.
It supplies Autoconf's supported Perl-library, macro-directory, trailer, and
tool overrides so cached packages built for another DESTDIR remain usable via
the unsuffixed commands. Explicit caller overrides are preserved. A sibling
m4 executable is preferred when M4 is unset. Direct version-suffixed commands
retain their upstream behavior and may still require explicit overrides after
relocation.

Linux verification used cached m4, Autoconf 2.72, and wrapper packages installed
into a temporary root. With the revised wrapper, `autoreconf -f -i` generated
a configure script for a minimal AC_PROG_CC project, and `./configure` produced
config.status. The original wrapper failed to locate its embedded source
installation's Perl modules and macros.

Darwin arm64 verification on macOS 26.6.2 used fresh isolated m4, Autoconf
2.72, and wrapper installations. Apple's `sort` 2.3 supports `-V` and selected
2.10 after 2.9 in a direct probe. With the validated native `aclocal` on PATH,
the unsuffixed wrapper selected Autoconf 2.72, generated the same minimal
configure script, and configure produced `config.status` without manual
Autoconf path overrides.

Smoke test after installation:

```sh
PATH="$DESTDIR/usr/local/bin:$PATH" autoreconf -f -i
./configure
test -s config.status
```
