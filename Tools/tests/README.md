# Real-world validation

For W06D, run from the parent project:

```sh
python3 make/uports/Tools/tests/w06d/check-pkg-removal-live.py
```

This uses real cached gforth Flavors and bootstrap archives. To reproduce legacy
overlap, it reads the earlier production pkg.sh from commit 54bba9d in this
repository's history and installs only into temporary destinations. It never
checks out or edits another preserved instance. Current pkg.sh removal checks
retain the other Flavor's files/shared empty directories and bootstrap, validate
previews/bulk cleanup, reject invalid/missing ownership data, and coordinate
concurrent mutations through aliases. Full per-case output and final status
are under /tmp/uports-w06d-manual.*/; /tmp/uports-w06d-latest records the latest
directory. Cache hashes are checked unchanged. No builds or real installation
changes. Python handles snapshots/concurrency; the package tool remains shell.

For W06C, run from the parent project:

```sh
python3 make/uports/Tools/tests/w06c/check-pkg-conflicts-live.py
```

This copies only pkg.sh and uses existing real gforth default/libffcall/bootstrap
archives. It checks exact reinstalls, opposite-Flavor conflicts in both orders,
shared directories, unmanaged files, type conflicts, symlink parents and
concurrent installs through destination aliases. All installation data stays
under /tmp/uports-w06c-manual.*/; original cache hashes are checked unchanged.
The script records expected command exits, full per-case output and overall
status; /tmp/uports-w06c-latest points to the saved evidence directory. No
builds or existing installation changes are performed. Linux x86_64 only.

For W06B, run from the parent project:

```sh
bash make/uports/Tools/tests/w06b/check-pkg-standalone-live.sh
```

This uses existing staged gforth default/libffcall files without building or
changing them. It copies only pkg.sh and creates manifests, packages and
installation destinations under /tmp/uports-w06b-manual.*/. The script saves
output and final exit status in validation.log; deletion previews have separate
per-case logs. /tmp/uports-w06b-latest records the evidence directory for review.
It exercises production package operations directly, bypassing wrapper/source
preparation. Expected rejection messages are deliberate checks. Both Flavor
PASS markers and exit=0 indicate success. Native macOS/ARM64 are not covered.

[manifest.json](manifest.json) is the authoritative
mapping between feature implementation commits and real-world test scripts.
The slice 6 registered commit includes source-selection and global-cache fixes.
Add future cases and their actual implementation commits to this manifest;
do not infer implementation identity from the current checkout's HEAD.

Run from the framework root:

```sh
make -C Tools/tests list
make -C Tools/tests slice6
make -C Tools/tests slice7
make -C Tools/tests slice8
```

Or run the script directly:

```sh
python3 Tools/tests/slice6/check-mxml-source-live.py
```

The script exercises the real parent Mini-XML port. It requires Linux,
Python 3, GNU make, Git, a C toolchain, normal port build/package tools, and
network access to GitHub. The parent project must contain Mini-XML 4.0.5 and
its maintained `distinfo`; this is not a standalone synthetic fixture.

Wrapper fetch uses normal project dependency policy. Isolated direct-port
build/package checks use `UPORTS_DEPENDENCIES=none` and `PREFIX=/usr` with a
temporary DESTDIR. Only `*_SITE` settings select cache directories. Commands
keep stdin open, and output plus exit statuses are recorded in
`/tmp/uports-mxml-slice6.*/validation.log`. The script prints the retained
directory. It deletes only its own temporary archive to exercise refetch;
existing caches, installations and developer work are preserved.

Darwin and different-version application migration are not covered. Detailed
validation results and current closeout status belong in
[the workstream handoff](../../HANDOFF.md).

Slice 7 uses actual Mini-XML and ad-libitum ports and checkouts, not synthetic
fixtures. Mini-XML supplies a real build/package and upstream runtime tests;
ad-libitum supplies actual declared submodules and maintained patch series.
Offline, update and concurrency checks use local mirror copies of the real
downloaded repositories. Developer edits and failure conditions are introduced
only into new temporary copies. Logs and command exit/expected-outcome records
are retained under `/tmp/uports-scm-slice7.*/`. Failures intentionally exercised
by the script are distinguished from unexpected failures.

For a repair rerun, `UPORTS_LIVE_MXML_REPO=/path/to/previous/real/mirror.git`
can reuse previously downloaded Mini-XML history. The default uses GitHub.
Direct port checks use dependency mode `none`, with alternative-source
directories enabled. This does not validate a new parent update alias or full
application installation. The manifest records the slice 7 implementation
commit separately from commits that register or update its validation script.

All previous regression scripts, fixtures, Makefiles and generated work were
moved to [Tools/tests-backup](../tests-backup/README.md). They are inactive;
no active target invokes them. Running `make -C Tools/tests` prints help only.

Slice 8 validates the actual Elk release and pinned Git revision on Linux.
Parent fetches use instance-scoped source selection, preserving the ordinary
dependency planner. Isolated direct-port builds use dependency mode `none`
and the native host Autotools/toolchain. Both modes package, load the staged
runtime and native regexp/UNIX extensions, and check repeat preservation.
Release checks use maintained distinfo. A cached real Elk mirror is copied
when available; no existing checkout is rebuilt or reset. Evidence is retained
under `/tmp/uports-elk-slice8.*/`. `UPORTS_LIVE_ELK_REPO` and
`UPORTS_LIVE_ELK_DISTDIR` can reuse previous real source downloads during
repairs. Darwin remains unverified. Parent migration commits intentionally
remain unset until fetch enhancement is finished and the user authorizes them.
There is deliberately no generic `check` alias that silently changes the
meaning of the former regression command.
