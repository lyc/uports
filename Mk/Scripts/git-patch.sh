#!/bin/sh

set -eu

fail()
{
	printf '  ERR     %s\n' "$*" >&2
	exit 1
}

[ -n "${PATCH_WRKSRC:-}" ] || fail 'missing PATCH_WRKSRC'
[ -n "${PATCHLIST:-}" ] || fail 'missing PATCHLIST'
[ -n "${PATCHDIR:-}" ] || fail 'missing PATCHDIR'
GIT=${GIT:-git}

[ -f "$PATCHLIST" ] || exit 0
cd "$PATCH_WRKSRC"

if "$GIT" rev-parse --verify REBASE_HEAD >/dev/null 2>&1 ||
    test -d "$($GIT rev-parse --git-path rebase-apply)"; then
	"$GIT" am --abort >/dev/null 2>&1 || fail 'cannot abort incomplete git am'
fi

[ -z "$("$GIT" status --porcelain --untracked-files=normal)" ] ||
	fail 'source checkout is dirty before patching'

tmp=${TMPDIR:-/tmp}/uports-git-patch.$$
trap 'rm -f "$tmp.expected" "$tmp.expected-subjects" "$tmp.actual-subjects"' \
	EXIT HUP INT TERM
: >"$tmp.expected"
: >"$tmp.expected-subjects"

while IFS= read -r patch
do
	case "$patch" in
		''|'#'*) continue ;;
		/*|.|..|../*|*/../*|*/..|*\\*) fail "invalid patch entry $patch" ;;
	esac
	[ -f "$PATCHDIR/$patch" ] || fail "missing patch $patch"
	patch_id=$("$GIT" patch-id --stable <"$PATCHDIR/$patch" | awk 'NR == 1 { print $1 }')
	[ -n "$patch_id" ] || fail "cannot identify patch $patch"
	printf '%s %s\n' "$patch_id" "$patch" >>"$tmp.expected"
	subject=$(sed -n 's/^Subject: \(\[PATCH[^]]*\] \)\{0,1\}//p' \
		"$PATCHDIR/$patch" | head -1)
	[ -n "$subject" ] || fail "cannot identify patch subject $patch"
	printf '%s\n' "$subject" >>"$tmp.expected-subjects"
done <"$PATCHLIST"

count=$(wc -l <"$tmp.expected" | tr -d ' ')
[ "$count" -gt 0 ] || exit 0
: >"$tmp.actual-subjects"
"$GIT" log --format=%s --reverse --max-count="$count" HEAD \
	>"$tmp.actual-subjects"

applied=$(awk '
	NR == FNR { expected[++n] = $0; next }
	{ actual[++m] = $0 }
	END {
		for (k = (n < m ? n : m); k > 0; --k) {
			start = m - k
			ok = 1
			for (i = 1; i <= k; ++i)
				if (expected[i] != actual[start + i]) ok = 0
			if (ok) { print k; exit }
		}
		print 0
	}' "$tmp.expected-subjects" "$tmp.actual-subjects")

[ "$applied" -lt "$count" ] || {
	printf '  GIT     patch series already applied\n'
	exit 0
}

base=$("$GIT" rev-parse HEAD)
index=0
while read -r patch_id patch
do
	index=$((index + 1))
	[ "$index" -gt "$applied" ] || continue
	printf '  GIT     %s (am)\n' "$patch"
	# Intentional word splitting: GIT_AM_OPTS is an argument list.
	# shellcheck disable=SC2086
	if ! "$GIT" am ${GIT_AM_OPTS:-} "$PATCHDIR/$patch"; then
		"$GIT" am --abort >/dev/null 2>&1 || :
		"$GIT" reset --hard "$base" >/dev/null
		fail "patch $patch failed; series rolled back"
	fi
done <"$tmp.expected"
