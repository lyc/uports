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

platform_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/uports-regression-platform.XXXXXX")
printf '%s\n' \
	'#!/bin/sh' \
	'case "$1" in' \
	'  -s) printf "%s\\n" Linux ;;' \
	'  -m) printf "%s\\n" x86_64 ;;' \
	'  *) exec /usr/bin/uname "$@" ;;' \
	'esac' > "$platform_test_dir/uname"
chmod +x "$platform_test_dir/uname"
trap 'rm -rf "$platform_test_dir"' EXIT HUP INT TERM

run_make()
{
	DEPENDENCY_PROVIDER_POLICIES= PATH="$platform_test_dir:$PATH" \
		make --no-print-directory -s -C "$testdir" USE_HOSTTOOLS= "$@"
}

snapshot=$(run_make regression.snapshot)

default_provider_mode=$(run_make dependency-provider-mode-check)
assert_contains "uports is the default provider mode" "$default_provider_mode" \
	"dependency_provider_mode = uports"
assert_contains "default provider mode disables external providers" \
	"$default_provider_mode" "dependency_external_providers = no"

legacy_provider_mode=$(run_make DEPENDENCY_EXTERNAL_PROVIDERS=yes \
	dependency-provider-mode-check)
assert_contains "legacy external opt-in maps to explicit mode" \
	"$legacy_provider_mode" "dependency_provider_mode = explicit"

host_provider_mode=$(run_make DEPENDENCY_PROVIDER_MODE=host \
	dependency-provider-mode-check)
assert_contains "host mode enables external provider machinery" \
	"$host_provider_mode" "dependency_external_providers = yes"
assert_contains "host mode retains uports fallback" "$host_provider_mode" \
	"dependency_provider_fallback = uports"

system_provider_mode=$(run_make DEPENDENCY_PROVIDER_MODE=system-only \
	dependency-provider-mode-check)
assert_contains "system-only mode has no uports fallback" \
	"$system_provider_mode" "dependency_provider_fallback = none"

if run_make DEPENDENCY_PROVIDER_MODE=invalid \
	dependency-provider-mode-check >/dev/null 2>&1; then
	fail "unknown provider mode is rejected" "invalid mode was accepted"
else
	pass "unknown provider mode is rejected"
fi

if run_make DEPENDENCY_PROVIDER_MODE=host \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	dependency-provider-mode-check >/dev/null 2>&1; then
	fail "host mode rejects cross targets" "cross target was accepted"
else
	pass "host mode rejects cross targets"
fi

if run_make DEPENDENCY_PROVIDER_MODE=system-only \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	dependency-provider-mode-check >/dev/null 2>&1; then
	fail "system-only mode rejects cross targets" "cross target was accepted"
else
	pass "system-only mode rejects cross targets"
fi

if run_make DEPENDENCY_PROVIDER_MODE=explicit \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	dependency-provider-mode-check >/dev/null 2>&1; then
	pass "explicit mode accepts cross targets"
else
	fail "explicit mode accepts cross targets" "cross target was rejected"
fi

linux_provider_profile=$(run_make dependency-provider-profile-check)
assert_contains "Linux host selects Linux provider profile" \
	"$linux_provider_profile" \
	"dependency_provider_profile = linux
dependency_provider_profile_opsys = linux"
assert_contains "Linux profile declares native command candidates" \
	"$linux_provider_profile" \
	"dependency_provider_profile_pkg_config_candidates = pkg-config pkgconf
dependency_provider_profile_cc_candidates = cc gcc clang"

macos_provider_profile=$(run_make DEPENDENCY_BUILD_OPSYS=darwin \
	DEPENDENCY_BUILD_ARCH=arm64 dependency-provider-profile-check)
assert_contains "Darwin host selects macOS provider profile" \
	"$macos_provider_profile" \
	"dependency_provider_profile = macos
dependency_provider_profile_opsys = darwin"
assert_contains "macOS profile declares system and package-manager prefixes" \
	"$macos_provider_profile" \
	"dependency_provider_profile_prefixes = /usr /usr/local /opt/homebrew /opt/local"

if run_make DEPENDENCY_PROVIDER_PROFILE=macos \
	dependency-provider-profile-check >/dev/null 2>&1; then
	fail "provider profile must match build operating system" \
		"macOS profile was accepted for Linux"
else
	pass "provider profile must match build operating system"
fi

provider_registry=$(run_make dependency-provider-registry-check)
assert_contains "built-in provider registry is valid" "$provider_registry" \
	"dependency_provider_registry_entries = 4
dependency_provider_registry_invalid = 0"
assert_contains "ncurses registry declares its required interface" \
	"$provider_registry" \
	"key=ncurses origin=devel/ncurses method=pkg-config module=ncurses header=ncurses.h link_name=ncurses state=valid"
assert_contains "readline registry accepts a nested header" \
	"$provider_registry" \
	"key=readline origin=devel/readline method=pkg-config module=readline header=readline/readline.h link_name=readline state=valid"

empty_provider_registry=$(run_make DEPENDENCY_PROVIDER_REGISTRY= \
	dependency-provider-registry-check)
assert_contains "empty provider registry remains valid" \
	"$empty_provider_registry" \
	"dependency_provider_registry_entries = 0
dependency_provider_registry_invalid = 0"

invalid_provider_registry=$(run_make \
	'DEPENDENCY_PROVIDER_REGISTRY=one two three four' \
	'DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.one=devel/example' \
	'DEPENDENCY_PROVIDER_REGISTRY_METHOD.one=unknown' \
	'DEPENDENCY_PROVIDER_REGISTRY_MODULE.one=example' \
	'DEPENDENCY_PROVIDER_REGISTRY_HEADER.one=example.h' \
	'DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.one=example' \
	'DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.two=devel/example' \
	'DEPENDENCY_PROVIDER_REGISTRY_METHOD.two=pkg-config' \
	'DEPENDENCY_PROVIDER_REGISTRY_MODULE.two=example' \
	'DEPENDENCY_PROVIDER_REGISTRY_HEADER.two=example.h' \
	'DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.two=example' \
	'DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.three=devel/other' \
	'DEPENDENCY_PROVIDER_REGISTRY_METHOD.three=pkg-config' \
	'DEPENDENCY_PROVIDER_REGISTRY_MODULE.three=other' \
	'DEPENDENCY_PROVIDER_REGISTRY_HEADER.three=../other.h' \
	'DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.three=other' \
	'DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.four=devel/example' \
	'DEPENDENCY_PROVIDER_REGISTRY_METHOD.four=pkg-config' \
	'DEPENDENCY_PROVIDER_REGISTRY_MODULE.four=example' \
	'DEPENDENCY_PROVIDER_REGISTRY_HEADER.four=example.h' \
	'DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.four=example' \
	dependency-provider-registry-list)
assert_contains "registry rejects unknown discovery method" \
	"$invalid_provider_registry" "registry.1 = key=one origin=devel/example method=unknown module=example header=example.h link_name=example state=invalid-method"
assert_contains "registry rejects unsafe header path" \
	"$invalid_provider_registry" "registry.3 = key=three origin=devel/other method=pkg-config module=other header=../other.h link_name=other state=invalid-header"
assert_contains "registry rejects duplicate origins" \
	"$invalid_provider_registry" "registry.4 = key=four origin=devel/example method=pkg-config module=example header=example.h link_name=example state=duplicate-origin"
if run_make \
	'DEPENDENCY_PROVIDER_REGISTRY=bad' \
	'DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.bad=invalid' \
	'DEPENDENCY_PROVIDER_REGISTRY_METHOD.bad=pkg-config' \
	'DEPENDENCY_PROVIDER_REGISTRY_MODULE.bad=bad' \
	'DEPENDENCY_PROVIDER_REGISTRY_HEADER.bad=bad.h' \
	'DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.bad=bad' \
	dependency-provider-registry-check >/dev/null 2>&1; then
	fail "invalid provider registry fails validation" \
		"invalid registry was accepted"
