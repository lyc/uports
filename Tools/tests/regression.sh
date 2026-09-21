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

assert_eq()
{
	name=$1
	actual=$2
	expected=$3

	if [ "$actual" = "$expected" ]; then
		pass "$name"
	else
		fail "$name" "expected: $expected; actual: $actual"
	fi
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
assert_contains "normalized instance default variant" "$snapshot" \
	"instance.target_libffi.variant=default"
assert_contains "default variant preserves instance key" "$snapshot" \
	"instance.key.default=target_libffi
instance.key.explicit-default=target_libffi"
assert_contains "nondefault variant has distinct instance key" "$snapshot" \
	"instance.key.nondefault=target_libffi_shared"
assert_contains "unselected variant has no instance record" "$snapshot" \
	"instance.nondefault.origin="
assert_contains "normalized instance environment" "$snapshot" \
	"instance.target_libffi.env="
assert_contains "status work path has no embedded whitespace" "$snapshot" \
	"work.target_libffi=$feeds/devel/libffi/work-pj.target"
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
assert_contains "compatibility environment record is immediate" "$snapshot" \
	"flavor.env.target.libffi=simple"

planner_stats=$(run_make planner-stats)
assert_contains "planner collection count" "$planner_stats" \
	"collections=2"
assert_contains "planner discovered definition count" "$planner_stats" \
	"discovered_definitions=56"
assert_contains "planner resolved logical port count" "$planner_stats" \
	"resolved_logical_ports=55"
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
	"lifecycle_suffixes=18
canonical_targets=108"
assert_contains "planner alias target count" "$planner_stats" \
	"alias_targets=90"
assert_contains "planner aggregate target count" "$planner_stats" \
	"aggregate_targets=145"
assert_contains "planner diagnostic target count" "$planner_stats" \
	"diagnostic_targets=8"

status_work=$feeds/devel/libffi/work-pj.target
rm -rf "$status_work"
status_empty=$(run_make --eval='.PHONY: status-check
status-check: ; @echo $(call info_ports_status,$(call info_ports_work,target@devel/libffi))' \
	status-check)
if [ -n "$status_empty" ]; then
	fail "empty status has no lifecycle marker" "unexpected: $status_empty"
else
	pass "empty status has no lifecycle marker"
fi
mkdir -p "$status_work"
touch "$status_work/build._done.test.cookie"
status_build=$(run_make --eval='.PHONY: status-check
status-check: ; @echo $(call info_ports_status,$(call info_ports_work,target@devel/libffi))' \
	status-check)
assert_contains "build status cookie is reported" "$status_build" "B"
touch "$status_work/install._done.test.cookie"
status_install=$(run_make --eval='.PHONY: status-check
status-check: ; @echo $(call info_ports_status,$(call info_ports_work,target@devel/libffi))' \
	status-check)
assert_contains "install status overrides build status" "$status_install" "I"
rm -rf "$status_work"

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

debug_plan=$(run_make info.debug.plan)
assert_contains "human-readable planner diagnostics" "$debug_plan" \
	"selected_ports = 5"
assert_contains "human-readable instance and variant counts" "$debug_plan" \
	"build_instances = 6
implicit_default_variants = 6
selected_nondefault_variants = 0"

debug_origins=$(run_make info.debug.origins)
assert_contains "human-readable origin diagnostics" "$debug_origins" \
	"collection.builtin = $portdir
collection.feed = $feeds
feed_overrides = none"
assert_contains "resolved feed origin diagnostic" "$debug_origins" \
	"origin.openssl = $feeds/security/openssl"

debug_instances=$(run_make info.debug.instances)
assert_contains "normalized instance diagnostics" "$debug_instances" \
	"instance.target_libffi = group=target origin=devel/libffi variant=default root=$feeds"
assert_not_contains "default instance diagnostics omit environment detail" \
	"$debug_instances" "WITH_TESTS=yes"

debug_instance_envs=$(run_make info.debug.instance-envs)
assert_contains "focused instance environment diagnostics" \
	"$debug_instance_envs" "instance.target_libffi.env ="
assert_contains "focused instance environment includes overlay" \
	"$debug_instance_envs" "WITH_TESTS=yes"

debug_variants=$(run_make info.debug.variants)
assert_contains "variant diagnostics" "$debug_variants" \
	"default_variant = default
implicit_default_instances = 6
selected_nondefault_variants = 0
unselected_variants_generate_state = no"

debug_dependencies=$(run_make info.debug.dependencies)
assert_contains "normalized dependency record count" "$debug_dependencies" \
	"dependency_records = 4"

serial_dependencies=$(run_make DEPENDENCY_METADATA_JOBS=1 \
	info.debug.dependencies)
if [ "$debug_dependencies" = "$serial_dependencies" ]; then
	pass "parallel dependency metadata preserves deterministic order"
else
	fail "parallel dependency metadata preserves deterministic order" \
		"parallel and serial output differ"
fi

if metadata_error=$(run_make \
	PORTS_target_libffi_EXTRA_ENVS='PORTSDIR=/nonexistent' \
	info.debug.dependencies 2>&1); then
	fail "dependency metadata probe failure is fatal" \
		"failed probe was accepted"
else
	pass "dependency metadata probe failure is fatal"
fi
assert_contains "dependency metadata failure is explicit" "$metadata_error" \
	"dependency metadata collection failed"

assert_contains "dependency type and requirement normalization" \
	"$debug_dependencies" \
	"consumer=target_libffi type=build requirement=autoconf>=2.69 origin=devel/autoconf"
assert_contains "selected definition with no instance is unresolved" \
	"$debug_dependencies" \
	"consumer=target_openssl type=lib requirement=libz.so origin=archivers/zlib provider_kind=uports provider_instance=none resolution=unselected"
assert_contains "unknown dependency origin is explicit" "$debug_dependencies" \
	"origin=devel/automake provider_kind=unresolved provider_instance=none resolution=unknown-origin"

autoconf_metadata=$(make --no-print-directory -s -C \
	"$portdir/devel/autoconf-2.72" uports-dependency-metadata)
assert_contains "provider capability metadata is exported" "$autoconf_metadata" \
	"provides|devel/autoconf"

capability_dependencies=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf' \
	info.debug.dependencies)
assert_contains "unique capability provider is selected" \
	"$capability_dependencies" \
	"origin=devel/autoconf provider_kind=uports provider_instance=host_pkg-config resolution=selected"

local_capability_dependencies=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf' \
	--eval='dependency_capabilities_target_libffi := devel/autoconf' \
	info.debug.dependencies)
assert_contains "consumer-group capability provider is preferred" \
	"$local_capability_dependencies" \
	"origin=devel/autoconf provider_kind=uports provider_instance=target_libffi resolution=selected"

ambiguous_capability_dependencies=$(run_make \
	--eval='dependency_capabilities_target_libffi := devel/autoconf' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf' \
	info.debug.dependencies)
assert_contains "multiple consumer-group capability providers are ambiguous" \
	"$ambiguous_capability_dependencies" \
	"origin=devel/autoconf provider_kind=uports provider_instance=none resolution=ambiguous"

dependency_graph=$(run_make info.debug.dependency-graph)
assert_contains "unresolved dependencies remain visible in graph" \
	"$dependency_graph" \
	"unresolved.dependency3 = consumer=target_libffi type=build origin=devel/autoconf resolution=unknown-origin"
assert_contains "empty selected graph is acyclic" "$dependency_graph" \
	"dependency_cycle = none"

if unresolved_output=$(run_make dependencies-check 2>&1); then
	fail "unresolved dependency graph fails validation" \
		"unresolved records were accepted"
else
	pass "unresolved dependency graph fails validation"
fi
assert_contains "dependency validation reports unresolved count" \
	"$unresolved_output" "unresolved_dependencies = 4"
assert_contains "dependency validation identifies unresolved record" \
	"$unresolved_output" \
	"unresolved.dependency3 = consumer=target_libffi type=build origin=devel/autoconf resolution=unknown-origin"

port_lifecycle_graph=$(make --no-print-directory -s -C \
	"$portdir/archivers/zlib" PORTSDIR="$portdir" \
	DESTDIR="$testdir/work/lifecycle" PREFIX=/usr/local \
	TYPE_SUFFIX=.regression ALTERNATIVE_WRKDIR="$testdir/work/lifecycle/src" \
	-pn build 2>/dev/null)
assert_contains "parallel lifecycle waits for previous phase" \
	"$port_lifecycle_graph" "build-message: | configure"
assert_contains "parallel lifecycle orders phase steps" \
	"$port_lifecycle_graph" "configure-message: | lib-depends"
assert_contains "parallel patch initialization waits for extraction" \
	"$port_lifecycle_graph" "git-init: | pre-patch-script"

resolved_dependency_graph=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf devel/automake archivers/zlib' \
	info.debug.dependency-graph)
assert_contains "selected dependency becomes typed graph edge" \
	"$resolved_dependency_graph" \
	"edge.dependency3 = consumer=target_libffi provider=host_pkg-config type=build origin=devel/autoconf"
assert_contains "shared provider graph is acyclic" "$resolved_dependency_graph" \
	"dependency_cycle = none"

dependency_order=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	info.debug.dependency-order)
assert_contains "dependency order includes every selected instance" \
	"$dependency_order" \
	"dependency_order_count = 6"
assert_contains "dependency order is provider-first and deterministic" \
	"$dependency_order" \
	"dependency_order = host_pkg-config target_expat2 toolchain_gmp host_openssl target_openssl target_libffi"

dependency_order_alias=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	dependency-order-list)
if [ "$dependency_order" = "$dependency_order_alias" ]; then
	pass "dependency order list exposes the read-only diagnostic"
else
	fail "dependency order list exposes the read-only diagnostic" \
		"alias and diagnostic output differ"
fi

dependency_lifecycle=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib devel/autoconf devel/automake' \
	info.debug.dependency-lifecycle)
assert_contains "build dependency maps to configure prerequisite" \
	"$dependency_lifecycle" \
	"prerequisite.dependency3 = consumer=target@libffi.configure provider=host@pkg-config.install type=build origin=devel/autoconf"
assert_contains "library dependency maps to configure prerequisite" \
	"$dependency_lifecycle" \
	"prerequisite.dependency1 = consumer=host@openssl.configure provider=host@pkg-config.install type=lib origin=archivers/zlib"

runtime_lifecycle=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib devel/autoconf devel/automake' \
	--eval='override dependency3_type := run' \
	--eval='override dependency3_target := build' \
	info.debug.dependency-lifecycle)
assert_contains "runtime dependency maps to stage prerequisite" \
	"$runtime_lifecycle" \
	"prerequisite.dependency3 = consumer=target@libffi.stage provider=host@pkg-config.build type=run origin=devel/autoconf"

if run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib devel/autoconf devel/automake' \
	dependency-lifecycle-check >/dev/null 2>&1; then
	pass "resolved lifecycle prerequisite plan passes validation"
else
	fail "resolved lifecycle prerequisite plan passes validation" \
		"dependency-lifecycle-check failed"
fi

if invalid_lifecycle=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib devel/autoconf devel/automake' \
	--eval='override dependency3_target := unsupported-target' \
	dependency-lifecycle-check 2>&1); then
	fail "unsupported dependency target fails lifecycle validation" \
		"unsupported target was accepted"
else
	pass "unsupported dependency target fails lifecycle validation"
fi
assert_contains "invalid dependency target is explicitly reported" \
	"$invalid_lifecycle" "invalid_dependency_targets = 1"

if run_make dependency-lifecycle-check >/dev/null 2>&1; then
	fail "unresolved lifecycle prerequisite plan fails validation" \
		"unresolved plan was accepted"
else
	pass "unresolved lifecycle prerequisite plan fails validation"
fi

dependency_execution=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	dependency-lifecycle-execute)
if [ "$dependency_execution" = "host@pkg-config.install
target@openssl.install" ]; then
	pass "opt-in execution is provider-first and deduplicated"
else
	fail "opt-in execution is provider-first and deduplicated" \
		"unexpected targets: $dependency_execution"
fi

if unresolved_execution=$(run_make \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	dependency-lifecycle-execute 2>&1); then
	fail "opt-in execution rejects unresolved plan before dispatch" \
		"unresolved plan was executed"
else
	pass "opt-in execution rejects unresolved plan before dispatch"
fi
assert_not_contains "unresolved execution dispatches no provider" \
	"$unresolved_execution" "@pkg-config.install"

target_execution_plan=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	DEPENDENCY_REQUEST=target@libffi.build dependency-execution-plan)
assert_contains "target execution plan follows transitive closure" \
	"$target_execution_plan" \
	"dependency_execution_instances = 3
dependency_execution_targets = host@pkg-config.install target@openssl.install"

fetch_execution_plan=$(run_make \
	DEPENDENCY_REQUEST=target@libffi.fetch dependency-execution-plan)
assert_contains "pre-configure target needs no package dependencies" \
	"$fetch_execution_plan" \
	"dependency_execution_instances = 1
dependency_execution_targets ="

runtime_build_plan=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf devel/automake' \
	--eval='override dependency3_type := run' \
	--eval='override dependency4_type := run' \
	DEPENDENCY_REQUEST=target@libffi.build dependency-execution-plan)
assert_contains "build request excludes runtime-only dependencies" \
	"$runtime_build_plan" \
	"dependency_execution_instances = 1
dependency_execution_targets ="

runtime_stage_plan=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf devel/automake' \
	--eval='override dependency3_type := run' \
	--eval='override dependency4_type := run' \
	DEPENDENCY_REQUEST=target@libffi.stage dependency-execution-plan)
assert_contains "stage request includes runtime dependencies" \
	"$runtime_stage_plan" \
	"dependency_execution_instances = 2
dependency_execution_targets = host@pkg-config.install"

if run_make DEPENDENCY_REQUEST=target@openssl.build \
	dependency-execution-plan >/dev/null 2>&1; then
	fail "target execution rejects unresolved reachable dependency" \
		"unresolved target closure was accepted"
else
	pass "target execution rejects unresolved reachable dependency"
fi

target_execution=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	DEPENDENCY_REQUEST=target@libffi.build \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	dependency-lifecycle-execute)
if [ "$target_execution" = "host@pkg-config.install
target@openssl.install" ]; then
	pass "target execution dispatches only transitive providers"
else
	fail "target execution dispatches only transitive providers" \
		"unexpected targets: $target_execution"
fi

dependency_execution_state=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	DEPENDENCY_REQUEST=target@libffi.build dependency-execution-state)
assert_contains "dependency state identifies requested consumer phase" \
	"$dependency_execution_state" "request|target_libffi|build"
assert_contains "dependency state records provider identity" \
	"$dependency_execution_state" \
	"dependency|target_libffi|build|autoconf>=2.69|devel/autoconf|uports|target_openssl|target@openssl.install"
assert_contains "dependency state records provider environment" \
	"$dependency_execution_state" \
	"instance|host_pkg-config|install|host|devel/pkg-config|"
assert_not_contains "dependency state excludes obsolete prefixes" \
	"$dependency_execution_state" "PREFIX=/usr "

dependency_state_fixture="$testdir/work/dependency-state"
dependency_state_source="$dependency_state_fixture/current"
dependency_state_saved="$dependency_state_fixture/dependency.configure.state"
rm -rf "$dependency_state_fixture"
mkdir -p "$dependency_state_fixture"
printf '%s\n' 'provider=uports:host_pkg-config:/usr/local' \
	>"$dependency_state_source"
dependency_state_new=$(DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	"$portdir/Mk/Scripts/dependency-state.sh" check)
assert_contains "missing saved dependency state is new" \
	"$dependency_state_new" "dependency_state = new"
dependency_state_save=$(DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	"$portdir/Mk/Scripts/dependency-state.sh" save)
assert_contains "dependency state save reports new" \
	"$dependency_state_save" "dependency_state = new"
dependency_state_same=$(DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	"$portdir/Mk/Scripts/dependency-state.sh" check)
assert_contains "saved dependency state is unchanged" \
	"$dependency_state_same" "dependency_state = unchanged"
printf '%s\n' 'provider=system:pkg-config:/usr/local' \
	>"$dependency_state_source"
dependency_state_changed=$(DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	"$portdir/Mk/Scripts/dependency-state.sh" check)
assert_contains "different dependency state is changed" \
	"$dependency_state_changed" "dependency_state = changed"
assert_contains "state comparison does not overwrite saved state" \
	"$(cat "$dependency_state_saved")" \
	"provider=uports:host_pkg-config:/usr/local"
port_state_save=$(make --no-print-directory -s -C \
	"$portdir/archivers/zlib" PORTSDIR="$portdir" \
	DESTDIR="$dependency_state_fixture/root" PREFIX=/usr/local \
	DEPENDENCY_STATE_CLASS=configure \
	DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	uports-dependency-state-save)
assert_contains "port target saves changed dependency state" \
	"$port_state_save" "dependency_state = changed"
port_state_same=$(make --no-print-directory -s -C \
	"$portdir/archivers/zlib" PORTSDIR="$portdir" \
	DESTDIR="$dependency_state_fixture/root" PREFIX=/usr/local \
	DEPENDENCY_STATE_CLASS=configure \
	DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	uports-dependency-state-check)
assert_contains "port target reads saved dependency state" \
	"$port_state_same" "dependency_state = unchanged"

if run_make DEPENDENCY_REQUEST=target@does-not-exist.build \
	dependency-execution-plan >/dev/null 2>&1; then
	fail "target execution rejects unknown request" \
		"unknown request was accepted"
else
	pass "target execution rejects unknown request"
fi

alias_execution_plan=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf devel/automake' \
	DEPENDENCY_REQUEST=libffi.build dependency-execution-plan)
assert_contains "target execution accepts unambiguous alias" \
	"$alias_execution_plan" "dependency_execution_root = target_libffi"

if run_make \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='dependency_capabilities_target_libffi := archivers/zlib' \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-execution-plan >/dev/null 2>&1; then
	fail "target execution rejects cycle in reachable closure" \
		"cyclic target closure was accepted"
else
	pass "target execution rejects cycle in reachable closure"
fi

if run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf devel/automake archivers/zlib' \
	--eval='override dependency3_target := unsupported-target' \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-execution-plan >/dev/null 2>&1; then
	fail "target execution rejects invalid target in reachable closure" \
		"invalid provider target was accepted"
else
	pass "target execution rejects invalid target in reachable closure"
fi

dependency_aware_dispatch=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	UPORTS_DEPENDENCIES=yes target@libffi.build)
if [ "$dependency_aware_dispatch" = "host@pkg-config.install
target@openssl.install
consumer=target@libffi.build" ]; then
	pass "dependency-aware canonical dispatch runs providers before consumer"
else
	fail "dependency-aware canonical dispatch runs providers before consumer" \
		"unexpected dispatch: $dependency_aware_dispatch"
fi

if failed_canonical_dispatch=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	DEPENDENCY_EXECUTE_COMMAND=false \
	UPORTS_DEPENDENCIES=yes target@libffi.build 2>&1); then
	fail "canonical provider failure is propagated" \
		"failed provider command was accepted"
