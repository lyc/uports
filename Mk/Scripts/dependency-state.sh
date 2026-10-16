#!/bin/sh

set -eu

fail()
{
	printf '  ERR     %s\n' "$*" >&2
	exit 1
}

mode=${1:-}
[ "$mode" = check ] || [ "$mode" = save ] || [ "$mode" = invalidate ] ||
	[ "$mode" = current ] ||
	fail 'dependency state mode must be check, save, invalidate, or current'
[ -n "${DEPENDENCY_STATE_SOURCE:-}" ] ||
	fail 'missing DEPENDENCY_STATE_SOURCE'
[ -n "${DEPENDENCY_STATE_FILE:-}" ] ||
	fail 'missing DEPENDENCY_STATE_FILE'
[ -f "$DEPENDENCY_STATE_SOURCE" ] ||
	fail "dependency state source does not exist: $DEPENDENCY_STATE_SOURCE"

source_normalized=$(mktemp "${TMPDIR:-/tmp}/uports-dependency-state-source.XXXXXX")
saved_normalized=$(mktemp "${TMPDIR:-/tmp}/uports-dependency-state-saved.XXXXXX")
trap 'rm -f "$source_normalized" "$saved_normalized" "$source_normalized.build" "$saved_normalized.build"' EXIT HUP INT TERM

normalize_state()
{
	awk -F '|' 'BEGIN { OFS = "|" }
	$1 == "instance" {
		count = split($6, values, " ")
		environment = ""
		for (i = 1; i <= count; i++) {
			if (values[i] ~ /^(USE_GLOBALBASE|DISTDIR_SITE|PACKAGES_SITE|SCMDIR_SITE)=/)
				continue
			environment = environment (environment == "" ? "" : " ") values[i]
		}
		$6 = environment
	}
	{ print }' "$1"
}

normalize_state "$DEPENDENCY_STATE_SOURCE" > "$source_normalized"
if [ -f "$DEPENDENCY_STATE_FILE" ]; then
	normalize_state "$DEPENDENCY_STATE_FILE" > "$saved_normalized"
fi

if [ ! -f "$DEPENDENCY_STATE_FILE" ]; then
	state=new
elif cmp -s "$source_normalized" "$saved_normalized"; then
	state=unchanged
else
	state=changed
fi

[ "$mode" != current ] || {
	[ "$state" = unchanged ]
	exit
}

printf 'dependency_state = %s\n' "$state"

[ "$mode" != invalidate ] || {
	[ "$state" = unchanged ] && exit 0
	[ -n "${DEPENDENCY_STATE_COOKIES:-}" ] ||
		fail 'missing DEPENDENCY_STATE_COOKIES'
	# A stage request can also carry a changed configure/build projection.
	if grep -q '^build-state|' "$source_normalized"; then
		grep '^build-state|' "$source_normalized" > "$source_normalized.build"
		grep '^build-state|' "$saved_normalized" > "$saved_normalized.build" || :
		if ! cmp -s "$source_normalized.build" "$saved_normalized.build"; then
			if [ -n "${DEPENDENCY_STATE_BUILD_MARKER:-}" ]; then
				mkdir -p "${DEPENDENCY_STATE_BUILD_MARKER%/*}"
				: > "$DEPENDENCY_STATE_BUILD_MARKER"
			fi
			for cookie in ${DEPENDENCY_STATE_BUILD_COOKIES:-}; do
				rm -f -- "$cookie"
			done
		fi
		rm -f "$source_normalized.build" "$saved_normalized.build"
	fi
	if [ -n "${DEPENDENCY_STATE_REBUILD_MARKER:-}" ]; then
		mkdir -p "${DEPENDENCY_STATE_REBUILD_MARKER%/*}"
		: > "$DEPENDENCY_STATE_REBUILD_MARKER"
	fi
	for cookie in $DEPENDENCY_STATE_COOKIES
	do
		rm -f -- "$cookie"
	done
	for artifact in ${DEPENDENCY_STATE_ARTIFACTS:-}
	do
		rm -f -- "$artifact"
	done
	exit 0
}

[ "$mode" = save ] || exit 0
[ "$state" != unchanged ] || exit 0
directory=${DEPENDENCY_STATE_FILE%/*}
[ "$directory" != "$DEPENDENCY_STATE_FILE" ] || directory=.
mkdir -p "$directory"
temporary=$DEPENDENCY_STATE_FILE.tmp.$$
trap 'rm -f "$source_normalized" "$saved_normalized" "$temporary"' EXIT HUP INT TERM
cp "$source_normalized" "$temporary"
mv -f "$temporary" "$DEPENDENCY_STATE_FILE"
