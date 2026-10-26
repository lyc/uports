#!/bin/sh

set -eu

output=$1
dependency_report=$2
source_state=$3
temporary=$output.tmp.$$
trap 'rm -f "$temporary"' EXIT HUP INT TERM
: > "$temporary"
if [ -n "$dependency_report" ]; then
	[ -r "$dependency_report" ] || {
		printf '  ERR     dependency provenance is not readable: %s\n' \
		    "$dependency_report" >&2
		exit 1
	}
	cat "$dependency_report" >> "$temporary"
fi
[ -r "$source_state" ] || {
	printf '  ERR     source state is not readable: %s\n' "$source_state" >&2
	exit 1
}
sed 's/^/source-state|/' "$source_state" >> "$temporary"
mv -f "$temporary" "$output"