else
	pass "canonical provider failure is propagated"
fi
assert_not_contains "canonical provider failure blocks consumer" \
	"$failed_canonical_dispatch" "consumer=target@libffi.build"

legacy_dispatch=$(run_make \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	target@libffi.build)
if [ "$legacy_dispatch" = "consumer=target@libffi.build" ]; then
	pass "normal canonical dispatch remains dependency-neutral by default"
else
	fail "normal canonical dispatch remains dependency-neutral by default" \
		"unexpected dispatch: $legacy_dispatch"
fi

if run_make UPORTS_DEPENDENCIES=invalid target@libffi.build \
	>/dev/null 2>&1; then
	fail "invalid dependency policy is rejected" "invalid policy was accepted"
else
	pass "invalid dependency policy is rejected"
fi

multi_root_plan=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	'DEPENDENCY_REQUESTS=target@expat2.build target@openssl.build target@libffi.build' \
	dependency-execution-plan)
assert_contains "multi-root plan reports requested consumers" \
	"$multi_root_plan" \
	"dependency_execution_roots = target_expat2.build target_openssl.build target_libffi.build"
assert_contains "multi-root plan deduplicates union of providers" \
	"$multi_root_plan" \
	"dependency_execution_targets = host@pkg-config.install target@openssl.install"

