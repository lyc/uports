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
SUBMODULE_UPDATE_ARGS   ?= --init --checkout
SUBMODULE_GIT_AM_OPTS   ?= $(GIT_AM_OPTS)
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
patched
dirty
invalid-path
duplicate
parent-not-git
```

This target does not initialize or update submodules, access the network, change
a checkout, or apply patches. Those lifecycle operations belong to later
implementation slices.

## 4. Slice 2 Preparation

When `SCM_SUBMODULES` is nonempty, the patch lifecycle prepares the declared
submodules before `pre-patch`, patch scripts, or the `do-patch` action runs.
The same operation can be invoked directly:

```sh
make prepare-submodules
```

Preparation has two phases. The first phase validates every declaration without
changing the work tree. It rejects:

- invalid or duplicate paths;
- paths without a gitlink at the parent `HEAD`;
- paths not registered in `.gitmodules`;
- paths that resolve outside `$(WRKSRC)`;
- dirty initialized checkouts;
- nonempty uninitialized paths and non-directory obstructions.

Only after every declaration passes validation does the second phase run
`git submodule update --init --checkout` for each path, in declaration order.
This initializes missing checkouts and changes clean mismatched checkouts to the
exact commit stored in the parent gitlink. Each result is verified for both the
expected commit and a clean work tree.

Submodule retrieval inherits `SCM_FETCH_ENV` and `SCM_TIMEOUT_CMD` from the SCM
fetch framework. Git uses an existing local submodule object database first and
contacts the configured submodule transport only when required objects are not
available locally. `SUBMODULE_UPDATE_ARGS` may be overridden when a port needs
additional `git submodule update` options.

Slice 2 does not apply submodule patches. Patch execution remains a separate
lifecycle operation for the next implementation slice.

## 5. Slice 3 Patch Application

The patch lifecycle applies submodule patches after the main source `do-patch`
action and before `post-patch`. This ordering keeps submodule commits from
making the parent work tree dirty while the parent's own `git am` series runs.
The operation is also available directly after preparation:

```sh
make apply-submodule-patches
```

Submodule series use the platform selection order documented above. Each
nonblank, noncomment line contains one patch filename relative to that
submodule's patch directory. Patch entries must be direct filenames; absolute
paths, parent traversal, subdirectories, and backslashes are rejected.

Slice 3 supports `SUBMODULE_PATCH_METHOD=V2`. Each listed file must be a
`git format-patch` email patch and is applied with `git am` plus
`SUBMODULE_GIT_AM_OPTS`. A port whose main source uses V1 can select V2 only for
its submodules:

```make
USE_PATCH= V1
SUBMODULE_PATCH_METHOD= V2
```

After a V2 series is applied, `info.debug.submodules` reports `patched` when
the checkout is a clean descendant of its gitlink and the descendant commit
count matches the selected series entry count. Other clean divergences remain
`commit-mismatch`.

Before the first patch is applied, the framework validates all declarations,
gitlinks, clean checkouts, selected series, and referenced patch files. Each
submodule must still be at the exact commit recorded by the parent `HEAD`.
When a patch fails, the active `git am` is aborted and that entire submodule
series is reset to its clean starting commit. Series already completed in an
earlier submodule are retained; rerunning the full patch lifecycle starts by
preparing all declared submodules back to their parent gitlinks.

Traditional V1 patching, quilt registration, and arbitrary file-copy actions
are intentionally outside this mechanism. Existing port hooks remain available
for non-patch file installation or generated-file work.
