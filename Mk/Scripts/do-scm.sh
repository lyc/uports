#!/bin/sh
# Git cache and developer checkout lifecycle. Existing trees are never reset.
set -eu

fail() { printf '  ERR     SCM: %s\n' "$*" >&2; exit 1; }
note() { printf '  GIT     %s\n' "$*"; }
command_failed()
{
	code=$1
	operation=$2
	case "$code" in
		124|137)
			printf '  ERR     SCM: %s timed out after %s (exit %s)\n' \
				"$operation" "$timeout" "$code" >&2
			;;
		*) printf '  ERR     SCM: %s failed (exit %s)\n' \
			"$operation" "$code" >&2 ;;
	esac
	exit "$code"
}
git=${GIT_CMD:-git}
action=${1:-}
cache=${SCM_CACHE_REPO:-}
repo=${SCM_REPO_URL:-}
tree=${SCM_WORKTREE:-}
alias=${SCM_WORKLINK:-$tree}
branch=${SCM_BRANCH:-}
detach=${SCM_DETACH:-}
timeout=${SCM_TIMEOUT:-15m}
timer=${SCM_TIMEOUT_BIN:-}
lock_wait=${SCM_LOCK_TIMEOUT:-30}
scratch=
cache_lock=
tree_lock=

cleanup()
{
	status=$?
	trap - EXIT HUP INT TERM
	if [ -n "$scratch" ]; then rm -rf -- "$scratch"; fi
	for lock in "$tree_lock" "$cache_lock"; do
		[ -n "$lock" ] || continue
		rm -f -- "$lock/owner"
		rmdir -- "$lock" || :
	done
	exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

case "$action" in fetch|checkout|update|package-check) ;;
	*) fail "unknown operation: $action" ;;
esac
[ -n "$repo" ] || fail 'SCM_REPO_URL is empty'
[ -z "$branch" ] || [ -z "$detach" ] ||
	fail 'select only SCM_BRANCH or SCM_DETACH'
case "$branch$detach" in -*) fail 'ref must not start with a dash' ;; esac
case "$lock_wait" in ''|*[!0-9]*) fail 'SCM_LOCK_TIMEOUT must be seconds' ;; esac
case "$timeout" in
	0|no) timer= ;;
	*)
		printf '%s\n' "$timeout" | grep -Eq '^[0-9]+([.][0-9]+)?[smhd]?$' ||
			fail 'SCM_TIMEOUT must be a positive duration, 0 or no'
		numeric=${timeout%[smhd]}
		awk -v seconds="$numeric" 'BEGIN { exit !(seconds > 0) }' ||
			fail 'use 0 to disable timeout'
		[ -n "$timer" ] || timer=$(command -v timeout || command -v gtimeout || :)
		[ -n "$timer" ] && command -v "$timer" >/dev/null 2>&1 ||
			fail 'finite SCM_TIMEOUT requires timeout/gtimeout; use 0 to opt out'
		;;
esac

limited()
{
	# SCM_FETCH_ENV is a plain whitespace-delimited list, not shell code.
	if [ -n "$timer" ]; then
		env ${SCM_FETCH_ENV:-GIT_TERMINAL_PROMPT=0} "$timer" \
			--kill-after=5 "$timeout" "$@"
	else
		env ${SCM_FETCH_ENV:-GIT_TERMINAL_PROMPT=0} "$@"
	fi
}

lock()
{
	path=$1
	mkdir -p -- "${path%/*}"
	waited=0
	until mkdir -- "$path" 2>/dev/null; do
		[ "$waited" -lt "$lock_wait" ] ||
			fail "lock busy: $path; inspect owner before manual recovery"
		sleep 1
		waited=$((waited + 1))
	done
	if [ "$path" = "$cache.lock" ]; then cache_lock=$path
	else tree_lock=$path
	fi
	printf '%s\n' "$$" > "$path/owner"
}

resolve()
{
	location=$1
	ref=$detach
	[ -z "$branch" ] || ref=refs/heads/$branch
	ref=${ref:-HEAD}
	"$git" -C "$location" rev-parse --verify "$ref^{commit}" ||
		fail "requested commit/ref is unavailable: $ref ($location)"
}