provider_root_plan=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	'DEPENDENCY_REQUESTS=target@openssl.install target@libffi.build' \
	dependency-execution-plan)
assert_contains "consumer root still executes when it is also a provider" \
	"$provider_root_plan" \
	"dependency_execution_targets = host@pkg-config.install target@openssl.install"

aggregate_dispatch=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	UPORTS_DEPENDENCIES=yes target.build)
assert_contains "aggregate dispatch prepares shared providers once" \
	"$aggregate_dispatch" \
	"host@pkg-config.install
target@openssl.install
consumer=target@expat2.build"
assert_contains "aggregate dispatch runs consumers after providers" \
	"$aggregate_dispatch" \
	"consumer=target@expat2.build
consumer=target@openssl.build
consumer=target@libffi.build"

parallel_aggregate_dispatch=$(make --no-print-directory -s -j8 -C \
	"$testdir" USE_HOSTTOOLS= \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	UPORTS_DEPENDENCIES=yes target.build)
case "$parallel_aggregate_dispatch" in
	"host@pkg-config.install
target@openssl.install
consumer="*)
		pass "parallel aggregate completes providers before consumers"
		;;
	*)
		fail "parallel aggregate completes providers before consumers" \
			"unexpected dispatch: $parallel_aggregate_dispatch"
		;;