else
	pass "invalid provider registry fails validation"
fi

discovery_test_dir=$(mktemp -d "$testdir/work/provider-discovery.XXXXXX")
mkdir -p "$discovery_test_dir/include" "$discovery_test_dir/lib" \
	"$discovery_test_dir/pkgconfig"
fake_pkg_config="$discovery_test_dir/pkg-config"
printf '%s\n' \
	'#!/bin/sh' \
	'case "$1" in' \
	'  --exists) exit 0 ;;' \
	"  --cflags) echo '-I$discovery_test_dir/include' ;;" \
	"  --libs) echo '-L$discovery_test_dir/lib -lexample' ;;" \
	"  --cflags-only-I) echo '-I$discovery_test_dir/include' ;;" \
	"  --libs-only-L) echo '-L$discovery_test_dir/lib' ;;" \
	"  --libs-only-l) echo '-lexample' ;;" \
	"  --path) echo '$discovery_test_dir/pkgconfig/example.pc' ;;" \
	'  *) exit 1 ;;' \
	'esac' > "$fake_pkg_config"
chmod +x "$fake_pkg_config"
fake_cc="$discovery_test_dir/cc"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$fake_cc"
chmod +x "$fake_cc"
discovery_registry_args="DEPENDENCY_PROVIDER_REGISTRY=example DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.example=devel/autoconf DEPENDENCY_PROVIDER_REGISTRY_METHOD.example=pkg-config DEPENDENCY_PROVIDER_REGISTRY_MODULE.example=example DEPENDENCY_PROVIDER_REGISTRY_HEADER.example=example/example.h DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.example=example"
provider_discovery=$(run_make $discovery_registry_args \
	"DEPENDENCY_PROVIDER_PKG_CONFIG=$fake_pkg_config" \
	"DEPENDENCY_PROVIDER_CC=$fake_cc" \
	dependency-provider-discovery-check)
assert_contains "pkg-config discovery validates required interface" \
	"$provider_discovery" \
	"discovery|example|devel/autoconf|available|validated|$discovery_test_dir/include|$discovery_test_dir/lib|$discovery_test_dir/pkgconfig"

header_order_cc="$discovery_test_dir/header-order-cc"
printf '%s\n' \
	'#!/bin/sh' \
	'source_file=' \
	'for argument do' \
	'  case "$argument" in *.c) source_file=$argument ;; esac' \
	'done' \
	'[ -n "$source_file" ] || exit 1' \
	'[ "$(sed -n "1p" "$source_file")" = "#include <stdio.h>" ] || exit 1' \
	'[ "$(sed -n "2p" "$source_file")" = "#include <example/example.h>" ]' \
	> "$header_order_cc"
chmod +x "$header_order_cc"
provider_header_order=$(run_make $discovery_registry_args \
	"DEPENDENCY_PROVIDER_PKG_CONFIG=$fake_pkg_config" \
	"DEPENDENCY_PROVIDER_CC=$header_order_cc" \
	dependency-provider-discovery-check)
assert_contains "native probe supplies standard I/O before registered header" \
	"$provider_header_order" \
	"discovery|example|devel/autoconf|available|validated"

provider_candidate_discovery=$(run_make $discovery_registry_args \
	"DEPENDENCY_PROVIDER_PKG_CONFIG_CANDIDATES=missing-pkg-config $fake_pkg_config" \
	"DEPENDENCY_PROVIDER_CC_CANDIDATES=missing-cc $fake_cc" \
	dependency-provider-discovery-check)
assert_contains "profile command candidates select the first available tools" \
	"$provider_candidate_discovery" \
	"discovery|example|devel/autoconf|available|validated"

missing_pkg_config="$discovery_test_dir/pkg-config-missing"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$missing_pkg_config"
chmod +x "$missing_pkg_config"
provider_discovery_missing=$(run_make $discovery_registry_args \
	"DEPENDENCY_PROVIDER_PKG_CONFIG=$missing_pkg_config" \
	"DEPENDENCY_PROVIDER_CC=$fake_cc" \
	dependency-provider-discovery-list)
assert_contains "missing pkg-config module is an unavailable provider" \
	"$provider_discovery_missing" \
	"discovery|example|devel/autoconf|unavailable|module-missing|none|none|none"

empty_provider_policy=$(run_make dependency-provider-policy-list)
assert_contains "empty provider policy is valid" "$empty_provider_policy" \
	"dependency_provider_policies = 0
dependency_provider_policy_invalid = 0"

valid_provider_policy='system@target@target@linux@amd64@devel/ncurses@linux-base sdk@target@target@darwin@arm64@devel/libffi@macos-sdk'
provider_policy=$(run_make \
	"DEPENDENCY_PROVIDER_POLICIES=$valid_provider_policy" \
	dependency-provider-policy-list)
assert_contains "system provider policy is normalized" "$provider_policy" \
	"policy.1 = kind=system context=target consumer_group=target opsys=linux arch=amd64 origin=devel/ncurses identity=linux-base state=valid"
assert_contains "SDK provider policy is normalized" "$provider_policy" \
	"policy.2 = kind=sdk context=target consumer_group=target opsys=darwin arch=arm64 origin=devel/libffi identity=macos-sdk state=valid"
if run_make "DEPENDENCY_PROVIDER_POLICIES=$valid_provider_policy" \
	dependency-provider-policy-check >/dev/null 2>&1; then
	pass "valid provider policy passes validation"
else
	fail "valid provider policy passes validation" \
		"dependency-provider-policy-check failed"
fi

invalid_provider_policy='sdk@build@target@darwin@arm64@devel/libffi@macos-sdk system@target@missing@linux@amd64@devel/ncurses@linux-base system@target@target@linux@amd64@devel/ncurses@linux-one sdk@target@target@linux@amd64@devel/ncurses@linux-two malformed'
if invalid_provider_policy_output=$(run_make \
	"DEPENDENCY_PROVIDER_POLICIES=$invalid_provider_policy" \
	dependency-provider-policy-check 2>&1); then
	fail "invalid provider policy fails validation" \
		"invalid policy was accepted"
else
	pass "invalid provider policy fails validation"
fi
assert_contains "SDK build context is rejected" \
	"$invalid_provider_policy_output" "state=sdk-requires-target-context"
assert_contains "unknown provider consumer group is rejected" \
	"$invalid_provider_policy_output" "state=unknown-consumer-group"
assert_contains "duplicate provider selection key is rejected" \
	"$invalid_provider_policy_output" "state=duplicate-selection-key"
assert_contains "malformed provider policy is rejected" \
	"$invalid_provider_policy_output" "raw=malformed state=invalid-field-count"

resolved_provider_args="--eval=dependency_capabilities_host_pkg-config := devel/autoconf devel/automake archivers/zlib"

host_discovery_selection=$(run_make "$resolved_provider_args" \
	$discovery_registry_args \
	"DEPENDENCY_PROVIDER_PKG_CONFIG=$fake_pkg_config" \
	"DEPENDENCY_PROVIDER_CC=$fake_cc" \
	DEPENDENCY_PROVIDER_MODE=host dependency-provider-selection-list)
assert_contains "host mode projects discovered provider into selection" \
	"$host_discovery_selection" \
	"origin=devel/autoconf provider_kind=system provider_identity=linux-pkg-config-x86_64 resolution=selected state=validated"

