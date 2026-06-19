# Parse-Time Shell Inventory

This is a static inventory of shell-function work in `Tools/tools.mk` before
optimization.

## Phase 2A Update

After Phase 2A, an ordinary planner invocation requires only collection
discovery:

```text
generate-ports-lists for built-in uports
generate-ports-lists for FEEDS when configured
```

The following work is deferred until `info.ports` is requested:

```text
uname -s and tr for operating-system identity
uname -m for architecture identity
stty/awk and tput/echo for terminal width
```

`which echo` and the platform-suffixed `pecho` probe were removed. Pkg-config
path composition now uses make string functions rather than `echo | sed`.
`which pkg-config` remains target-specific to `info.debug.targets`.

## Ordinary Planner Invocation

Expected `$(shell ...)` evaluations:

```text
collection discovery
  generate-ports-lists for built-in uports
  generate-ports-lists for FEEDS when configured

host metadata
  which echo
  uname -s for pecho selection
  uname -s and tr for info operating-system identity
  uname -m for info architecture identity

terminal presentation
  stty/awk unless COLUMNS is already defined
  tput/echo if stty does not produce a width

pkg-config path composition
  echo/sed through merge while PKG_CONFIG_LIBDIR is assigned
```

This is normally seven to nine make shell-function evaluations, depending on
whether a feed exists, `COLUMNS` is set, and terminal probing succeeds.
Pipelines may create more operating-system processes than the number of make
shell-function evaluations.

The count above is the original pre-Phase-2A baseline.

## Deferred Or Target-Specific Sites

The following sites are not required for an ordinary planner invocation:

```text
merge calls expanded only by later recipes
which pkg-config in info.debug.targets
commented PKGCONFIG_LIST discovery
```

This inventory is intentionally separate from per-port framework parsing.
`Tools/benchmark-tools.sh` invokes only `planner-stats`; it does not enter port
Makefiles or run package lifecycle recipes.