esac

category_dispatch=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	UPORTS_DEPENDENCIES=yes security.build)
assert_contains "category aggregate uses one provider preflight" \
	"$category_dispatch" \
	"host@pkg-config.install
consumer=host@openssl.build
consumer=target@openssl.build"

global_fetch_dispatch=$(run_make \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	UPORTS_DEPENDENCIES=yes ports.fetch)
assert_not_contains "global pre-dependency aggregate dispatches no providers" \
	"$global_fetch_dispatch" ".install"
assert_contains "global aggregate dispatches consumers after preflight" \
	"$global_fetch_dispatch" "consumer=target@libffi.fetch"

if run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib devel/autoconf devel/automake' \
	DEPENDENCY_EXECUTE_COMMAND=false \
	dependency-lifecycle-execute >/dev/null 2>&1; then
	fail "provider execution failure is propagated" \
		"failed provider command was accepted"
else
	pass "provider execution failure is propagated"
fi

if run_make \
	--eval='dependency_capabilities_host_pkg-config := devel/autoconf devel/automake archivers/zlib' \
	dependencies-check >/dev/null 2>&1; then
	pass "resolved acyclic dependency graph passes validation"
else
	fail "resolved acyclic dependency graph passes validation" \
		"dependencies-check failed"
fi

if cycle_output=$(run_make \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='dependency_capabilities_target_libffi := archivers/zlib' \
	dependencies-check 2>&1); then
	fail "dependency cycle fails validation" "cycle was accepted"
else
	pass "dependency cycle fails validation"
fi
assert_contains "dependency cycle reports blocked instances" "$cycle_output" \
	"dependency_cycle_blocked_nodes = host_openssl target_openssl target_libffi"

if run_make \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='dependency_capabilities_target_libffi := archivers/zlib' \
	dependency-lifecycle-check >/dev/null 2>&1; then
	fail "cyclic lifecycle prerequisite plan fails validation" \
		"cyclic plan was accepted"
else
	pass "cyclic lifecycle prerequisite plan fails validation"
fi

if run_make \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='dependency_capabilities_target_libffi := archivers/zlib' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	dependency-lifecycle-execute >/dev/null 2>&1; then
	fail "opt-in execution rejects cycle before dispatch" \
		"cyclic plan was executed"
