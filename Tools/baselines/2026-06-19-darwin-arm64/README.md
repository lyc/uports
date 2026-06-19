# tools.mk Baseline: Darwin arm64, 2026-06-19

This directory records the pre-optimization warm-cache baseline for
`Tools/tools.mk`.

Environment:

```text
GNU Make 4.4.1
macOS 26.5.1 (Build 25F80)
Darwin 25.5.0
arm64
```

Each scenario used seven timing runs. Paths are normalized to `<project>` and
`<uports>` so the snapshots are portable as historical records.

Commands:

```sh
make/uports/Tools/benchmark-tools.sh -C . -n 7 -l full

make/uports/Tools/benchmark-tools.sh -C . -n 7 -l cpython \
  PORTS_LISTS=lang/cpython

make/uports/Tools/benchmark-tools.sh -C . -n 7 -l host-group \
  PORTS_LISTS='host@devel/pkg-config host@devel/cmake'

Tools/benchmark-tools.sh -C Tools/tests -n 7 -l multi-group
```

The first three commands run from the parent example project. The multi-group
command runs from the uports submodule.

Maximum resident memory is `unavailable` because the Darwin `/usr/bin/time`
implementation could not provide reliable memory output in the execution
environment.

These values are comparison baselines, not universal performance budgets.
Timing comparisons must use the same host and environment.

