#!/bin/sh

set -eu

fail()
{
	printf '  ERR     %s\n' "$*" >&2
	exit 1
}

mode=${1:-}
[ "$mode" = check ] || [ "$mode" = save ] || [ "$mode" = invalidate ] ||
	fail 'dependency state mode must be check, save, or invalidate'
[ -n "${DEPENDENCY_STATE_SOURCE:-}" ] ||
	fail 'missing DEPENDENCY_STATE_SOURCE'
[ -n "${DEPENDENCY_STATE_FILE:-}" ] ||
	fail 'missing DEPENDENCY_STATE_FILE'
[ -f "$DEPENDENCY_STATE_SOURCE" ] ||
	fail "dependency state source does not exist: $DEPENDENCY_STATE_SOURCE"

if [ ! -f "$DEPENDENCY_STATE_FILE" ]; then
	state=new
elif cmp -s "$DEPENDENCY_STATE_SOURCE" "$DEPENDENCY_STATE_FILE"; then
	state=unchanged
else
	state=changed
fi

printf 'dependency_state = %s\n' "$state"

[ "$mode" != invalidate ] || {
	[ "$state" = unchanged ] && exit 0
	[ -n "${DEPENDENCY_STATE_COOKIES:-}" ] ||
		fail 'missing DEPENDENCY_STATE_COOKIES'
	for cookie in $DEPENDENCY_STATE_COOKIES
	do
		rm -f -- "$cookie"
	done
	exit 0
}

[ "$mode" = save ] || exit 0
[ "$state" != unchanged ] || exit 0
directory=${DEPENDENCY_STATE_FILE%/*}
[ "$directory" != "$DEPENDENCY_STATE_FILE" ] || directory=.
mkdir -p "$directory"
temporary=$DEPENDENCY_STATE_FILE.tmp.$$
trap 'rm -f "$temporary"' EXIT HUP INT TERM
cp "$DEPENDENCY_STATE_SOURCE" "$temporary"
mv -f "$temporary" "$DEPENDENCY_STATE_FILE"