else
	pass "opt-in execution rejects cycle before dispatch"
fi

debug_targets=$(run_make info.debug.targets)
assert_contains "dispatch diagnostics" "$debug_targets" \
	"lifecycle_suffixes = 18
canonical_targets = 108
alias_targets = 90
aggregate_targets = 145"
assert_contains "dispatch validation diagnostics" "$debug_targets" \
	"ambiguous_short_ports = none
target_validation = enabled"
assert_not_contains "concise dispatch diagnostics omit target matrix" \
	"$debug_targets" "depends_exclude_targets ="

debug_targets_all=$(run_make info.debug.targets-all)
assert_contains "full target matrix remains available" "$debug_targets_all" \
	"depends_exclude_targets ="

debug_all=$(run_make info.debug)
assert_contains "default debug report includes normalized plan" "$debug_all" \
	"implicit_default_variants = 6"
assert_contains "default debug report includes dependency records" "$debug_all" \
	"dependency_records = 4"
assert_not_contains "default debug report omits target matrix" "$debug_all" \
	"depends_exclude_targets ="

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
	"discovered_definitions=33
resolved_logical_ports=33
selected_ports=20"
assert_contains "synthetic groups categories and instances" "$synthetic_stats" \
	"groups=4
categories=4
build_instances=22"
assert_contains "synthetic generated target counts" "$synthetic_stats" \
	"canonical_targets=396
alias_targets=360
aggregate_targets=163"

mkdir -p "$synthetic_dir/feeds/devel/synthetic-added"
printf '# discovery invalidation fixture\n' \
	>"$synthetic_dir/feeds/devel/synthetic-added/Makefile"
synthetic_added=$(make --no-print-directory -s -C "$synthetic_dir" \
	USE_HOSTTOOLS= planner-stats)
assert_contains "new port is discovered without cache invalidation" \
	"$synthetic_added" "discovered_definitions=34
resolved_logical_ports=34"
rm -rf "$synthetic_dir/feeds/devel/synthetic-added"
synthetic_removed=$(make --no-print-directory -s -C "$synthetic_dir" \
	USE_HOSTTOOLS= planner-stats)
assert_contains "removed port is dropped without cache invalidation" \
	"$synthetic_removed" "discovered_definitions=33
resolved_logical_ports=33"
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

unknown_target_file=${TMPDIR:-/tmp}/uports-tools-unknown-target.$$.err
if make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	unknown@libffi.build >"$unknown_target_file" 2>&1; then
	fail "unknown canonical target is rejected" "make unexpectedly succeeded"
else
	unknown_target_output=$(cat "$unknown_target_file")
	assert_contains "unknown canonical target is rejected" \
		"$unknown_target_output" \
		"Unknown uports lifecycle target: unknown@libffi.build"
fi
rm -f "$unknown_target_file"

unknown_suffix_file=${TMPDIR:-/tmp}/uports-tools-unknown-suffix.$$.err
if make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	target@libffi.unknown >"$unknown_suffix_file" 2>&1; then
	fail "unknown lifecycle suffix is rejected" "make unexpectedly succeeded"
else
	unknown_suffix_output=$(cat "$unknown_suffix_file")
	assert_contains "unknown lifecycle suffix is rejected" \
		"$unknown_suffix_output" \
		"No rule to make target 'target@libffi.unknown'"
fi
rm -f "$unknown_suffix_file"

touch "$testdir/target@libffi.build"
forced_dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	target@libffi.build)
rm -f "$testdir/target@libffi.build"
assert_contains "canonical dispatch ignores matching filesystem file" \
	"$forced_dispatch" "target@devel/libffi build"

alias_dispatch=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	openssl.build)
assert_contains "default alias selects default group" "$alias_dispatch" \
	"target@security/openssl build"
assert_not_contains "default alias excludes nondefault group" "$alias_dispatch" \
	"host@security/openssl build"

unknown_alias_file=${TMPDIR:-/tmp}/uports-tools-unknown-alias.$$.err
if make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	does-not-exist.build >"$unknown_alias_file" 2>&1; then
	fail "unknown short alias is rejected" "make unexpectedly succeeded"
else
	unknown_alias_output=$(cat "$unknown_alias_file")
	assert_contains "unknown short alias is rejected" "$unknown_alias_output" \
		"Unknown uports lifecycle target: does-not-exist.build"
fi
rm -f "$unknown_alias_file"

touch "$testdir/libffi.build"
forced_alias=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	libffi.build)
rm -f "$testdir/libffi.build"
assert_contains "short alias ignores matching filesystem file" \
	"$forced_alias" "target@devel/libffi build"

ambiguous_dir=${TMPDIR:-/tmp}/uports-tools-ambiguous.$$
"$testdir/../generate-synthetic-plan.sh" "$ambiguous_dir" 2
mkdir -p "$ambiguous_dir/feeds/devel/duplicate" \
	"$ambiguous_dir/feeds/lang/duplicate"
printf '# ambiguous fixture\n' >"$ambiguous_dir/feeds/devel/duplicate/Makefile"
printf '# ambiguous fixture\n' >"$ambiguous_dir/feeds/lang/duplicate/Makefile"
ambiguous_file=${TMPDIR:-/tmp}/uports-tools-ambiguous.$$.err
if make --no-print-directory -s -C "$ambiguous_dir" USE_HOSTTOOLS= \
	PORTS_LISTS='g1@devel/duplicate g2@lang/duplicate' planner-stats \
	>"$ambiguous_file" 2>&1; then
	fail "ambiguous short port names fail early" "make unexpectedly succeeded"
else
	ambiguous_output=$(cat "$ambiguous_file")
	assert_contains "ambiguous short port names fail early" \
		"$ambiguous_output" "ambiguous short port names: duplicate"
fi
rm -rf "$ambiguous_dir"
rm -f "$ambiguous_file"

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

touch "$testdir/target.build" "$testdir/devel.build"
forced_group=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	target.build)
forced_category=$(make --no-print-directory -n -C "$testdir" USE_HOSTTOOLS= \
	devel.build)
