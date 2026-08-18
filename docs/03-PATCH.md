# uports Patch Design

## 1. Main Source Patches

uports supports two patch methods for the main source tree:

```make
USE_PATCH= V1
```

uses the traditional `patch`-based ports workflow. The default:

```make
USE_PATCH= V2
```

applies patches produced by `git format-patch` with `git am`. V2 patch files
are stored in `$(PATCHDIR)` and listed in a `series` file.

The framework selects the first existing series file in this order:

```text
series.<OPSYS>-<OPSYS_SUFX>-<ARCH>
series.<OPSYS>-<OPSYS_SUFX>
series.<OPSYS>-<ARCH>
series.<OPSYS>
series
```

The two `OPSYS_SUFX` forms are omitted when `OPSYS_SUFX` is empty.

## 2. Submodule Patch Metadata

Ports that need patches in Git submodules declare each submodule explicitly,
in dependency-safe order:

```make
SCM_SUBMODULES= third_party/foo third_party/bar
```

The default patch layout mirrors the submodule path below the port's files
directory:

```text
files/
`-- submodules/
    |-- third_party/foo/
    |   |-- series
    |   `-- 0001-example.patch
    `-- third_party/bar/
        |-- series.linux-amd64
        `-- 0001-example.patch
```

The public variables are:

```make
SCM_SUBMODULES          ?=
SUBMODULE_PATCHDIR      ?= $(PATCHDIR)/submodules
SUBMODULE_PATCH_METHOD  ?= $(PATCH_METHOD)
```

`SCM_SUBMODULES` contains paths relative to `$(WRKSRC)`. Absolute paths,
parent traversal, empty components, backslashes, and paths that resolve outside
`$(WRKSRC)` are invalid. Duplicate declarations are also invalid. Each
submodule directory uses the same platform series selection order as the main
source tree.

## 3. Slice 1 Diagnostics

Slice 1 introduces metadata and read-only inspection only. From a port
directory, run:

```sh
make info.debug.submodules
```

The report preserves declaration order and shows the expected Git link commit,
current checkout, initialization and dirty status, selected patch method,
selected series file, patch count, and normalized state for every declaration.
Possible states are:

```text
ready
uninitialized
missing-gitlink
commit-mismatch
dirty
invalid-path
duplicate
parent-not-git
```

This target does not initialize or update submodules, access the network, change
a checkout, or apply patches. Those lifecycle operations belong to later
implementation slices.
