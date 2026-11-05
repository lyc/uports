#!/bin/sh

set -eu

root=$1
plist=$2
temporary=$(mktemp -d "${TMPDIR:-/tmp}/uports-plist-check.XXXXXX")
trap 'rm -rf -- "$temporary"' EXIT HUP INT TERM

[ -d "$root" ] || {
	printf '  ERR     staged prefix is missing: %s\n' "$root" >&2
	exit 1
}
[ -r "$plist" ] || {
	printf '  ERR     package manifest is not readable: %s\n' "$plist" >&2
	exit 1
}
LC_ALL=C sort "$plist" > "$temporary/expected"
(cd "$root" && find . -print) > "$temporary/inventory"
sed '/^\.$/d' "$temporary/inventory" > "$temporary/paths"
LC_ALL=C sort "$temporary/paths" > "$temporary/actual"
if ! diff -u "$temporary/expected" "$temporary/actual"; then
	printf '  ERR     package manifest differs from staged contents\n' >&2
	exit 1
fi