rm -f "$testdir/target.build" "$testdir/devel.build"
assert_contains "group aggregate ignores matching filesystem file" \
	"$forced_group" "target@devel/libffi build"
assert_contains "category aggregate ignores matching filesystem file" \
	"$forced_category" "target@devel/libffi build"

collision_dispatch=$(make --no-print-directory -n -C "$testdir" \
	USE_HOSTTOOLS= \
	PORTS_LISTS='textproc@textproc/expat2 textproc@devel/libffi' \
	textproc.build)
assert_contains "aggregate name collision includes category members" \
	"$collision_dispatch" "textproc@textproc/expat2 build"
assert_contains "aggregate name collision includes group members" \
	"$collision_dispatch" "textproc@devel/libffi build"

main_patch_fixture=${TMPDIR:-/tmp}/uports-main-patch.$$
main_patch_repo=$main_patch_fixture/repo
main_patch_dir=$main_patch_fixture/patches
rm -rf "$main_patch_fixture"
mkdir -p "$main_patch_repo" "$main_patch_dir"
git -C "$main_patch_repo" init -q
printf 'before\n' >"$main_patch_repo/tracked"
git -C "$main_patch_repo" add tracked
git -C "$main_patch_repo" -c user.name='uports test' \
	-c user.email='uports-test@example.invalid' commit -qm base
main_patch_base=$(git -C "$main_patch_repo" rev-parse HEAD)
printf 'after\n' >"$main_patch_repo/tracked"
git -C "$main_patch_repo" add tracked
git -C "$main_patch_repo" -c user.name='uports test' \
	-c user.email='uports-test@example.invalid' commit -qm 'main patch fixture'
git -C "$main_patch_repo" format-patch -1 --stdout \
	>"$main_patch_dir/0001-main.patch"
printf '%s\n' 0001-main.patch >"$main_patch_dir/series"
git -C "$main_patch_repo" reset -q --hard "$main_patch_base"

PATCH_WRKSRC="$main_patch_repo" PATCHLIST="$main_patch_dir/series" \
	PATCHDIR="$main_patch_dir" GIT=git \
	"$portdir/Mk/Scripts/git-patch.sh" >/dev/null
assert_eq "main patch series applies" \
	"$(git -C "$main_patch_repo" log -1 --format=%s)" "main patch fixture"
main_patch_repeat=$(PATCH_WRKSRC="$main_patch_repo" \
	PATCHLIST="$main_patch_dir/series" PATCHDIR="$main_patch_dir" GIT=git \
	"$portdir/Mk/Scripts/git-patch.sh")
assert_contains "applied main patch series is restartable" \
	"$main_patch_repeat" "patch series already applied"

git -C "$main_patch_repo" reset -q --hard "$main_patch_base"
printf '%s\n' 0001-main.patch 0001-main.patch >"$main_patch_dir/series"
if PATCH_WRKSRC="$main_patch_repo" PATCHLIST="$main_patch_dir/series" \
	PATCHDIR="$main_patch_dir" GIT=git \
	"$portdir/Mk/Scripts/git-patch.sh" >/dev/null 2>&1; then
	fail "failed main patch series is rejected" "script unexpectedly succeeded"
else
	pass "failed main patch series is rejected"
fi
assert_eq "failed main patch series rolls back cleanly" \
	"$(git -C "$main_patch_repo" rev-parse HEAD)" "$main_patch_base"
rm -rf "$main_patch_fixture"

submodule_fixture=${TMPDIR:-/tmp}/uports-submodule-info.$$
submodule_source=$submodule_fixture/source
submodule_parent=$submodule_fixture/parent
submodule_port=$submodule_fixture/port
rm -rf "$submodule_fixture"
mkdir -p "$submodule_source" "$submodule_parent" "$submodule_port/files/submodules/module-ready"

git -C "$submodule_source" init -q
printf 'initial\n' >"$submodule_source/tracked"
git -C "$submodule_source" add tracked
git -C "$submodule_source" -c user.name='uports test' \
	-c user.email='uports-test@example.invalid' commit -qm initial
submodule_expected=$(git -C "$submodule_source" rev-parse HEAD)

git -C "$submodule_parent" init -q
cat >"$submodule_parent/.gitmodules" <<EOF
[submodule "module-ready"]
	path = module-ready
	url = $submodule_source
[submodule "module-dirty"]
	path = module-dirty
	url = $submodule_source
[submodule "module-mismatch"]
	path = module-mismatch
	url = $submodule_source
[submodule "module-uninitialized"]
	path = module-uninitialized
	url = $submodule_source
EOF
git -C "$submodule_parent" add .gitmodules
for path in module-ready module-dirty module-mismatch module-uninitialized; do
	git -C "$submodule_parent" update-index --add --cacheinfo \
		160000,"$submodule_expected","$path"
done
git -C "$submodule_parent" -c user.name='uports test' \
	-c user.email='uports-test@example.invalid' commit -qm parent

printf 'second\n' >>"$submodule_source/tracked"
git -C "$submodule_source" add tracked
git -C "$submodule_source" -c user.name='uports test' \
	-c user.email='uports-test@example.invalid' commit -qm second
submodule_mismatch=$(git -C "$submodule_source" rev-parse HEAD)

for path in module-ready module-dirty module-mismatch; do
	git -c protocol.file.allow=always clone -q "$submodule_source" \
		"$submodule_parent/$path"
done
git -C "$submodule_parent/module-ready" checkout -q "$submodule_expected"
git -C "$submodule_parent/module-dirty" checkout -q "$submodule_expected"
printf 'dirty\n' >>"$submodule_parent/module-dirty/tracked"
mkdir -p "$submodule_parent/module-uninitialized"

cat >"$submodule_port/files/submodules/module-ready/series.linux-amd64" <<'EOF'
# platform-specific fixture
0001-first.patch

