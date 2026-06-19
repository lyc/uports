#!/bin/sh

set -eu

testdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
topdir=$(CDPATH= cd -- "$testdir/../../../.." && pwd)
portdir=$topdir/make/uports
feeds=$topdir/feeds
failures=0
tests=0

pass()
{
	tests=$((tests + 1))
	printf 'ok %d - %s\n' "$tests" "$1"
}

fail()
{
	tests=$((tests + 1))
	failures=$((failures + 1))
	printf 'not ok %d - %s\n' "$tests" "$1"
	printf '  %s\n' "$2"
}

assert_contains()
{
	name=$1
	haystack=$2
	needle=$3

	case "$haystack" in
		*"$needle"*) pass "$name" ;;
		*) fail "$name" "missing: $needle" ;;
	esac
}

assert_not_contains()
{
	name=$1
	haystack=$2
	needle=$3

	case "$haystack" in
		*"$needle"*) fail "$name" "unexpected: $needle" ;;
		*) pass "$name" ;;
	esac
}

run_make()
{
	make --no-print-directory -s -C "$testdir" USE_HOSTTOOLS= "$@"
}

snapshot=$(run_make regression.snapshot)

assert_contains "selected logical ports" "$snapshot" \
	"ports_all_raw=devel/pkg-config textproc/expat2 math/gmp security/openssl devel/libffi"
assert_contains "short port names" "$snapshot" \
	"ports_all=pkg-config expat2 gmp openssl libffi"
assert_contains "group set" "$snapshot" \
	"groups_all=host target toolchain"
assert_contains "multiple group membership" "$snapshot" \
	"host@security/openssl target@security/openssl"
assert_contains "default-group assignment" "$snapshot" \
	"target@textproc/expat2"
assert_contains "built-in port origin" "$snapshot" \
	"origin.pkg-config=$portdir"
assert_contains "feed override origin" "$snapshot" \
	"origin.openssl=$feeds"
assert_contains "group suffix composition" "$snapshot" \
	"target_SUFFIX=-pj.target"
assert_contains "instance environment overlay" "$snapshot" \
	"WITH_TESTS=yes"
assert_not_contains "instance environment exclusion" \
	"$(printf '%s\n' "$snapshot" | sed -n 's/^env.target.libffi=//p')" \
	"USE_GLOBALBASE=yes"

planner_stats=$(run_make planner-stats)
assert_contains "planner collection count" "$planner_stats" \
	"collections=2"
assert_contains "planner discovered definition count" "$planner_stats" \
	"discovered_definitions=43"
assert_contains "planner resolved logical port count" "$planner_stats" \
	"resolved_logical_ports=42"
assert_contains "planner selected port count" "$planner_stats" \
	"selected_ports=5"
assert_contains "planner group and category counts" "$planner_stats" \
	"groups=3
categories=4"
assert_contains "planner build instance count" "$planner_stats" \
	"build_instances=6"
assert_contains "planner current variant count" "$planner_stats" \
	"selected_variants=0"
assert_contains "planner lifecycle and canonical target counts" "$planner_stats" \
	"lifecycle_suffixes=17
canonical_targets=102"
assert_contains "planner alias target count" "$planner_stats" \
	"alias_targets=85"
assert_contains "planner aggregate target count" "$planner_stats" \
	"aggregate_targets=137"
assert_contains "planner diagnostic target count" "$planner_stats" \
	"diagnostic_targets=8"

dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	target@libffi.build)
assert_contains "canonical dispatch directory" "$dispatch" \
	"dir=$feeds"
assert_contains "canonical dispatch identity" "$dispatch" \
	"category=devel; port=libffi; suffix=build"
assert_contains "canonical dispatch environment" "$dispatch" \
	"WITH_TESTS=yes TYPE_SUFFIX=-pj.target"

alias_dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	openssl.build)
assert_contains "default alias selects default group" "$alias_dispatch" \
	"target@security/openssl build"
assert_not_contains "default alias excludes nondefault group" "$alias_dispatch" \
	"host@security/openssl build"

group_dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	target.build)
assert_contains "group aggregate includes expat2" "$group_dispatch" \
	"target@textproc/expat2 build"
assert_contains "group aggregate includes openssl" "$group_dispatch" \
	"target@security/openssl build"
assert_contains "group aggregate includes libffi" "$group_dispatch" \
	"target@devel/libffi build"

category_dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	devel.build)
assert_contains "category aggregate includes built-in port" "$category_dispatch" \
	"host@devel/pkg-config build"
assert_contains "category aggregate includes feed port" "$category_dispatch" \
	"target@devel/libffi build"

error_file=${TMPDIR:-/tmp}/uports-tools-regression.$$.err
trap 'rm -f "$error_file"' EXIT HUP INT TERM
if run_make PORTS_LISTS=devel/does-not-exist info.debug >"$error_file" 2>&1; then
	fail "unknown selected port fails early" "make unexpectedly succeeded"
else
	error_output=$(cat "$error_file")
	assert_contains "unknown selected port fails early" "$error_output" \
		"assign unknown packages: devel/does-not-exist"
fi

rm -f "$error_file"
trap - EXIT HUP INT TERM

if [ "$failures" -ne 0 ]; then
	printf '1..%d\n' "$tests"
	printf '# %d test(s) failed\n' "$failures"
	exit 1
fi

printf '1..%d\n' "$tests"
