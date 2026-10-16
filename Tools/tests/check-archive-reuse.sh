#!/bin/sh
set -eu
testdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
portdir=$(CDPATH= cd -- "$testdir/../.." && pwd)
task_root=$(mktemp -d "${TMPDIR:-/tmp}/uports-archive-reuse.XXXXXX")
trap 'rm -rf "$task_root"' EXIT HUP INT TERM
mkdir -p "$task_root/feeds/devel" "$task_root/packages"
cp -R "$testdir/cases/archive-consumer" "$testdir/cases/archive-provider" "$task_root/feeds/devel/"
cp "$testdir/archive-reuse.mk" "$task_root/Makefile"
run_make() {
    make --no-print-directory -s -C "$task_root" portdir="$portdir" TEST_ROOT="$task_root" "$@" target@archive-consumer.install
}
archive="$task_root/packages/All-linux-x86_64/archive-consumer-1.pkg"
binary="$task_root/installed/target/usr/local/bin/consumer"
run_make
test "$("$binary")" = without-library
test "$(grep -c '^build$' "$task_root/events")" = 1
cp "$archive" "$task_root/old.pkg"
cp "$task_root/feeds/devel/archive-consumer/work/dependency.stage.state" "$task_root/old.state"
if run_make NEEDS_LIBRARY=yes FAIL_BUILD=yes > "$task_root/failed-build.log" 2>&1; then
    echo 'expected the deliberately failed build to propagate' >&2
    exit 1
fi
cmp -s "$task_root/old.state" "$task_root/feeds/devel/archive-consumer/work/dependency.stage.state"
cmp -s "$task_root/old.pkg" "$archive"
# Remove only the deliberately failed attempt from the successful-build count.
failed_builds=1
run_make NEEDS_LIBRARY=yes
test "$("$binary")" = 42
test "$(grep -c '^build$' "$task_root/events")" = $((2 + failed_builds))
awk 'NR > 9 { if ($0 == "%%%%%-PROVENANCE") exit; print }' "$archive" > "$task_root/current.report"
/bin/sh "$portdir/Mk/Scripts/package-provenance-check.sh" "$archive" "$task_root/current.report" /usr/local
if /bin/sh "$portdir/Mk/Scripts/package-provenance-check.sh" "$task_root/old.pkg" "$task_root/current.report" /usr/local; then
    echo 'archive checker accepted missing library provenance' >&2
    exit 1
fi
if /bin/sh "$portdir/Mk/Scripts/package-provenance-check.sh" "$archive" "$task_root/current.report" /usr; then
    echo 'archive checker accepted a different installation prefix' >&2
    exit 1
fi
env STAGEDIR="$task_root/feeds/devel/archive-consumer/work/stage" \
    PKGNAME=archive-consumer VERSION=1 ORIGIN=devel/archive-consumer \
    PREFIX=/usr/local INDEX=devel COMPRESS=XZ EXT=linux \
    PLIST="$task_root/feeds/devel/archive-consumer/pkg-plist" \
    WRKDIR_PKGFILE="$task_root/legacy.pkg" PROVENANCE= \
    /bin/sh "$portdir/Mk/Scripts/pkg.sh" create
if /bin/sh "$portdir/Mk/Scripts/package-provenance-check.sh" "$task_root/legacy.pkg" "$task_root/current.report" /usr/local; then
    echo 'archive checker accepted legacy packaging without provenance' >&2
    exit 1
fi
run_make NEEDS_LIBRARY=yes
test "$(grep -c '^build$' "$task_root/events")" = $((2 + failed_builds))
# A runtime-only dependency changes packaging, not configure/build inputs.
run_make NEEDS_LIBRARY=yes RUNTIME_PROVIDER=yes
test "$(grep -c '^build$' "$task_root/events")" = $((2 + failed_builds))
# With local state removed, archive provenance must still reject the old build.
rm -rf "$task_root/feeds/devel/archive-consumer/work"
cp "$task_root/old.pkg" "$archive"
run_make NEEDS_LIBRARY=yes
test "$("$binary")" = 42
test "$(grep -c '^build$' "$task_root/events")" = $((3 + failed_builds))
rm -rf "$task_root/feeds/devel/archive-consumer/work"
for repeat in 1 2; do
    make --no-print-directory -s -C "$task_root" portdir="$portdir" \
        TEST_ROOT="$task_root" NEEDS_LIBRARY=yes target@archive-consumer.stage
    test "$(grep -c '^build$' "$task_root/events")" = $((4 + failed_builds))
done
run_make NEEDS_LIBRARY=yes
test "$(grep -c '^build$' "$task_root/events")" = $((4 + failed_builds))
test "$("$binary")" = 42
echo 'archive dependency transition, runtime-only change, and repeat reuse passed'
