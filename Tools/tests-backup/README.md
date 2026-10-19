# Archived regression tests

The previous contents of `Tools/tests`, except the real Mini-XML slice 6
script, were moved here on 2026-10-19. Scripts, fixtures, the original Makefile
and locally generated work are preserved. `archive-inventory.json` records
SHA256 hashes of moved files and the exact targets of moved symlinks.
Generated work may remain ignored by Git, but is retained on disk.

This is a backup, not an active test suite. Do not run it unless the user
explicitly requests regression testing again. No active test target calls
this folder. Archived scripts may assume their original `Tools/tests` path;
they have not been rewritten or revalidated for execution from this location.
Any future restoration must use an isolated checkout and preserve the active
real-world test layout.
