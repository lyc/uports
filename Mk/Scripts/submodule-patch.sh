#!/bin/sh

# Validate and apply platform-selected git-format patch series to explicitly
# declared submodules.  Series metadata is validated before the first patch is
# applied; a failed series is rolled back to that submodule's starting commit.

set -eu

: "${WRKSRC:?WRKSRC is required}"
: "${SUBMODULE_PATCHDIR:?SUBMODULE_PATCHDIR is required}"

SCM_SUBMODULES=${SCM_SUBMODULES-}
SUBMODULE_PATCH_METHOD=${SUBMODULE_PATCH_METHOD-V2}
SUBMODULE_GIT_AM_OPTS=${SUBMODULE_GIT_AM_OPTS-}
OPSYS=${OPSYS-}
OPSYS_SUFX=${OPSYS_SUFX-}
ARCH=${ARCH-}
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

select_series()
{
	dir=$1

	if [ -n "$OPSYS_SUFX" ]; then
		for name in \
			"series.$OPSYS-$OPSYS_SUFX-$ARCH" \
			"series.$OPSYS-$OPSYS_SUFX"
		do
			if [ -f "$dir/$name" ]; then
				printf '%s\n' "$dir/$name"
				return
			fi
		done
	fi

	for name in "series.$OPSYS-$ARCH" "series.$OPSYS" series
	do
		if [ -f "$dir/$name" ]; then
			printf '%s\n' "$dir/$name"
			return
		fi
	done
}

series_entries()
{
	awk '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*$/ { next }
		{
			gsub(/^[[:space:]]+|[[:space:]]+$/, "")
			print
		}
	' "$1"
}

set -- $SCM_SUBMODULES
[ "$#" -gt 0 ] || exit 0

"$GIT" -C "$WRKSRC" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
	fail parent 'WRKSRC is not a Git work tree'
root_physical=$(CDPATH= cd -- "$WRKSRC" 2>/dev/null && pwd -P) ||
	fail parent 'cannot resolve WRKSRC'

# Validate every selected series and patch path before changing a submodule.
seen=
for path in "$@"
do
	valid_path "$path" || fail "$path" 'invalid path'
	case " $seen " in
		*" $path "*) fail "$path" 'duplicate declaration' ;;
	esac
	seen="$seen $path"
	expected=$(gitlink "$path") || fail "$path" 'missing gitlink at parent HEAD'
	dir_physical=$(CDPATH= cd -- "$WRKSRC/$path" 2>/dev/null && pwd -P) ||
		fail "$path" 'submodule is not initialized'
	case "$dir_physical" in
		"$root_physical"/*) ;;
		*) fail "$path" 'checkout resolves outside WRKSRC' ;;
	esac
	actual=$("$GIT" -C "$WRKSRC/$path" rev-parse HEAD 2>/dev/null || :)
	[ "$actual" = "$expected" ] ||
		fail "$path" "checkout is not at parent gitlink $expected"

	series=$(select_series "$SUBMODULE_PATCHDIR/$path" || :)
	[ -n "$series" ] || continue
	[ "$SUBMODULE_PATCH_METHOD" = V2 ] ||
		fail "$path" "unsupported patch method $SUBMODULE_PATCH_METHOD"
	if [ -n "$("$GIT" -C "$WRKSRC/$path" status --porcelain \
	    --untracked-files=normal 2>/dev/null || :)" ]; then
		fail "$path" 'checkout is dirty before patching'
	fi
	series_entries "$series" | while IFS= read -r patch
	do
		case "$patch" in
			""|/*|.|..|../*|*/../*|*/..|*/*|*\\*)
				fail "$path" "invalid patch entry $patch"
				;;
		esac
		[ -f "$SUBMODULE_PATCHDIR/$path/$patch" ] ||
			fail "$path" "missing patch $patch"
	done
done

for path in "$@"
do
	series=$(select_series "$SUBMODULE_PATCHDIR/$path" || :)
	[ -n "$series" ] || continue
	base=$("$GIT" -C "$WRKSRC/$path" rev-parse HEAD) ||
		fail "$path" 'cannot resolve starting commit'
	printf '  SUBPAT  %s (%s)\n' "$path" "${series##*/}"
	series_entries "$series" | while IFS= read -r patch
	do
		printf '  GIT     %s/%s (am)\n' "$path" "$patch"
		# Intentional word splitting: SUBMODULE_GIT_AM_OPTS is an argument list.
		# shellcheck disable=SC2086
		if ! "$GIT" -C "$WRKSRC/$path" am $SUBMODULE_GIT_AM_OPTS \
		    "$SUBMODULE_PATCHDIR/$path/$patch"; then
			"$GIT" -C "$WRKSRC/$path" am --abort >/dev/null 2>&1 || :
			"$GIT" -C "$WRKSRC/$path" reset --hard "$base" >/dev/null
			fail "$path" "patch $patch failed; series rolled back"
		fi
	done
done