macos_discovery_selection=$(run_make "$resolved_provider_args" \
	$discovery_registry_args \
	"DEPENDENCY_PROVIDER_PKG_CONFIG=$fake_pkg_config" \
	"DEPENDENCY_PROVIDER_CC=$fake_cc" \
	DEPENDENCY_BUILD_OPSYS=darwin DEPENDENCY_BUILD_ARCH=arm64 \
	DEPENDENCY_PROVIDER_MODE=host dependency-provider-selection-list)
assert_contains "macOS profile gives discovery a platform identity" \
	"$macos_discovery_selection" \
	"origin=devel/autoconf provider_kind=system provider_identity=macos-pkg-config-arm64 resolution=selected state=validated"

host_discovery_fallback=$(run_make "$resolved_provider_args" \
	$discovery_registry_args \
	"DEPENDENCY_PROVIDER_PKG_CONFIG=$missing_pkg_config" \
	"DEPENDENCY_PROVIDER_CC=$fake_cc" \
	DEPENDENCY_PROVIDER_MODE=host dependency-provider-selection-list)
assert_contains "host mode falls back when discovery is unavailable" \
	"$host_discovery_fallback" \
	"origin=devel/autoconf provider_kind=uports provider_identity=host_pkg-config resolution=selected state=selected"

rm -rf "$discovery_test_dir"

if run_make "$resolved_provider_args" DEPENDENCY_PROVIDER_MODE=system-only \
	info.debug.dependencies >/dev/null 2>&1; then
	fail "system-only mode rejects uports fallback" \
		"uports dependencies were accepted"
else
	pass "system-only mode rejects uports fallback"
fi

provider_selection=$(run_make "$resolved_provider_args" \
	dependency-provider-selection-list)
assert_contains "uports provider selection remains the default" \
	"$provider_selection" \
	"origin=devel/autoconf provider_kind=uports provider_identity=host_pkg-config resolution=selected state=selected"
assert_contains "resolved provider selection has no invalid records" \
	"$provider_selection" "dependency_provider_selection_invalid = 0"

