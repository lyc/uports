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
installation's Perl modules and macros. macOS runtime validation is pending;
the existing version-selection code still uses `sort -V`.

Smoke test after installation:

```sh
PATH="$DESTDIR/usr/local/bin:$PATH" autoreconf -f -i
./configure
test -s config.status
```
