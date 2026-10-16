#!/bin/sh
# Generate stage state together with its configure/build dependency projection.
set -eu
planner=$1
shift
input=$(mktemp "${TMPDIR:-/tmp}/uports-state-input.XXXXXX")
state=$(mktemp "${TMPDIR:-/tmp}/uports-state-output.XXXXXX")
trap 'rm -f "$input" "$state" "$state.build"' EXIT HUP INT TERM
cat > "$input"
awk -v state=1 "$@" -f "$planner" "$input" > "$state"
cat "$state"
node=$(awk -F '|' '$1 == "request" { if (++n == 1 && $3 == "stage") node=$2; else node="" } END { print node }' "$state")
if [ -n "$node" ]; then
    awk -v state=1 "$@" -v request_override="$node" \
        -v request_override_phase=configure -f "$planner" "$input" > "$state.build"
    sed 's/^/build-state|/' "$state.build"
fi