verify_cache()
{
	[ "$("$git" -C "$cache" rev-parse --is-bare-repository)" = true ] ||
		fail "not a bare Git cache: $cache"
	[ "$("$git" -C "$cache" remote get-url origin)" = "$repo" ] ||
		fail "cache origin differs from SCM_REPO_URL: $cache"
}

fetch_cache()
{
	[ "${SCM_CACHE:-yes}" != no ] || return 0
	[ -n "$cache" ] || fail 'SCM_CACHE_REPO is empty'
	lock "$cache.lock"
	if [ -e "$cache" ] || [ -L "$cache" ]; then
		verify_cache
		if [ "${SCM_CACHE_UPDATE:-yes}" = yes ]; then
			note "refresh mirror: $cache"
			if limited "$git" -C "$cache" fetch --progress --prune origin; then :
			else
				code=$?
				if [ "${SCM_CACHE_UPDATE_REQUIRED:-no}" = yes ]; then
					command_failed "$code" 'required mirror refresh'
				fi
				note "optional refresh failed (exit $code); verifying cached requested ref"
			fi
		fi
	else
		scratch=$(mktemp -d "$cache.tmp.XXXXXX")
		note "create mirror: $cache (total deadline: $timeout)"
		# SCM_CMD is the legacy clone command; arguments remain word lists.
		if limited ${SCM_CMD:-$git clone} --progress --mirror "$repo" "$scratch"; then :
		else command_failed "$?" 'mirror clone'
		fi
		resolve "$scratch" >/dev/null
		mv -- "$scratch" "$cache"
		scratch=
	fi
	resolve "$cache" >/dev/null
}

verify_tree()
{
	[ -d "$tree" ] || fail "checkout does not exist: $tree"
	physical=$(CDPATH= cd -- "$tree" && pwd -P)
	top=$("$git" -C "$tree" rev-parse --show-toplevel) ||
		fail "not a Git checkout: $tree"
	[ "$physical" = "$(CDPATH= cd -- "$top" && pwd -P)" ] ||
		fail 'checkout path is inside another repository'
	origin=$("$git" -C "$tree" remote get-url origin) || fail 'checkout has no origin'
	[ "$origin" = "$repo" ] || [ "$origin" = "$cache" ] ||
		fail 'existing checkout origin differs; refusing to replace it'
	gitdir=$("$git" -C "$tree" rev-parse --absolute-git-dir)
}

verify_request()
{
	marker=$gitdir/uports-source-request
	if [ -e "$marker" ]; then
		printf '%s\n' "$repo" "$branch" "$detach" | cmp -s - "$marker" ||
			fail 'checkout belongs to another source request; use a separate root'
	else
		if [ -n "$detach" ]; then
			base=$("$git" -C "$tree" rev-parse --verify "$detach^{commit}") ||
				fail 'existing checkout does not contain requested revision'
			"$git" -C "$tree" merge-base --is-ancestor "$base" HEAD ||
				fail 'existing checkout history differs from requested revision'
		fi
		scratch=$(mktemp "$gitdir/uports-source-request.tmp.XXXXXX")
		printf '%s\n' "$repo" "$branch" "$detach" > "$scratch"
		mv -- "$scratch" "$marker"
		scratch=
	fi
}

check_operation()
{
	for name in rebase-apply rebase-merge MERGE_HEAD CHERRY_PICK_HEAD \
		REVERT_HEAD sequencer BISECT_LOG; do
		[ ! -e "$gitdir/$name" ] ||
			fail "Git operation is in progress ($name); resolve it manually"
	done
	"$git" -C "$tree" submodule foreach --quiet --recursive '
		dir=$(git rev-parse --absolute-git-dir) || exit 1
		for name in rebase-apply rebase-merge MERGE_HEAD CHERRY_PICK_HEAD \
		    REVERT_HEAD sequencer; do
			test ! -e "$dir/$name" || exit 1
		done
	' || fail 'submodule has an unfinished Git operation'
}

check_clean()
{
	check_operation
	status=$("$git" -C "$tree" status --porcelain --untracked-files=all) ||
		fail 'cannot inspect checkout status'
	[ -z "$status" ] ||
		fail 'checkout/submodules are dirty; resolve tracked and untracked changes'
	# Uninitialized or locally advanced submodules must not be moved implicitly.
	if "$git" -C "$tree" submodule status --recursive | grep -Eq '^[-+U]'; then
		fail 'submodule checkout differs from its recorded gitlink'
	fi
}

