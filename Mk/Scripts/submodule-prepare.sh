#!/bin/sh

# Validate every declared submodule before changing any checkout, then
# initialize it and select the exact gitlink commit recorded by the parent.

set -eu

: "${WRKSRC:?WRKSRC is required}"

SCM_SUBMODULES=${SCM_SUBMODULES-}
SCM_FETCH_ENV=${SCM_FETCH_ENV-}
SCM_TIMEOUT_CMD=${SCM_TIMEOUT_CMD-}
SUBMODULE_UPDATE_ARGS=${SUBMODULE_UPDATE_ARGS---init --checkout}
GIT=${GIT-git}

fail()
{
	printf '  ERR     submodule %s: %s\n' "$1" "$2" >&2
	exit 1
}

valid_path()
{
	case "$1" in
		""|/*|.|..|../*|*/../*|*/..|./*|*/./*|*//*|*/|*\\*)
			return 1
			;;
	esac
	return 0
}

gitlink()
{
	line=$("$GIT" -C "$WRKSRC" ls-tree HEAD -- "$1" 2>/dev/null || :)
	mode=$(printf '%s\n' "$line" | awk 'NR == 1 { print $1 }')
	type=$(printf '%s\n' "$line" | awk 'NR == 1 { print $2 }')
	hash=$(printf '%s\n' "$line" | awk 'NR == 1 { print $3 }')
	[ "$mode" = 160000 ] && [ "$type" = commit ] && [ -n "$hash" ] ||
		return 1
	printf '%s\n' "$hash"
}

is_registered()
{
	[ -f "$WRKSRC/.gitmodules" ] || return 1
	"$GIT" -C "$WRKSRC" config -f .gitmodules --get-regexp \
		'^submodule\..*\.path$' 2>/dev/null |
		awk -v want="$1" '$2 == want { found=1 } END { exit !found }'
}

set -- $SCM_SUBMODULES
[ "$#" -gt 0 ] || exit 0

"$GIT" -C "$WRKSRC" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
	fail parent 'WRKSRC is not a Git work tree'
root_physical=$(CDPATH= cd -- "$WRKSRC" 2>/dev/null && pwd -P) ||
	fail parent 'cannot resolve WRKSRC'

# Pass one is read-only.  It prevents a late declaration error or dirty tree
# from leaving earlier submodules partially prepared.
seen=
for path in "$@"
do
	valid_path "$path" || fail "$path" 'invalid path'
	case " $seen " in
		*" $path "*) fail "$path" 'duplicate declaration' ;;
	esac
	seen="$seen $path"

	expected=$(gitlink "$path") || fail "$path" 'missing gitlink at parent HEAD'
	is_registered "$path" || fail "$path" 'not registered in .gitmodules'

	dir=$WRKSRC/$path
	if [ -e "$dir" ]; then
		dir_physical=$(CDPATH= cd -- "$dir" 2>/dev/null && pwd -P) ||
			fail "$path" 'cannot resolve checkout path'
		case "$dir_physical" in
			"$root_physical"/*) ;;
			*) fail "$path" 'checkout resolves outside WRKSRC' ;;
		esac
	fi

	if [ -e "$dir/.git" ]; then
		"$GIT" -C "$dir" rev-parse HEAD >/dev/null 2>&1 ||
			fail "$path" 'initialized checkout is not a Git work tree'
		if [ -n "$("$GIT" -C "$dir" status --porcelain \
		    --untracked-files=normal 2>/dev/null || :)" ]; then
			fail "$path" 'checkout is dirty'
		fi
	elif [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null || :)" ]; then
		fail "$path" 'uninitialized checkout path is not empty'
	elif [ -e "$dir" ] && [ ! -d "$dir" ]; then
		fail "$path" 'checkout path is not a directory'
	fi

	# Keep shellcheck and readers aware that validation intentionally resolves
	# the gitlink in this pass; the action pass resolves it again after init.
	: "$expected"
done

# Pass two performs the requested initialization/checkout one declaration at
# a time.  git-submodule first uses an existing local object database and only
# invokes its configured transport when required objects are unavailable.
for path in "$@"
do
	expected=$(gitlink "$path") || fail "$path" 'gitlink changed during preparation'
	printf '  SUBMOD  %s (%s)\n' "$path" "$expected"
	# Intentional word splitting: these variables are command argument lists.
	# shellcheck disable=SC2086
	env $SCM_FETCH_ENV $SCM_TIMEOUT_CMD "$GIT" -C "$WRKSRC" \
		submodule update $SUBMODULE_UPDATE_ARGS -- "$path" ||
		fail "$path" 'update failed'

	actual=$("$GIT" -C "$WRKSRC/$path" rev-parse HEAD 2>/dev/null || :)
	[ "$actual" = "$expected" ] ||
		fail "$path" "expected $expected, found ${actual:-none}"
	if [ -n "$("$GIT" -C "$WRKSRC/$path" status --porcelain \
	    --untracked-files=normal 2>/dev/null || :)" ]; then
		fail "$path" 'checkout became dirty during preparation'
	fi
done