0002-second.patch
EOF
cat >"$submodule_port/Makefile" <<EOF
PORTNAME = submodule-fixture
DISTVERSION = 1
CATEGORIES = devel
SCM_SUBMODULES = module-ready module-dirty module-mismatch module-uninitialized module-missing ../escape module-ready
WRKSRC = $submodule_parent
MASTERDIR = \$(CURDIR)
PORTSDIR = $portdir
include \$(PORTSDIR)/Mk/linux.port.mk
EOF

submodule_before=$(git -C "$submodule_parent/module-ready" status --porcelain)
submodule_output=$(make --no-print-directory -s -C "$submodule_port" \
	OPSYS=linux OPSYS_SUFX= ARCH=amd64 info.debug.submodules)
submodule_after=$(git -C "$submodule_parent/module-ready" status --porcelain)

assert_contains "submodule metadata preserves declaration order" \
	"$submodule_output" \
	"submodules.declared = module-ready module-dirty module-mismatch module-uninitialized module-missing ../escape module-ready"
assert_contains "submodule metadata reports declaration count" \
	"$submodule_output" "submodules.count = 7"
assert_contains "ready submodule and platform series diagnostics" \
	"$submodule_output" \
	"submodule.1 = path=module-ready expected=$submodule_expected checkout=$submodule_expected initialized=yes dirty=no patch_method=V2 patch_series=series.linux-amd64 patch_count=2 state=ready"
assert_contains "dirty submodule diagnostics" "$submodule_output" \
	"path=module-dirty expected=$submodule_expected checkout=$submodule_expected initialized=yes dirty=yes patch_method=V2 patch_series=none patch_count=0 state=dirty"
assert_contains "commit mismatch diagnostics" "$submodule_output" \
	"path=module-mismatch expected=$submodule_expected checkout=$submodule_mismatch initialized=yes dirty=no patch_method=V2 patch_series=none patch_count=0 state=commit-mismatch"
assert_contains "uninitialized submodule diagnostics" "$submodule_output" \
	"path=module-uninitialized expected=$submodule_expected checkout=none initialized=no dirty=unknown patch_method=V2 patch_series=none patch_count=0 state=uninitialized"
assert_contains "missing gitlink diagnostics" "$submodule_output" \
	"path=module-missing expected=none checkout=none initialized=no dirty=unknown patch_method=V2 patch_series=none patch_count=0 state=missing-gitlink"
assert_contains "unsafe submodule path diagnostics" "$submodule_output" \
	"path=../escape expected=none checkout=none initialized=no dirty=unknown patch_method=V2 patch_series=none patch_count=0 state=invalid-path"
assert_contains "duplicate submodule diagnostics" "$submodule_output" \
	"submodule.7 = path=module-ready expected=none checkout=none initialized=no dirty=unknown patch_method=V2 patch_series=series.linux-amd64 patch_count=2 state=duplicate"
if [ "$submodule_before" = "$submodule_after" ]; then
	pass "submodule diagnostics do not modify checkout"
else
	fail "submodule diagnostics do not modify checkout" \
		"before: $submodule_before; after: $submodule_after"
fi

submodule_prepare_parent=$submodule_fixture/prepare-parent
submodule_prepare_port=$submodule_fixture/prepare-port
mkdir -p "$submodule_prepare_parent" "$submodule_prepare_port"
git -C "$submodule_prepare_parent" init -q
cat >"$submodule_prepare_parent/.gitmodules" <<EOF
[submodule "module-init"]
	path = module-init
	url = $submodule_source
[submodule "module-mismatch"]
	path = module-mismatch
	url = $submodule_source
EOF
git -C "$submodule_prepare_parent" add .gitmodules
for path in module-init module-mismatch; do
	git -C "$submodule_prepare_parent" update-index --add --cacheinfo \
		160000,"$submodule_expected","$path"
done
git -C "$submodule_prepare_parent" -c user.name='uports test' \
	-c user.email='uports-test@example.invalid' commit -qm parent
git -c protocol.file.allow=always clone -q "$submodule_source" \
	"$submodule_prepare_parent/module-mismatch"

cat >"$submodule_prepare_port/Makefile" <<EOF
PORTNAME = submodule-prepare-fixture
DISTVERSION = 1
CATEGORIES = devel
SCM_SUBMODULES = module-init module-mismatch
SCM_FETCH_ENV = GIT_ALLOW_PROTOCOL=file
WRKSRC = $submodule_prepare_parent
MASTERDIR = \$(CURDIR)
PORTSDIR = $portdir
include \$(PORTSDIR)/Mk/linux.port.mk
EOF

submodule_prepare_output=$(make --no-print-directory -s \
	-C "$submodule_prepare_port" prepare-submodules)
assert_contains "submodule preparation follows declaration order" \
	"$submodule_prepare_output" \
	"SUBMOD  module-init ($submodule_expected)"
assert_contains "submodule preparation visits clean mismatch" \
	"$submodule_prepare_output" \
	"SUBMOD  module-mismatch ($submodule_expected)"
if [ "$(git -C "$submodule_prepare_parent/module-init" rev-parse HEAD)" = \
    "$submodule_expected" ]; then
	pass "submodule preparation initializes exact gitlink commit"
else
	fail "submodule preparation initializes exact gitlink commit" \
		"unexpected module-init commit"
fi
if [ "$(git -C "$submodule_prepare_parent/module-mismatch" rev-parse HEAD)" = \
    "$submodule_expected" ]; then
	pass "submodule preparation corrects clean commit mismatch"
else
	fail "submodule preparation corrects clean commit mismatch" \
		"unexpected module-mismatch commit"
fi

submodule_patch_root=$submodule_prepare_port/files/submodules
mkdir -p "$submodule_patch_root/module-init" \
	"$submodule_patch_root/module-mismatch"
git -C "$submodule_source" format-patch -1 "$submodule_mismatch" --stdout \
	>"$submodule_patch_root/module-init/0001-second.patch"
printf '%s\n' 0001-second.patch \
	>"$submodule_patch_root/module-init/series.linux-amd64"
git -C "$submodule_prepare_parent/module-init" config user.name 'uports test'
git -C "$submodule_prepare_parent/module-init" config user.email \
	'uports-test@example.invalid'