check_alias()
{
	[ "$alias" != "$tree" ] || return 0
	if [ -L "$alias" ]; then
		[ "$(readlink "$alias")" = "$tree" ] ||
			fail "unexpected alternative-source link: $alias"
	elif [ -e "$alias" ]; then
		fail "alternative-source alias is occupied: $alias"
	fi
}

case "$action" in
	fetch) fetch_cache ;;
	checkout)
		[ -n "$tree" ] || fail 'SCM_WORKTREE is empty'
		lock "$tree.uports-lock"
		check_alias
		if [ -e "$tree" ] || [ -L "$tree" ]; then
			verify_tree
			check_operation
			verify_request
			note "preserve existing checkout: $tree"
		else
			upstream=$repo
			if [ "${SCM_CACHE:-yes}" != no ]; then
				lock "$cache.lock"
				verify_cache
				resolve "$cache" >/dev/null
				upstream=$cache
			fi
			mkdir -p -- "${tree%/*}"
			scratch=$(mktemp -d "$tree.tmp.XXXXXX")
			note "create checkout: $tree"
			if [ -n "$branch" ]; then
				limited ${SCM_CMD:-$git clone} ${SCM_CMD_OPTS:-} \
					--progress --branch "$branch" "$upstream" "$scratch"
			else
				limited ${SCM_CMD:-$git clone} ${SCM_CMD_OPTS:-} \
					--progress "$upstream" "$scratch"
			fi
			resolve "$scratch" >/dev/null
			if [ -n "$detach" ]; then
				target=$(resolve "$scratch")
				"$git" -C "$scratch" checkout --detach "$target"
			fi
			"$git" -C "$scratch" remote set-url origin "$repo"
			mv -- "$scratch" "$tree"
			scratch=
			verify_tree
			verify_request
		fi
		if [ "$alias" != "$tree" ] && [ ! -L "$alias" ]; then
			mkdir -p -- "${alias%/*}"
			ln -s -- "$tree" "$alias"
		fi
		;;
	update)
		lock "$tree.uports-lock"
		check_alias
		verify_tree
		verify_request
		check_clean
		current_branch=$("$git" -C "$tree" symbolic-ref --quiet --short HEAD || :)
		if [ -n "$branch" ]; then
			[ "$current_branch" = "$branch" ] ||
				fail 'current branch differs from SCM_BRANCH; preserved unchanged'
		else
			[ -z "$current_branch" ] ||
				fail 'detached update requested on a developer branch; preserved unchanged'
		fi
		fetch_cache
		upstream=$repo
		ref=${detach:-HEAD}
		[ -z "$branch" ] || ref=refs/heads/$branch
		[ "${SCM_CACHE:-yes}" = no ] || upstream=$cache
		limited "$git" -C "$tree" fetch --progress --no-tags "$upstream" "$ref"
		old=$("$git" -C "$tree" rev-parse HEAD)
		new=$("$git" -C "$tree" rev-parse FETCH_HEAD)
		"$git" -C "$tree" merge-base --is-ancestor "$old" "$new" ||
			fail 'update is not a fast-forward; local commits are preserved'
		[ -z "$("$git" -C "$tree" diff --name-only "$old" "$new" -- .gitmodules)" ] ||
			fail 'update changes .gitmodules; manage submodules manually'
		if "$git" -C "$tree" diff --raw "$old" "$new" |
		    grep -Eq '^:160000 |^:[0-9]+ 160000 '; then
			fail 'update changes gitlinks; manage submodules manually'
		fi
		if [ -n "$branch" ]; then
			"$git" -C "$tree" merge --ff-only "$new"
		else
			"$git" -C "$tree" checkout --detach "$new"
		fi
		note "updated checkout: $new"
		;;
	package-check)
		verify_tree
		check_operation
		case "${SCM_DIRTY_PACKAGE:-record}" in
			reject) check_clean ;;
			record)
				status=$("$git" -C "$tree" status --porcelain \
				    --untracked-files=all) || fail 'cannot inspect checkout status'
				if [ -n "$status" ]; then
					note 'dirty worktree; explicit source mode records package source status'
				fi
				;;
			*) fail 'SCM_DIRTY_PACKAGE must be record or reject' ;;
		esac
		;;
esac
