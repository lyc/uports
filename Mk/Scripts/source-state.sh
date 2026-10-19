#!/bin/sh

set -eu

fail()
{
	printf '  ERR     source state: %s\n' "$*" >&2
	exit 1
}

mode=${1:-}
[ "$mode" = check ] || [ "$mode" = save ] ||
	fail 'mode must be check or save'
: "${SOURCE_STATE_FILE:?}" "${SOURCE_STATE_MODE:?}"

current=$(mktemp "${TMPDIR:-/tmp}/uports-source-state.XXXXXX")
saved=$(mktemp "${TMPDIR:-/tmp}/uports-source-saved.XXXXXX")
trap 'rm -f "$current" "$saved" "$current.tmp"' EXIT HUP INT TERM

{
	printf 'source-state|1\n'
	printf 'request-key|%s\n' "${SOURCE_STATE_REQUEST_KEY:--}"
	printf 'mode|%s\n' "$SOURCE_STATE_MODE"
	printf 'provider|%s\n' "${SOURCE_STATE_PROVIDER:--}"
	printf 'repository|%s\n' "${SOURCE_STATE_REPOSITORY:--}"
	printf 'ref-kind|%s\n' "${SOURCE_STATE_REF_KIND:-default}"
	printf 'ref|%s\n' "${SOURCE_STATE_REF:--}"
	printf 'root|%s\n' "${SOURCE_STATE_ROOT:--}"
	printf 'archives|%s\n' "${SOURCE_STATE_ARCHIVES:--}"
	printf 'layout|%s\n' "${SOURCE_STATE_LAYOUT:--}"
} > "$current"

if [ -f "$SOURCE_STATE_FILE" ]; then
	sed -e '/^resolved-commit|/d' -e '/^worktree-dirty|/d' \
		"$SOURCE_STATE_FILE" > "$saved"
fi

if [ ! -f "$SOURCE_STATE_FILE" ]; then
	state=new
elif cmp -s "$current" "$saved"; then
	state=unchanged
else
	state=changed
fi

if [ "$mode" = check ]; then
	[ "$state" = unchanged ] && exit 0
	identity_state=$SOURCE_STATE_FILE.${SOURCE_STATE_REQUEST_KEY:--}
	if [ -r "$identity_state" ] && [ -d "${SOURCE_STATE_PATH:-}" ]; then
		# Reuse the preserved extraction/patch history for this identity.
		# Configure onward writes shared stage/package artifacts afresh.
		for cookie in ${SOURCE_STATE_SHARED_COOKIES:-}; do
			rm -f -- "$cookie"
		done
		cp "$identity_state" "$SOURCE_STATE_FILE"
	else
		for cookie in ${SOURCE_STATE_COOKIES:-}; do
			rm -f -- "$cookie"
		done
	fi
	for artifact in ${SOURCE_STATE_ARTIFACTS:-}; do
		rm -f -- "$artifact"
	done
	exit 0
fi

[ -d "${SOURCE_STATE_PATH:-}" ] ||
	fail "source root does not exist: ${SOURCE_STATE_PATH:-}"
resolved=-
dirty=no
if [ "$SOURCE_STATE_MODE" = git ]; then
	[ -e "$SOURCE_STATE_PATH/.git" ] ||
		fail "Git source has no repository: $SOURCE_STATE_PATH"
	resolved=$(git -C "$SOURCE_STATE_PATH" rev-parse HEAD) ||
		fail 'cannot resolve Git commit'
	status=$(git -C "$SOURCE_STATE_PATH" status --porcelain \
		--untracked-files=all) || fail 'cannot inspect Git status'
	[ -z "$status" ] || dirty=yes
fi
printf 'resolved-commit|%s\n' "$resolved" >> "$current"
printf 'worktree-dirty|%s\n' "$dirty" >> "$current"
directory=${SOURCE_STATE_FILE%/*}
[ "$directory" != "$SOURCE_STATE_FILE" ] || directory=.
mkdir -p "$directory"
temporary=$SOURCE_STATE_FILE.tmp.$$
trap 'rm -f "$current" "$saved" "$temporary"' EXIT HUP INT TERM
cp "$current" "$temporary"
mv -f "$temporary" "$SOURCE_STATE_FILE"
cp "$SOURCE_STATE_FILE" "$SOURCE_STATE_FILE.${SOURCE_STATE_REQUEST_KEY:--}"
