#!/bin/sh
# Read only the text header; stop before the binary payload.
set -eu
archive=$1
report=$2
prefix=$3
source_state=${4:-}
source_key=${5:-}
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
if [ -n "$source_key" ] &&
    ! grep -Fqx "source-state|request-key|$source_key" "$actual"; then
	exit 1
fi
# Lifecycle phase and record ordering do not change provider identity.
awk -F '|' '$1 != "request" { print }' "$actual" | LC_ALL=C sort > "$expected"
{
	if [ -n "$report" ]; then
		awk -F '|' '$1 != "request" { print }' "$report"
	fi
	if [ -n "$source_state" ]; then
		sed 's/^/source-state|/' "$source_state"
	fi
} | LC_ALL=C sort > "$actual"
cmp -s "$actual" "$expected"
