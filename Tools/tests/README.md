# Real-world validation

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
There is deliberately no generic `check` alias that silently changes the
meaning of the former regression command.
