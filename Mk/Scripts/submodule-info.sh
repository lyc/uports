#!/bin/sh

# Print normalized, read-only diagnostics for explicitly declared SCM
# submodules.  This helper must not initialize, update, reset, or patch a
# repository.

set -eu

: "${WRKSRC:?WRKSRC is required}"
: "${SUBMODULE_PATCHDIR:?SUBMODULE_PATCHDIR is required}"

SCM_SUBMODULES=${SCM_SUBMODULES-}
SUBMODULE_PATCH_METHOD=${SUBMODULE_PATCH_METHOD-V2}
OPSYS=${OPSYS-}
OPSYS_SUFX=${OPSYS_SUFX-}
ARCH=${ARCH-}
GIT=${GIT-git}

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

series_count()
{
	awk '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*$/ { next }
		{ count++ }
		END { print count + 0 }
	' "$1"
}

root_is_git=no
if "$GIT" -C "$WRKSRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	root_is_git=yes
fi

root_physical=
if [ -d "$WRKSRC" ]; then
	root_physical=$(CDPATH= cd -- "$WRKSRC" 2>/dev/null && pwd -P) || :
fi

set -- $SCM_SUBMODULES
printf 'submodules.declared = %s\n' "$SCM_SUBMODULES"
printf 'submodules.count = %s\n' "$#"
printf 'submodules.patchdir = %s\n' "$SUBMODULE_PATCHDIR"
printf 'submodules.patch_method = %s\n' "$SUBMODULE_PATCH_METHOD"

index=0
seen=
for path in "$@"
do
	index=$((index + 1))
	state=ready
	expected=none
	checkout=none
	initialized=no
	dirty=unknown
	patch_series=none
	patch_count=0

	case " $seen " in
		*" $path "*) state=duplicate ;;
		*) seen="$seen $path" ;;
	esac

	if [ "$state" != duplicate ]; then
		case "$path" in
			""|/*|.|..|../*|*/../*|*/..|./*|*/./*|*//*|*/|*\\*)
				state=invalid-path
				;;
		esac
	fi

	dir=$WRKSRC/$path
	if [ "$state" = ready ] && [ -e "$dir" ]; then
		dir_physical=$(CDPATH= cd -- "$dir" 2>/dev/null && pwd -P) || \
			dir_physical=
		case "$dir_physical" in
			"$root_physical"/*) ;;
			*) state=invalid-path ;;
		esac
	fi

	if [ "$state" = ready ]; then
		if [ "$root_is_git" != yes ]; then
			state=parent-not-git
		else
			tree_line=$("$GIT" -C "$WRKSRC" ls-tree HEAD -- "$path" \
				2>/dev/null || :)
			tree_mode=$(printf '%s\n' "$tree_line" | awk 'NR == 1 { print $1 }')
			tree_type=$(printf '%s\n' "$tree_line" | awk 'NR == 1 { print $2 }')
			tree_hash=$(printf '%s\n' "$tree_line" | awk 'NR == 1 { print $3 }')
			if [ "$tree_mode" != 160000 ] || [ "$tree_type" != commit ] || \
			   [ -z "$tree_hash" ]; then
				state=missing-gitlink
			else
				expected=$tree_hash
			fi
		fi
	fi

	if [ "$state" = ready ]; then
		if [ ! -e "$dir/.git" ]; then
			state=uninitialized
		else
			checkout=$("$GIT" -C "$dir" rev-parse HEAD 2>/dev/null || :)
			if [ -z "$checkout" ]; then
				checkout=none
				state=uninitialized
			else
				initialized=yes
				if [ -n "$("$GIT" -C "$dir" status --porcelain \
					--untracked-files=normal 2>/dev/null || :)" ]; then
					dirty=yes
				else
					dirty=no
				fi
				if [ "$checkout" != "$expected" ]; then
					state=commit-mismatch
				elif [ "$dirty" = yes ]; then
					state=dirty
				fi
			fi
		fi
	fi

	series=$(select_series "$SUBMODULE_PATCHDIR/$path" || :)
	if [ -n "$series" ]; then
		patch_series=${series##*/}
		patch_count=$(series_count "$series")
	fi

	printf 'submodule.%s = path=%s expected=%s checkout=%s initialized=%s dirty=%s patch_method=%s patch_series=%s patch_count=%s state=%s\n' \
		"$index" "$path" "$expected" "$checkout" "$initialized" \
		"$dirty" "$SUBMODULE_PATCH_METHOD" "$patch_series" \
		"$patch_count" "$state"
done
