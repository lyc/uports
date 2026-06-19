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
assert_contains "normalized planning records are immediate" "$snapshot" \
	"flavor.ports_all_raw=simple
flavor.categories_all=simple
flavor.ports_all_group=simple
flavor.groups_all=simple
flavor.ports_all_group_extra=simple"
assert_contains "built-in port origin" "$snapshot" \
	"origin.pkg-config=$portdir"
assert_contains "feed override origin" "$snapshot" \
	"origin.openssl=$feeds"
assert_contains "normalized logical port origin" "$snapshot" \
	"record.openssl.origin=security/openssl
record.openssl.root=$feeds"
assert_contains "unselected logical port lookup" "$snapshot" \
	"record.cpython.root=$feeds"
assert_contains "normalized instance origin" "$snapshot" \
	"instance.target_libffi.origin=devel/libffi
instance.target_libffi.root=$feeds"
assert_contains "normalized instance environment" "$snapshot" \
	"instance.target_libffi.env="
assert_contains "shell-free path merge" "$snapshot" \
	"merge.paths=/prefix/lib/pkgconfig:/prefix/lib64/pkgconfig"
assert_contains "presentation probes are deferred" "$snapshot" \
	"flavor.info_ports_opsys=recursive
flavor.info_ports_arch=recursive
flavor.info_ports_cols=recursive"
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

debug_categories=$(run_make info.debug.category-all)
assert_contains "aggregate category diagnostics" "$debug_categories" \
	"categories_devel = pkg-config libffi"
show_category=$(run_make show-categories-devel)
assert_contains "direct category diagnostic alias" "$show_category" \
	"categories_devel = pkg-config libffi"

debug_port_groups=$(run_make info.debug.port-groups)
assert_contains "aggregate port-group diagnostics" "$debug_port_groups" \
	"openssl_groups = host target"
show_port_groups=$(run_make show-openssl-groups)
assert_contains "direct port-group diagnostic alias" "$show_port_groups" \
	"openssl_groups = host target"

show_group=$(run_make show-groups-target)
assert_contains "direct group diagnostic alias" "$show_group" \
	"groups_target = expat2 openssl libffi"
show_suffix=$(run_make show-groups-suffix-target)
assert_contains "direct group-suffix diagnostic alias" "$show_suffix" \
	"target_SUFFIX = -pj.target"

benchmark=$("$testdir/../benchmark-tools.sh" -C "$testdir" -n 1 \
	-l regression)
assert_contains "benchmark output format" "$benchmark" \
	"benchmark_format=1"
assert_contains "benchmark label" "$benchmark" \
	"label=regression"
assert_contains "benchmark run count" "$benchmark" \
	"runs=1"
assert_contains "benchmark includes planner statistics" "$benchmark" \
	"selected_ports=5
groups=3"
assert_contains "benchmark includes timing" "$benchmark" \
	"median_real_seconds="
assert_contains "benchmark includes make database counts" "$benchmark" \
	"make_database_bytes="
assert_contains "benchmark reports optional memory state" "$benchmark" \
	"memory_max_rss_kb=unavailable"

baseline_dir=$testdir/../baselines/2026-06-19-darwin-arm64
for baseline in full cpython host-group multi-group; do
	baseline_data=$(cat "$baseline_dir/$baseline.baseline")
	assert_contains "baseline format: $baseline" "$baseline_data" \
		"benchmark_format=1"
	assert_contains "baseline label: $baseline" "$baseline_data" \
		"label=$baseline"
done
synthetic_baseline=$(cat "$baseline_dir/synthetic-200.baseline")
assert_contains "baseline format: synthetic-200" "$synthetic_baseline" \
	"benchmark_format=1"
assert_contains "baseline label: synthetic-200" "$synthetic_baseline" \
	"label=synthetic-200"

synthetic_dir=${TMPDIR:-/tmp}/uports-tools-synthetic.$$
trap 'rm -rf "$synthetic_dir"' EXIT HUP INT TERM
"$testdir/../generate-synthetic-plan.sh" "$synthetic_dir" 20
synthetic_stats=$(make --no-print-directory -s -C "$synthetic_dir" \
	USE_HOSTTOOLS= planner-stats)
assert_contains "synthetic discovered and selected ports" "$synthetic_stats" \
	"discovered_definitions=31
resolved_logical_ports=31
selected_ports=20"
assert_contains "synthetic groups categories and instances" "$synthetic_stats" \
	"groups=4
categories=4
build_instances=22"
assert_contains "synthetic generated target counts" "$synthetic_stats" \
	"canonical_targets=374
alias_targets=340
aggregate_targets=154"
rm -rf "$synthetic_dir"
trap - EXIT HUP INT TERM

dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	target@libffi.build)
assert_contains "canonical dispatch directory" "$dispatch" \
	"dir=$feeds"
assert_contains "canonical dispatch identity" "$dispatch" \
	"category=devel; port=libffi; suffix=build"
assert_contains "canonical dispatch environment" "$dispatch" \
	"WITH_TESTS=yes TYPE_SUFFIX=-pj.target"

special_dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	target@libffi.makesum)
special_dispatch=$(printf '%s\n' "$special_dispatch" | tr '\\\n\t' '   ' | \
	awk '{$1=$1; print}')
assert_contains "special dispatch directory and identity" "$special_dispatch" \
	"dir=$feeds; category=devel; port=libffi; suffix=makesum"
assert_contains "special dispatch inner make mode" "$special_dispatch" \
	"_INNERMKINCLUDE=no --no-print-directory"

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
