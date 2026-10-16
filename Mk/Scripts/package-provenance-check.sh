#!/bin/sh
# Read only the text header; stop before the binary payload.
set -eu
archive=$1
report=$2
prefix=$3
actual=$(mktemp "${TMPDIR:-/tmp}/uports-package-actual.XXXXXX")
expected=$(mktemp "${TMPDIR:-/tmp}/uports-package-expected.XXXXXX")
trap 'rm -f "$actual" "$expected"' EXIT HUP INT TERM
awk -v prefix="$prefix" '
NR == 1 && $0 != "PVER: 2" { exit 1 }
NR == 5 && $0 != "PREFIX: " prefix { exit 1 }
NR == 9 { if ($0 != "PROVENANCE: %%%%%-PROVENANCE") exit 1; next }
NR > 9 { if ($0 == "%%%%%-PROVENANCE") { complete=1; exit }; print }
END { if (!complete) exit 1 }
' "$archive" > "$actual" || exit 1
# Lifecycle phase and record ordering do not change provider identity.
awk -F '|' '$1 != "request" { print }' "$actual" | LC_ALL=C sort > "$expected"
awk -F '|' '$1 != "request" { print }' "$report" | LC_ALL=C sort > "$actual"
cmp -s "$actual" "$expected"