system_selection=$(run_make "$resolved_provider_args" \
	'DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base' \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=true' \
	dependency-provider-selection-list)
assert_contains "validated system provider replaces uports selection" \
	"$system_selection" \
	"origin=devel/autoconf provider_kind=system provider_identity=linux-base resolution=selected state=validated"

missing_validator_selection=$(run_make "$resolved_provider_args" \
	'DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base' \
	dependency-provider-selection-list)
assert_contains "explicit provider without validator fails closed" \
	"$missing_validator_selection" \
	"provider_kind=system provider_identity=linux-base resolution=invalid-provider state=validator-missing"

failed_validator_selection=$(run_make "$resolved_provider_args" \
	'DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base' \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=false' \
	dependency-provider-selection-list)
assert_contains "failed explicit provider validation is visible" \
	"$failed_validator_selection" \
	"provider_kind=system provider_identity=linux-base resolution=invalid-provider state=validation-failed"

if run_make "$resolved_provider_args" \
	'DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base' \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=false' \
	dependency-provider-selection-check >/dev/null 2>&1; then
	fail "invalid explicit provider fails selection check" \
		"failed validator was accepted"
else
	pass "invalid explicit provider fails selection check"
fi

platform_mismatch_selection=$(run_make "$resolved_provider_args" \
	'DEPENDENCY_PROVIDER_POLICIES=system@build@target@darwin@arm64@devel/autoconf@macos-base' \
	'DEPENDENCY_PROVIDER_CHECK.macos-base.devel_autoconf=true' \
	dependency-provider-selection-list)
assert_contains "nonmatching platform policy does not replace uports" \
	"$platform_mismatch_selection" \
	"origin=devel/autoconf provider_kind=uports provider_identity=host_pkg-config resolution=selected state=selected"

readiness_policy='DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base'
ready_provider=$(run_make "$resolved_provider_args" "$readiness_policy" \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=true' \
	'DEPENDENCY_PROVIDER_READY_HEADER.linux-base.devel_autoconf=true' \
	'DEPENDENCY_PROVIDER_READY_LIBRARY.linux-base.devel_autoconf=true' \
	dependency-provider-readiness-check)
assert_contains "readiness reports passing named checks" "$ready_provider" \
	"header=ready library=ready metadata=unspecified tool=unspecified state=ready"
assert_contains "readiness check counts matching dependencies" "$ready_provider" \
	"dependency_provider_readiness_invalid = 0"

missing_provider=$(run_make "$resolved_provider_args" "$readiness_policy" \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=false' \
	'DEPENDENCY_PROVIDER_READY_HEADER.linux-base.devel_autoconf=false' \
	'DEPENDENCY_PROVIDER_READY_LIBRARY.linux-base.devel_autoconf=true' \
	dependency-provider-readiness-list)
assert_contains "readiness names a missing header check" "$missing_provider" \
	"header=missing library=ready metadata=unspecified tool=unspecified state=validation-failed"
if run_make "$resolved_provider_args" "$readiness_policy" \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=false' \
	'DEPENDENCY_PROVIDER_READY_HEADER.linux-base.devel_autoconf=false' \
	dependency-provider-readiness-check >/dev/null 2>&1; then
	fail "readiness check fails for missing provider" "failed validator was accepted"
else
	pass "readiness check fails for missing provider"
fi

probe_disagrees=$(run_make "$resolved_provider_args" "$readiness_policy" \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=true' \
	'DEPENDENCY_PROVIDER_READY_METADATA.linux-base.devel_autoconf=false' \
	dependency-provider-readiness-list)
assert_contains "readiness exposes failed named probe despite passing validator" \
	"$probe_disagrees" "metadata=missing tool=unspecified state=probe-failed"

sdk_selection=$(run_make "$resolved_provider_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@linux@arm64@archivers/zlib@target-sdk' \
	'DEPENDENCY_PROVIDER_CHECK.target-sdk.archivers_zlib=true' \
	dependency-provider-selection-list)
assert_contains "group target platform selects validated SDK" \
	"$sdk_selection" \
	"consumer=target_openssl context=target opsys=linux arch=arm64 type=lib requirement=libz.so origin=archivers/zlib provider_kind=sdk provider_identity=target-sdk resolution=selected state=validated"

global_cross_selection=$(run_make "$resolved_provider_args" \
	'CROSS_COMPILE=arm64-unknown-linux-gnu' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@linux@arm64@archivers/zlib@target-sdk' \
	'DEPENDENCY_PROVIDER_CHECK.target-sdk.archivers_zlib=true' \
	dependency-provider-selection-list)
assert_contains "global CROSS_COMPILE defines target provider context" \
	"$global_cross_selection" \
	"consumer=target_openssl context=target opsys=linux arch=arm64"

cross_system_selection=$(run_make "$resolved_provider_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	'DEPENDENCY_PROVIDER_POLICIES=system@target@target@linux@arm64@archivers/zlib@linux-base' \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.archivers_zlib=true' \
	dependency-provider-selection-list)
assert_contains "cross target rejects system provider" \
	"$cross_system_selection" \
	"provider_kind=system provider_identity=linux-base resolution=invalid-provider state=system-cross-provider"

native_system_selection=$(run_make "$resolved_provider_args" \
	--eval='override dependency3_type := lib' \
	'DEPENDENCY_PROVIDER_POLICIES=system@target@target@linux@x86_64@devel/autoconf@linux-base' \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=true' \
	dependency-provider-selection-list)
assert_contains "native target accepts validated system provider" \
	"$native_system_selection" \
	"provider_kind=system provider_identity=linux-base resolution=selected state=validated"

if run_make "$resolved_provider_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	'DEPENDENCY_TARGET_ARCH.target=x86_64' \
	dependency-provider-selection-list >/dev/null 2>&1; then
	fail "explicit target override must match CROSS_COMPILE" \
		"inconsistent target architecture was accepted"
else
	pass "explicit target override must match CROSS_COMPILE"
fi

if run_make "$resolved_provider_args" \
	'PORTS_target_libffi_EXTRA_ENVS=WITH_TESTS=yes CROSS_COMPILE=arm64-unknown-linux-gnu' \
	dependency-provider-selection-list >/dev/null 2>&1; then
	fail "consumer group rejects mixed native and cross instances" \
		"mixed CROSS_COMPILE values were accepted"
else
	pass "consumer group rejects mixed native and cross instances"
fi

toolchain_test_dir=$(mktemp -d "$testdir/work/cross-toolchain.XXXXXX")
for tool in gcc g++ ld as ar nm objdump ranlib strip; do
	command="$toolchain_test_dir/test-cross-linux-gnu-$tool"
	printf '%s\n' '#!/bin/sh' 'exit 0' > "$command"
	chmod +x "$command"
done
toolchain_list=$(run_make \
	"PATH=$toolchain_test_dir:$PATH" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=test-cross-linux-gnu' \
	dependency-cross-toolchain-list)
assert_contains "cross toolchain diagnostic derives prefixed command" \
	"$toolchain_list" \
	"toolchain.target.gcc = command=test-cross-linux-gnu-gcc path=$toolchain_test_dir/test-cross-linux-gnu-gcc state=ready"
assert_contains "complete cross toolchain is ready" "$toolchain_list" \
	"dependency_cross_toolchain_missing = 0"
if run_make "PATH=$toolchain_test_dir:$PATH" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=test-cross-linux-gnu' \
	dependency-cross-toolchain-check >/dev/null 2>&1; then
	pass "complete cross toolchain passes readiness check"
else
	fail "complete cross toolchain passes readiness check" \
		"synthetic tools were rejected"
fi

rm -f "$toolchain_test_dir/test-cross-linux-gnu-strip"
missing_toolchain=$(run_make \
	"PATH=$toolchain_test_dir:$PATH" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=test-cross-linux-gnu' \
	dependency-cross-toolchain-list)
assert_contains "incomplete cross toolchain identifies missing command" \
	"$missing_toolchain" \
	"toolchain.target.strip = command=test-cross-linux-gnu-strip path=none state=missing"
if missing_toolchain_execution=$(run_make "$resolved_provider_args" \
	"PATH=$toolchain_test_dir:$PATH" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=test-cross-linux-gnu' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-lifecycle-execute 2>&1); then
	fail "missing cross tool blocks dependency execution" \
		"execution accepted incomplete toolchain"
else
	pass "missing cross tool blocks dependency execution"
fi
assert_contains "cross execution failure names missing tool" \
	"$missing_toolchain_execution" \
	"cross toolchain missing: group=target command=test-cross-linux-gnu-strip"
assert_not_contains "cross toolchain preflight dispatches no provider" \
	"$missing_toolchain_execution" "host@pkg-config.install"
rm -rf "$toolchain_test_dir"

system_environment=$(run_make "$resolved_provider_args" \
	'DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base' \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=true' \
	'DEPENDENCY_PROVIDER_BINDIRS.linux-base.devel_autoconf=/usr/bin /opt/tools/bin /usr/bin' \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/usr/include' \
	'DEPENDENCY_PROVIDER_LIBDIRS.linux-base.devel_autoconf=/usr/lib' \
	'DEPENDENCY_PROVIDER_PKGCONFIGDIRS.linux-base.devel_autoconf=/usr/lib/pkgconfig' \
	'DEPENDENCY_PROVIDER_RUNTIMEDIRS.linux-base.devel_autoconf=/usr/lib' \
	dependency-provider-environment-list)
assert_contains "system provider paths are normalized and deduplicated" \
	"$system_environment" \
	"environment.target_libffi = bindirs=/usr/bin:/opt/tools/bin includedirs=/usr/include libdirs=/usr/lib pkgconfigdirs=/usr/lib/pkgconfig runtimedirs=/usr/lib runtime_variable=LD_LIBRARY_PATH sysroot=none state=valid"
assert_contains "valid system provider environment passes" \
	"$system_environment" "dependency_provider_environment_invalid = 0"

missing_sdk_environment=$(run_make "$resolved_provider_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@linux@arm64@archivers/zlib@target-sdk' \
	'DEPENDENCY_PROVIDER_CHECK.target-sdk.archivers_zlib=true' \
	dependency-provider-environment-list)
assert_contains "SDK provider without sysroot fails closed" \
	"$missing_sdk_environment" "state=sdk-sysroot-missing"
if run_make "$resolved_provider_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@linux@arm64@archivers/zlib@target-sdk' \
	'DEPENDENCY_PROVIDER_CHECK.target-sdk.archivers_zlib=true' \
	dependency-provider-environment-check >/dev/null 2>&1; then
	fail "missing SDK sysroot fails environment check" \
		"SDK without sysroot was accepted"
else
	pass "missing SDK sysroot fails environment check"
fi

sdk_environment=$(run_make "$resolved_provider_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-apple-darwin' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@darwin@arm64@archivers/zlib@macos-sdk' \
	'DEPENDENCY_PROVIDER_CHECK.macos-sdk.archivers_zlib=true' \
	'DEPENDENCY_PROVIDER_SYSROOT.macos-sdk.archivers_zlib=/SDKs/MacOSX.sdk' \
	'DEPENDENCY_PROVIDER_LIBDIRS.macos-sdk.archivers_zlib=/SDKs/MacOSX.sdk/usr/lib' \
	'DEPENDENCY_PROVIDER_RUNTIMEDIRS.macos-sdk.archivers_zlib=/SDKs/MacOSX.sdk/usr/lib' \
	dependency-provider-environment-list)
assert_contains "SDK environment records sysroot and Darwin runtime variable" \
	"$sdk_environment" \
	"libdirs=/SDKs/MacOSX.sdk/usr/lib pkgconfigdirs=none runtimedirs=/SDKs/MacOSX.sdk/usr/lib runtime_variable=DYLD_LIBRARY_PATH sysroot=/SDKs/MacOSX.sdk state=valid"

external_record_args='DEPENDENCY_EXTERNAL_PROVIDERS=yes'
external_policy='DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base'
external_validator='DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=true'
external_records=$(run_make "$resolved_provider_args" "$external_record_args" \
	"$external_policy" "$external_validator" info.debug.dependencies)
assert_contains "external provider replaces normalized record" \
	"$external_records" \
	"origin=devel/autoconf provider_kind=system provider_instance=none resolution=selected provider_identity=linux-base"

external_unknown_record=$(run_make "$external_record_args" \
	"$external_policy" "$external_validator" info.debug.dependencies)
assert_contains "explicit external provider resolves otherwise unknown origin" \
	"$external_unknown_record" \
	"origin=devel/autoconf provider_kind=system provider_instance=none resolution=selected provider_identity=linux-base"

opt_in_without_policy=$(run_make "$resolved_provider_args" \
	"$external_record_args" info.debug.dependencies)
assert_contains "opt-in without policy preserves uports selection" \
	"$opt_in_without_policy" \
	"origin=devel/autoconf provider_kind=uports provider_instance=host_pkg-config resolution=selected"

external_graph=$(run_make "$resolved_provider_args" "$external_record_args" \
	"$external_policy" "$external_validator" info.debug.dependency-graph)
assert_contains "external provider removes uports graph edge" \
	"$external_graph" "dependency_graph_edges = 3"
assert_not_contains "external provider has no uports graph edge" \
	"$external_graph" "edge.dependency3 ="

external_plan=$(run_make "$resolved_provider_args" "$external_record_args" \
	"$external_policy" "$external_validator" \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-execution-plan)
assert_contains "external provider is omitted from uports execution targets" \
	"$external_plan" "dependency_execution_targets = host@pkg-config.install"

external_state=$(run_make "$resolved_provider_args" "$external_record_args" \
	"$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/host/include' \
	DEPENDENCY_REQUEST=target@libffi.build dependency-execution-state)
assert_contains "external provider identity enters consumer state" \
	"$external_state" \
	"dependency|target_libffi|build|autoconf>=2.69|devel/autoconf|system|linux-base|external"
assert_contains "external provider environment enters consumer state" \
	"$external_state" \
	"external-environment|target_libffi|linux-base|devel/autoconf|build|linux|x86_64||/opt/host/include"

external_state_changed=$(run_make "$resolved_provider_args" "$external_record_args" \
	"$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/other/include' \
	DEPENDENCY_REQUEST=target@libffi.build dependency-execution-state)
if [ "$external_state" != "$external_state_changed" ]; then
	pass "external provider path change alters consumer state"
else
	fail "external provider path change alters consumer state" \
		"changed include path was not reflected"
fi

uports_provenance=$(run_make "$resolved_provider_args" \
	DEPENDENCY_REQUEST=target@libffi.package dependency-provider-provenance)
assert_contains "provenance identifies its schema and request" \
	"$uports_provenance" "provenance|1
request|target_libffi|package"
assert_contains "provenance records selected uports provider identity" \
	"$uports_provenance" \
	"provider|target_libffi|build|autoconf>=2.69|devel/autoconf|uports|host_pkg-config|build|linux|x86_64|host@pkg-config.install"

external_provenance=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	DEPENDENCY_REQUEST=target@libffi.package dependency-provider-provenance)
assert_contains "provenance records external provider identity and platform" \
	"$external_provenance" \
	"provider|target_libffi|build|autoconf>=2.69|devel/autoconf|system|linux-base|build|linux|x86_64|external"
assert_contains "external provenance retains remaining uports providers" \
	"$external_provenance" \
	"provider|target_libffi|build|automake>=1.16.1|devel/automake|uports|host_pkg-config|build|linux|x86_64|host@pkg-config.install"
assert_eq "provider provenance is deterministic" \
	"$(run_make "$resolved_provider_args" "$external_record_args" \
	  "$external_policy" "$external_validator" \
	  DEPENDENCY_REQUEST=target@libffi.package dependency-provider-provenance)" \
	"$external_provenance"

package_test_dir=$(mktemp -d "$testdir/work/package-provenance.XXXXXX")
mkdir -p "$package_test_dir/stage/usr/local" "$package_test_dir/pkg" \
	"$package_test_dir/install"
printf '%s\n' payload > "$package_test_dir/stage/usr/local/payload.txt"
printf '%s\n' payload.txt > "$package_test_dir/plist"
printf '%s\n' "$external_provenance" > "$package_test_dir/provenance"
package_file="$package_test_dir/pkg/test.pkg"
STAGEDIR="$package_test_dir/stage" PKGNAME=test VERSION=1 ORIGIN=test/test \
	PREFIX=/usr/local INDEX=test COMPRESS=XZ EXT=linux \
	PLIST="$package_test_dir/plist" \
	PROVENANCE="$package_test_dir/provenance" \
	WRKDIR_PKGFILE="$package_file" \
	"$portdir/Mk/Scripts/pkg.sh" create
assert_eq "package with provenance uses format version two" \
	"$(sed -n '1p' "$package_file")" "PVER: 2"
assert_contains "package embeds deterministic provider provenance" \
	"$(sed -n '1,/^%%%%%-PROVENANCE$/p' "$package_file")" \
	"provider|target_libffi|build|autoconf>=2.69|devel/autoconf|system|linux-base|build|linux|x86_64|external"
DESTDIR="$package_test_dir/install" \
	"$portdir/Mk/Scripts/pkg.sh" add -q "$package_file"
assert_eq "version-two package remains installable" \
	"$(cat "$package_test_dir/install/usr/local/payload.txt")" "payload"

legacy_package_file="$package_test_dir/pkg/legacy.pkg"
STAGEDIR="$package_test_dir/stage" PKGNAME=legacy VERSION=1 \
	ORIGIN=test/legacy PREFIX=/usr/local INDEX=test COMPRESS=XZ EXT=linux \
	PLIST="$package_test_dir/plist" WRKDIR_PKGFILE="$legacy_package_file" \
	"$portdir/Mk/Scripts/pkg.sh" create
assert_eq "dependency-neutral package retains legacy format" \
	"$(sed -n '1p' "$legacy_package_file")" "PVER: 1"
mkdir -p "$package_test_dir/install-legacy"
DESTDIR="$package_test_dir/install-legacy" \
	"$portdir/Mk/Scripts/pkg.sh" add -q "$legacy_package_file"
assert_eq "legacy package remains installable" \
	"$(cat "$package_test_dir/install-legacy/usr/local/payload.txt")" "payload"
rm -rf "$package_test_dir"

external_execution=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	DEPENDENCY_REQUEST=target@libffi.build dependency-lifecycle-execute)
assert_eq "external provider dispatches only remaining uports targets" \
	"$external_execution" "host@pkg-config.install"

if external_invalid_environment=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=relative/include' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-lifecycle-execute 2>&1); then
	fail "invalid external environment blocks provider dispatch" \
		"provider execution accepted invalid include path"
else
	pass "invalid external environment blocks provider dispatch"
fi
assert_contains "external preflight reports invalid path" \
	"$external_invalid_environment" "state=invalid-path"
assert_not_contains "external preflight dispatches no uports provider" \
	"$external_invalid_environment" "host@pkg-config.install"

if invalid_external=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" \
	'DEPENDENCY_PROVIDER_CHECK.linux-base.devel_autoconf=false' \
	info.debug.dependencies 2>&1); then
	fail "invalid external provider cannot alter records" \
		"failed external validator was accepted"
else
	pass "invalid external provider cannot alter records"
fi
assert_contains "invalid external provider is explicit" \
	"$invalid_external" "dependency provider validation failed"

environment_export=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_BINDIRS.linux-base.devel_autoconf=/opt/host/bin' \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/host/include' \
	'DEPENDENCY_PROVIDER_LIBDIRS.linux-base.devel_autoconf=/opt/host/lib' \
	'DEPENDENCY_PROVIDER_PKGCONFIGDIRS.linux-base.devel_autoconf=/opt/host/lib/pkgconfig' \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-provider-environment-export)
assert_contains "external provider exports build tool path" \
	"$environment_export" "PATH='/opt/host/bin':"
assert_contains "external provider exports include flags" \
	"$environment_export" "CPPFLAGS='-I/opt/host/include'"
assert_contains "external provider exports linker flags" \
	"$environment_export" "LDFLAGS='-L/opt/host/lib'"
assert_contains "external provider exports pkg-config path" \
	"$environment_export" "PKG_CONFIG_PATH='/opt/host/lib/pkgconfig'"
if sh -uc "unset CPPFLAGS LDFLAGS PKG_CONFIG_PATH; $environment_export"; then
	pass "provider exports tolerate unset base variables"
else
	fail "provider exports tolerate unset base variables" \
		"export failed under shell nounset mode"
fi

if run_make "$resolved_provider_args" "$external_policy" \
	"$external_validator" DEPENDENCY_REQUEST=target@libffi.build \
	dependency-provider-environment-export >/dev/null 2>&1; then
	fail "provider export requires explicit opt-in" \
		"export accepted without DEPENDENCY_EXTERNAL_PROVIDERS=yes"
else
	pass "provider export requires explicit opt-in"
fi

environment_run=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/host/include' \
	'CPPFLAGS=-DKEEP' \
	DEPENDENCY_REQUEST=target@libffi.build \
	'DEPENDENCY_ENVIRONMENT_COMMAND=env' \
	dependency-provider-environment-run)
assert_contains "explicit runner injects consumer environment" \
	"$environment_run" "CPPFLAGS=-I/opt/host/include -DKEEP"

runtime_provider_args='DEPENDENCY_PROVIDER_POLICIES=system@target@target@linux@x86_64@devel/autoconf@linux-base'
runtime_build_export=$(run_make "$resolved_provider_args" \
	--eval='override dependency3_type := run' \
	"$external_record_args" "$runtime_provider_args" "$external_validator" \
	'DEPENDENCY_PROVIDER_RUNTIMEDIRS.linux-base.devel_autoconf=/opt/host/lib' \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-provider-environment-export)
assert_eq "build request excludes runtime-only provider environment" \
	"$runtime_build_export" ""
runtime_stage_export=$(run_make "$resolved_provider_args" \
	--eval='override dependency3_type := run' \
	"$external_record_args" "$runtime_provider_args" "$external_validator" \
	'DEPENDENCY_PROVIDER_RUNTIMEDIRS.linux-base.devel_autoconf=/opt/host/lib' \
	DEPENDENCY_REQUEST=target@libffi.stage \
	dependency-provider-environment-export)
assert_contains "stage request includes native runtime path" \
	"$runtime_stage_export" "LD_LIBRARY_PATH='/opt/host/lib'"

cross_environment_export=$(run_make "$resolved_provider_args" \
	"$external_record_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-apple-darwin' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@darwin@arm64@archivers/zlib@macos-sdk' \
	'DEPENDENCY_PROVIDER_CHECK.macos-sdk.archivers_zlib=true' \
	'DEPENDENCY_PROVIDER_SYSROOT.macos-sdk.archivers_zlib=/SDKs/MacOSX.sdk' \
	'DEPENDENCY_PROVIDER_RUNTIMEDIRS.macos-sdk.archivers_zlib=/SDKs/MacOSX.sdk/usr/lib' \
	DEPENDENCY_REQUEST=target@openssl.build \
	dependency-provider-environment-export)
assert_contains "cross SDK exports explicit sysroot" \
	"$cross_environment_export" "SDKROOT='/SDKs/MacOSX.sdk'"
assert_contains "external-only library suppresses uports library paths" \
	"$cross_environment_export" \
	"UPORTS_LIB_DEPENDS_USES_UPORTS=no"
assert_contains "cross target runtime path stays out of host loader" \
	"$cross_environment_export" \
	"UPORTS_TARGET_RUNTIME_DIRS='/SDKs/MacOSX.sdk/usr/lib'"
assert_not_contains "cross SDK does not set host loader path" \
	"$cross_environment_export" "DYLD_LIBRARY_PATH="

sdk_test_dir=$(mktemp -d "$testdir/work/sdk-environment.XXXXXX")
sdk_sysroot="$sdk_test_dir/sysroot"
mkdir -p "$sdk_sysroot/usr/include" "$sdk_sysroot/usr/lib/pkgconfig"
sdk_policy='DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@linux@arm64@archivers/zlib@test-sdk'
sdk_validator="DEPENDENCY_PROVIDER_CHECK.test-sdk.archivers_zlib=test -d $sdk_sysroot/usr/include -a -d $sdk_sysroot/usr/lib"
sdk_args="DEPENDENCY_PROVIDER_SYSROOT.test-sdk.archivers_zlib=$sdk_sysroot"
sdk_include="DEPENDENCY_PROVIDER_INCLUDEDIRS.test-sdk.archivers_zlib=$sdk_sysroot/usr/include"
sdk_library="DEPENDENCY_PROVIDER_LIBDIRS.test-sdk.archivers_zlib=$sdk_sysroot/usr/lib"
sdk_pkgconfig="DEPENDENCY_PROVIDER_PKGCONFIGDIRS.test-sdk.archivers_zlib=$sdk_sysroot/usr/lib/pkgconfig"
sdk_environment_run=$(run_make "$resolved_provider_args" \
	"$external_record_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	"$sdk_policy" "$sdk_validator" "$sdk_args" "$sdk_include" \
	"$sdk_library" "$sdk_pkgconfig" \
	DEPENDENCY_REQUEST=target@openssl.build \
	'DEPENDENCY_ENVIRONMENT_COMMAND=env' \
	dependency-provider-environment-run)
assert_contains "SDK runner exports compiler sysroot flags" \
	"$sdk_environment_run" \
	"CFLAGS=--sysroot=$sdk_sysroot -I$sdk_sysroot/usr/include"
assert_contains "SDK runner exports C++ sysroot flags" \
	"$sdk_environment_run" \
	"CXXFLAGS=--sysroot=$sdk_sysroot -I$sdk_sysroot/usr/include"
assert_contains "SDK runner exports preprocessor sysroot flags" \
	"$sdk_environment_run" \
	"CPPFLAGS=--sysroot=$sdk_sysroot -I$sdk_sysroot/usr/include"
assert_contains "SDK runner exports linker sysroot flags" \
	"$sdk_environment_run" \
	"LDFLAGS=-L$sdk_sysroot/usr/lib --sysroot=$sdk_sysroot"
assert_contains "SDK runner exports pkg-config sysroot" \
	"$sdk_environment_run" "PKG_CONFIG_SYSROOT_DIR=$sdk_sysroot"
assert_contains "SDK runner exports pkg-config search path" \
	"$sdk_environment_run" \
	"PKG_CONFIG_PATH=$sdk_sysroot/usr/lib/pkgconfig"

sdk_state=$(run_make "$resolved_provider_args" "$external_record_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	"$sdk_policy" "$sdk_validator" "$sdk_args" "$sdk_include" \
	"$sdk_library" "$sdk_pkgconfig" \
	DEPENDENCY_REQUEST=target@openssl.build dependency-execution-state)
assert_contains "SDK identity and sysroot enter dependency state" "$sdk_state" \
	"external-environment|target_openssl|test-sdk|archivers/zlib|target|linux|arm64||$sdk_sysroot/usr/include|$sdk_sysroot/usr/lib|$sdk_sysroot/usr/lib/pkgconfig||$sdk_sysroot"
sdk_provenance=$(run_make "$resolved_provider_args" "$external_record_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-unknown-linux-gnu' \
	"$sdk_policy" "$sdk_validator" "$sdk_args" \
	DEPENDENCY_REQUEST=target@openssl.package dependency-provider-provenance)
assert_contains "SDK identity and platform enter provider provenance" \
	"$sdk_provenance" \
	"provider|target_openssl|lib|libz.so|archivers/zlib|sdk|test-sdk|target|linux|arm64|external"

conflicting_sdk=$(run_make "$resolved_provider_args" \
	--eval='override dependency3_type := lib' \
	--eval='override dependency4_type := lib' \
	"$external_record_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-apple-darwin' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@darwin@arm64@devel/autoconf@sdk-one sdk@target@target@darwin@arm64@devel/automake@sdk-two' \
	'DEPENDENCY_PROVIDER_CHECK.sdk-one.devel_autoconf=true' \
	'DEPENDENCY_PROVIDER_CHECK.sdk-two.devel_automake=true' \
	"DEPENDENCY_PROVIDER_SYSROOT.sdk-one.devel_autoconf=$sdk_test_dir/sdk-one" \
	"DEPENDENCY_PROVIDER_SYSROOT.sdk-two.devel_automake=$sdk_test_dir/sdk-two" \
	dependency-provider-environment-list)
assert_contains "conflicting SDK sysroots are explicit" "$conflicting_sdk" \
	"state=conflicting-sysroots"
if run_make "$resolved_provider_args" \
	--eval='override dependency3_type := lib' \
	--eval='override dependency4_type := lib' \
	"$external_record_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-apple-darwin' \
	'DEPENDENCY_PROVIDER_POLICIES=sdk@target@target@darwin@arm64@devel/autoconf@sdk-one sdk@target@target@darwin@arm64@devel/automake@sdk-two' \
	'DEPENDENCY_PROVIDER_CHECK.sdk-one.devel_autoconf=true' \
	'DEPENDENCY_PROVIDER_CHECK.sdk-two.devel_automake=true' \
	"DEPENDENCY_PROVIDER_SYSROOT.sdk-one.devel_autoconf=$sdk_test_dir/sdk-one" \
	"DEPENDENCY_PROVIDER_SYSROOT.sdk-two.devel_automake=$sdk_test_dir/sdk-two" \
	dependency-provider-environment-check >/dev/null 2>&1; then
	fail "conflicting SDK sysroots fail preflight" \
		"conflicting sysroots were accepted"
else
	pass "conflicting SDK sysroots fail preflight"
fi
rm -rf "$sdk_test_dir"

mixed_context_export=$(run_make "$resolved_provider_args" \
	--eval='override dependency4_type := lib' \
	"$external_record_args" \
	'TEST_TARGET_ENVS=CROSS_COMPILE=arm64-apple-darwin' \
	'DEPENDENCY_PROVIDER_POLICIES=system@build@target@linux@x86_64@devel/autoconf@linux-base sdk@target@target@darwin@arm64@devel/automake@macos-sdk' \
	"$external_validator" \
	'DEPENDENCY_PROVIDER_CHECK.macos-sdk.devel_automake=true' \
	'DEPENDENCY_PROVIDER_SYSROOT.macos-sdk.devel_automake=/SDKs/MacOSX.sdk' \
	'DEPENDENCY_PROVIDER_RUNTIMEDIRS.macos-sdk.devel_automake=/SDKs/MacOSX.sdk/usr/lib' \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-provider-environment-export)
assert_contains "mixed host tool and cross SDK retain target runtime identity" \
	"$mixed_context_export" \
	"UPORTS_TARGET_RUNTIME_DIRS='/SDKs/MacOSX.sdk/usr/lib'"
assert_not_contains "mixed contexts never put target library on host loader" \
	"$mixed_context_export" "LD_LIBRARY_PATH="

mixed_library_export=$(run_make "$resolved_provider_args" \
	--eval='override dependency3_type := lib' \
	--eval='override dependency4_type := lib' \
	"$external_record_args" "$runtime_provider_args" "$external_validator" \
	DEPENDENCY_REQUEST=target@libffi.build \
	dependency-provider-environment-export)
assert_not_contains "mixed library providers retain uports search paths" \
	"$mixed_library_export" "UPORTS_LIB_DEPENDS_USES_UPORTS=no"

port_library_probe='probe: ; @printf "%s\n" "CFLAGS=$(CFLAGS)" "LDFLAGS=$(LDFLAGS)"'
default_library_paths=$(make --no-print-directory -s -C \
	"$feeds/security/openssl" PORTSDIR="$portdir" \
	DESTDIR="$testdir/work/external-prefix" PREFIX=/usr/local \
	--eval="$port_library_probe" probe)
assert_contains "default library dependencies retain uports include path" \
	"$default_library_paths" \
	"$testdir/work/external-prefix/usr/local/include"
external_library_paths=$(make --no-print-directory -s -C \
	"$feeds/security/openssl" PORTSDIR="$portdir" \
	DESTDIR="$testdir/work/external-prefix" PREFIX=/usr/local \
	UPORTS_LIB_DEPENDS_USES_UPORTS=no \
	--eval="$port_library_probe" probe)
assert_not_contains "external-only library omits uports include path" \
	"$external_library_paths" \
	"$testdir/work/external-prefix/usr/local/include"
assert_not_contains "external-only library omits uports linker path" \
	"$external_library_paths" \
	"$testdir/work/external-prefix/usr/local/lib"

if invalid_environment_run=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=relative/include' \
	DEPENDENCY_REQUEST=target@libffi.build \
	'DEPENDENCY_ENVIRONMENT_COMMAND=printf SHOULD-NOT-RUN' \
	dependency-provider-environment-run 2>&1); then
	fail "invalid provider path blocks explicit runner" \
		"relative path was accepted"
else
	pass "invalid provider path blocks explicit runner"
fi
assert_contains "invalid provider path is explicit" \
	"$invalid_environment_run" "invalid external provider environment"
assert_not_contains "invalid path never invokes consumer command" \
	"$invalid_environment_run" "SHOULD-NOT-RUN"

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
	"$dependency_execution_state" "request|target_libffi|configure"
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
dependency_state_inode=$(ls -di "$dependency_state_saved" | awk '{ print $1 }')
dependency_state_resave=$(DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	"$portdir/Mk/Scripts/dependency-state.sh" save)
assert_contains "unchanged dependency state save is reported" \
	"$dependency_state_resave" "dependency_state = unchanged"
assert_eq "unchanged dependency state is not rewritten" \
	"$(ls -di "$dependency_state_saved" | awk '{ print $1 }')" \
	"$dependency_state_inode"
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

dependency_cookie_fixture="$dependency_state_fixture/cookies"
mkdir -p "$dependency_cookie_fixture"
for cookie in extract configure build stage package install
do
	touch "$dependency_cookie_fixture/$cookie"
done
port_state_unchanged=$(make --no-print-directory -s -C \
	"$portdir/archivers/zlib" PORTSDIR="$portdir" \
	DESTDIR="$dependency_state_fixture/root" PREFIX=/usr/local \
	DEPENDENCY_STATE_CLASS=configure \
	DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	CONFIGURE_COOKIE="$dependency_cookie_fixture/configure" \
	BUILD_COOKIE="$dependency_cookie_fixture/build" \
	STAGE_COOKIE="$dependency_cookie_fixture/stage" \
	PACKAGE_COOKIE="$dependency_cookie_fixture/package" \
	INSTALL_COOKIE="$dependency_cookie_fixture/install" \
	uports-dependency-state-invalidate)
assert_contains "unchanged state reports no invalidation" \
	"$port_state_unchanged" "dependency_state = unchanged"
if test -f "$dependency_cookie_fixture/configure" && \
	   test -f "$dependency_cookie_fixture/install"; then
	pass "unchanged state preserves downstream cookies"
else
	fail "unchanged state preserves downstream cookies" \
		"configure or install cookie was removed"
fi

printf '%s\n' 'provider=uports:other-provider:/usr/local' \
	>"$dependency_state_source"
port_state_invalidated=$(make --no-print-directory -s -C \
	"$portdir/archivers/zlib" PORTSDIR="$portdir" \
	DESTDIR="$dependency_state_fixture/root" PREFIX=/usr/local \
	DEPENDENCY_STATE_CLASS=configure \
	DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	CONFIGURE_COOKIE="$dependency_cookie_fixture/configure" \
	BUILD_COOKIE="$dependency_cookie_fixture/build" \
	STAGE_COOKIE="$dependency_cookie_fixture/stage" \
	PACKAGE_COOKIE="$dependency_cookie_fixture/package" \
	INSTALL_COOKIE="$dependency_cookie_fixture/install" \
	uports-dependency-state-invalidate)
assert_contains "changed configure state reports invalidation" \
	"$port_state_invalidated" "dependency_state = changed"
if test ! -f "$dependency_cookie_fixture/configure" && \
	   test ! -f "$dependency_cookie_fixture/build" && \
	   test ! -f "$dependency_cookie_fixture/stage" && \
	   test ! -f "$dependency_cookie_fixture/package" && \
	   test ! -f "$dependency_cookie_fixture/install"; then
	pass "configure state removes configure and downstream cookies"
else
	fail "configure state removes configure and downstream cookies" \
		"one or more downstream cookies remain"
fi
if test -f "$dependency_cookie_fixture/extract"; then
	pass "configure state preserves source cookies"
else
	fail "configure state preserves source cookies" \
		"extract cookie was removed"
fi

for cookie in configure build stage package install
do
	touch "$dependency_cookie_fixture/$cookie"
done
rm -f "$dependency_state_saved"
port_stage_invalidated=$(make --no-print-directory -s -C \
	"$portdir/archivers/zlib" PORTSDIR="$portdir" \
	DESTDIR="$dependency_state_fixture/root" PREFIX=/usr/local \
	DEPENDENCY_STATE_CLASS=stage \
	DEPENDENCY_STATE_SOURCE="$dependency_state_source" \
	DEPENDENCY_STATE_FILE="$dependency_state_saved" \
	STAGE_COOKIE="$dependency_cookie_fixture/stage" \
	PACKAGE_COOKIE="$dependency_cookie_fixture/package" \
	INSTALL_COOKIE="$dependency_cookie_fixture/install" \
	uports-dependency-state-invalidate)
assert_contains "new stage state reports invalidation" \
	"$port_stage_invalidated" "dependency_state = new"
if test ! -f "$dependency_cookie_fixture/stage" && \
	   test ! -f "$dependency_cookie_fixture/package" && \
	   test ! -f "$dependency_cookie_fixture/install"; then
	pass "stage state removes stage and downstream cookies"
else
	fail "stage state removes stage and downstream cookies" \
		"one or more stage cookies remain"
fi
if test -f "$dependency_cookie_fixture/configure" && \
	   test -f "$dependency_cookie_fixture/build"; then
	pass "stage state preserves configure and build cookies"
else
	fail "stage state preserves configure and build cookies" \
		"configure or build cookie was removed"
fi

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

dispatch_state_dir="$testdir/work/dispatch-state"
dispatch_state_file="$dispatch_state_dir/dependency.configure.state"
rm -rf "$dispatch_state_dir"
mkdir -p "$dispatch_state_dir"
dispatch_state_env="WITH_TESTS=yes DEPENDENCY_STATE_FILE=$dispatch_state_file CONFIGURE_COOKIE=$dispatch_state_dir/configure BUILD_COOKIE=$dispatch_state_dir/build STAGE_COOKIE=$dispatch_state_dir/stage PACKAGE_COOKIE=$dispatch_state_dir/package INSTALL_COOKIE=$dispatch_state_dir/install"

external_dispatch_dir=$(mktemp -d "$testdir/work/external-dispatch.XXXXXX")
external_dispatch_file="$external_dispatch_dir/dependency.configure.state"
external_dispatch_env="WITH_TESTS=yes DEPENDENCY_STATE_FILE=$external_dispatch_file CONFIGURE_COOKIE=$external_dispatch_dir/configure BUILD_COOKIE=$external_dispatch_dir/build STAGE_COOKIE=$external_dispatch_dir/stage PACKAGE_COOKIE=$external_dispatch_dir/package INSTALL_COOKIE=$external_dispatch_dir/install"
external_dispatch=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/host/include' \
	"PORTS_target_libffi_EXTRA_ENVS=$external_dispatch_env" \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	UPORTS_DEPENDENCIES=yes target@libffi.build)
assert_eq "external provider dispatch runs remaining uports target first" \
	"$external_dispatch" "host@pkg-config.install
consumer=target@libffi.build"
assert_contains "external provider identity is saved in consumer state" \
	"$(cat "$external_dispatch_file")" \
	"dependency|target_libffi|build|autoconf>=2.69|devel/autoconf|system|linux-base|external"
assert_contains "external provider path is saved in consumer state" \
	"$(cat "$external_dispatch_file")" \
	"external-environment|target_libffi|linux-base|devel/autoconf|build|linux|x86_64||/opt/host/include"

external_unchanged=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/host/include' \
	"PORTS_target_libffi_EXTRA_ENVS=$external_dispatch_env" \
	DEPENDENCY_REQUEST=target@libffi.build dependency-state-check)
assert_contains "unchanged external provider state is recognized" \
	"$external_unchanged" "dependency_state = unchanged"

external_changed=$(run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/other/include' \
	"PORTS_target_libffi_EXTRA_ENVS=$external_dispatch_env" \
	DEPENDENCY_REQUEST=target@libffi.build dependency-state-check)
assert_contains "external provider path change invalidates consumer state" \
	"$external_changed" "dependency_state = changed"

cp "$external_dispatch_file" "$external_dispatch_dir/before-failure"
if run_make "$resolved_provider_args" \
	"$external_record_args" "$external_policy" "$external_validator" \
	'DEPENDENCY_PROVIDER_INCLUDEDIRS.linux-base.devel_autoconf=/opt/other/include' \
	"PORTS_target_libffi_EXTRA_ENVS=$external_dispatch_env" \
	--eval='override cmd_generate-port-target = false' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\\n'" \
	UPORTS_DEPENDENCIES=yes target@libffi.build >/dev/null 2>&1; then
	fail "external consumer failure propagates" \
		"failed consumer command was accepted"
else
	pass "external consumer failure propagates"
fi
if cmp -s "$external_dispatch_dir/before-failure" "$external_dispatch_file"; then
	pass "external consumer failure retains last successful state"
else
	fail "external consumer failure retains last successful state" \
		"failed consumer overwrote state"
fi
rm -rf "$external_dispatch_dir"

dependency_aware_dispatch=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	"PORTS_target_libffi_EXTRA_ENVS=$dispatch_state_env" \
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
if test -f "$dispatch_state_file"; then
	pass "successful canonical dispatch saves dependency state"
else
	fail "successful canonical dispatch saves dependency state" \
		"missing saved state: $dispatch_state_file"
fi

cp "$dispatch_state_file" "$dispatch_state_dir/before-failure"
if run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	"PORTS_target_libffi_EXTRA_ENVS=$dispatch_state_env STATE_REVISION=changed" \
	--eval='override cmd_generate-port-target = false' \
	"DEPENDENCY_EXECUTE_COMMAND=printf '%s\n'" \
	UPORTS_DEPENDENCIES=yes target@libffi.build >/dev/null 2>&1; then
	fail "consumer failure after invalidation is propagated" \
		"failed consumer command was accepted"
else
	pass "consumer failure after invalidation is propagated"
fi
if cmp -s "$dispatch_state_dir/before-failure" "$dispatch_state_file"; then
	pass "consumer failure preserves last successful dependency state"
else
	fail "consumer failure preserves last successful dependency state" \
		"saved dependency state changed after consumer failure"
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

if failed_aggregate_dispatch=$(run_make \
	--eval='dependency_capabilities_host_pkg-config := archivers/zlib' \
	--eval='dependency_capabilities_target_openssl := devel/autoconf devel/automake' \
	--eval='override cmd_generate-port-target = printf "%s\n" "consumer=$(resolved-port-target)"' \
	DEPENDENCY_EXECUTE_COMMAND=false \
	UPORTS_DEPENDENCIES=yes target.build 2>&1); then
	fail "aggregate provider failure is propagated" \
		"failed aggregate provider command was accepted"
else
	pass "aggregate provider failure is propagated"
fi
assert_not_contains "aggregate provider failure blocks consumers" \
	"$failed_aggregate_dispatch" "consumer="

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