submodule_patch_output=$(make --no-print-directory -s \
	-C "$submodule_prepare_port" OPSYS=linux OPSYS_SUFX= ARCH=amd64 \
	apply-submodule-patches)
assert_contains "submodule patch application reports selected series" \
	"$submodule_patch_output" \
	"SUBPAT  module-init (series.linux-amd64)"
assert_contains "submodule patch application reports patch" \
	"$submodule_patch_output" "module-init/0001-second.patch (am)"
if [ "$(git -C "$submodule_prepare_parent/module-init" log -1 --format=%s)" = \
    second ] && [ -z "$(git -C "$submodule_prepare_parent/module-init" \
    status --porcelain)" ]; then
	pass "submodule git-am series creates a clean commit"
else
	fail "submodule git-am series creates a clean commit" \
		"patch result is not the expected clean commit"
fi
submodule_patched_info=$(make --no-print-directory -s \
	-C "$submodule_prepare_port" OPSYS=linux OPSYS_SUFX= ARCH=amd64 \
	info.debug.submodules)
assert_contains "submodule diagnostics recognize applied series" \
	"$submodule_patched_info" \
	"path=module-init expected=$submodule_expected"
assert_contains "submodule diagnostics report patched state" \
	"$submodule_patched_info" \
	"patch_series=series.linux-amd64 patch_count=1 state=patched"

git -C "$submodule_prepare_parent/module-init" reset -q --hard \
	"$submodule_expected"
printf '%s\n' missing.patch \
	>"$submodule_patch_root/module-mismatch/series.linux-amd64"
submodule_patch_error=$submodule_fixture/submodule-patch.err
if make --no-print-directory -s -C "$submodule_prepare_port" \
    OPSYS=linux OPSYS_SUFX= ARCH=amd64 apply-submodule-patches \
    >"$submodule_patch_error" 2>&1; then
	fail "submodule patch metadata is validated before application" \
		"missing patch unexpectedly accepted"
else
	assert_contains "submodule patch metadata is validated before application" \
		"$(cat "$submodule_patch_error")" \
		"submodule module-mismatch: missing patch missing.patch"
fi
if [ "$(git -C "$submodule_prepare_parent/module-init" rev-parse HEAD)" = \
    "$submodule_expected" ]; then
	pass "submodule patch prevalidation prevents partial application"
else
	fail "submodule patch prevalidation prevents partial application" \
		"earlier series was applied before validation failed"
fi

rm -f "$submodule_patch_root/module-mismatch/series.linux-amd64"
printf 'not an email patch\n' \
	>"$submodule_patch_root/module-init/0002-broken.patch"
printf '%s\n' 0001-second.patch 0002-broken.patch \
	>"$submodule_patch_root/module-init/series.linux-amd64"
if make --no-print-directory -s -C "$submodule_prepare_port" \
    OPSYS=linux OPSYS_SUFX= ARCH=amd64 apply-submodule-patches \
    >"$submodule_patch_error" 2>&1; then
	fail "failed submodule series is rejected" \
		"broken patch unexpectedly accepted"
else
	assert_contains "failed submodule series is rejected" \
		"$(cat "$submodule_patch_error")" \
		"patch 0002-broken.patch failed; series rolled back"
fi
if [ "$(git -C "$submodule_prepare_parent/module-init" rev-parse HEAD)" = \
    "$submodule_expected" ] && \
   [ -z "$(git -C "$submodule_prepare_parent/module-init" status --porcelain)" ] && \
   [ ! -d "$submodule_prepare_parent/.git/modules/module-init/rebase-apply" ]; then
	pass "failed submodule series rolls back cleanly"
else
	fail "failed submodule series rolls back cleanly" \
		"submodule was not restored to its clean starting commit"
fi

submodule_atomic_parent=$submodule_fixture/atomic-parent
submodule_atomic_port=$submodule_fixture/atomic-port
mkdir -p "$submodule_atomic_parent" "$submodule_atomic_port"
git -C "$submodule_atomic_parent" init -q
cat >"$submodule_atomic_parent/.gitmodules" <<EOF
[submodule "module-first"]
	path = module-first
	url = $submodule_source
[submodule "module-dirty"]
	path = module-dirty
	url = $submodule_source
EOF
git -C "$submodule_atomic_parent" add .gitmodules
for path in module-first module-dirty; do
	git -C "$submodule_atomic_parent" update-index --add --cacheinfo \
		160000,"$submodule_expected","$path"
done
git -C "$submodule_atomic_parent" -c user.name='uports test' \
	-c user.email='uports-test@example.invalid' commit -qm parent
git -c protocol.file.allow=always clone -q "$submodule_source" \
	"$submodule_atomic_parent/module-dirty"
printf 'dirty\n' >>"$submodule_atomic_parent/module-dirty/tracked"
cat >"$submodule_atomic_port/Makefile" <<EOF
PORTNAME = submodule-atomic-fixture
DISTVERSION = 1
CATEGORIES = devel
SCM_SUBMODULES = module-first module-dirty
SCM_FETCH_ENV = GIT_ALLOW_PROTOCOL=file
WRKSRC = $submodule_atomic_parent
MASTERDIR = \$(CURDIR)
PORTSDIR = $portdir
include \$(PORTSDIR)/Mk/linux.port.mk
EOF
submodule_prepare_error=$submodule_fixture/prepare.err
if make --no-print-directory -s -C "$submodule_atomic_port" \
    prepare-submodules >"$submodule_prepare_error" 2>&1; then
	fail "submodule preparation rejects dirty checkout" \
		"dirty checkout unexpectedly accepted"
else
	assert_contains "submodule preparation rejects dirty checkout" \
		"$(cat "$submodule_prepare_error")" \
		"submodule module-dirty: checkout is dirty"
fi
if [ ! -e "$submodule_atomic_parent/module-first/.git" ]; then
	pass "submodule validation completes before mutation"
else
	fail "submodule validation completes before mutation" \
		"module-first was initialized before validation failed"
fi
rm -rf "$submodule_fixture"

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
