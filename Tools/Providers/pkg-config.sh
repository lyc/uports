#!/bin/sh

set -eu
set -f

pkg_config=${DEPENDENCY_PROVIDER_PKG_CONFIG:-}
cc=${DEPENDENCY_PROVIDER_CC:-}
pkg_config_candidates=${DEPENDENCY_PROVIDER_PKG_CONFIG_CANDIDATES:-pkg-config pkgconf}
cc_candidates=${DEPENDENCY_PROVIDER_CC_CANDIDATES:-cc}
provider_prefixes=${DEPENDENCY_PROVIDER_PREFIXES:-}

find_command()
{
	for candidate do
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return 0
		fi
	done
	return 1
}

safe_path_list()
{
	value=$1
	case "$value" in
		*[!A-Za-z0-9_./+,@:%-]* | .. | ../* | */.. | */../*) return 1 ;;
	esac
	return 0
}

normalize_flags()
{
	prefix=$1
	shift
	result=
	for flag do
		case "$flag" in
			"$prefix"*) path=${flag#"$prefix"} ;;
			*) continue ;;
		esac
		[ -n "$path" ] || continue
		safe_path_list "$path" || return 1
		case ":$result:" in
			*":$path:"*) ;;
			*) result=${result:+$result:}$path ;;
		esac
	done
	printf '%s\n' "${result:-none}"
}

if [ -z "$pkg_config" ]; then
	pkg_config=$(find_command $pkg_config_candidates || :)
fi
if [ -z "$cc" ]; then
	cc=$(find_command $cc_candidates || :)
fi

profile_pkg_config_path=
for prefix in $provider_prefixes; do
	safe_path_list "$prefix" || continue
	for directory in "$prefix/lib/pkgconfig" "$prefix/share/pkgconfig"; do
		[ -d "$directory" ] || continue
		case ":$profile_pkg_config_path:" in
			*":$directory:"*) ;;
			*) profile_pkg_config_path=${profile_pkg_config_path:+$profile_pkg_config_path:}$directory ;;
		esac
	done
done
if [ -n "$profile_pkg_config_path" ]; then
	PKG_CONFIG_PATH=$profile_pkg_config_path${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
	export PKG_CONFIG_PATH
fi

if [ -z "$pkg_config" ] || ! command -v "$pkg_config" >/dev/null 2>&1; then
	pkg_config_available=no
else
	pkg_config_available=yes
fi
if [ -z "$cc" ] || ! command -v "$cc" >/dev/null 2>&1; then
	cc_available=no
else
	cc_available=yes
fi

while IFS='|' read -r record key origin method module header link_name extra; do
	[ "$record" = registry ] || continue
	state=unavailable
	include_dirs=none
	library_dirs=none
	pkgconfig_dirs=none
	reason=module-missing

	if [ -n "${extra:-}" ]; then
		reason=invalid-registry
	elif [ "$method" != pkg-config ]; then
		reason=unsupported-method
	elif [ "$pkg_config_available" != yes ]; then
		reason=pkg-config-missing
	elif [ "$cc_available" != yes ]; then
		reason=compiler-missing
	elif "$pkg_config" --exists "$module" >/dev/null 2>&1; then
		cflags=$($pkg_config --cflags "$module" 2>/dev/null) || cflags=
		libs=$($pkg_config --libs "$module" 2>/dev/null) || libs=
		lib_names=$($pkg_config --libs-only-l "$module" 2>/dev/null) || lib_names=
		case " $lib_names " in
			*" -l$link_name "*)
				tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/uports-provider.XXXXXX") || exit 1
				trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
				printf '#include <%s>\nint main(void) { return 0; }\n' "$header" > "$tmpdir/probe.c"
				# Registry tokens and pkg-config output are restricted by the
				# surrounding validation.  Splitting flags here is intentional.
				if "$cc" $cflags "$tmpdir/probe.c" $libs -o "$tmpdir/probe" >/dev/null 2>&1; then
					set -- $($pkg_config --cflags-only-I "$module" 2>/dev/null || :)
					include_dirs=$(normalize_flags -I "$@") || include_dirs=invalid
					set -- $($pkg_config --libs-only-L "$module" 2>/dev/null || :)
					library_dirs=$(normalize_flags -L "$@") || library_dirs=invalid
					pcfile=$($pkg_config --path "$module" 2>/dev/null || :)
					if [ -n "$pcfile" ]; then
						pkgconfig_dirs=$(dirname "$pcfile")
						safe_path_list "$pkgconfig_dirs" || pkgconfig_dirs=invalid
					fi
					if [ "$include_dirs" != invalid ] &&
					   [ "$library_dirs" != invalid ] &&
					   [ "$pkgconfig_dirs" != invalid ]; then
						state=available
						reason=validated
					else
						reason=unsafe-path
					fi
					rm -rf "$tmpdir"
					trap - EXIT HUP INT TERM
				else
					reason=compile-link-failed
					rm -rf "$tmpdir"
					trap - EXIT HUP INT TERM
				fi
				;;
			*) reason=link-name-missing ;;
		esac
	fi

	printf 'discovery|%s|%s|%s|%s|%s|%s|%s\n' \
		"$key" "$origin" "$state" "$reason" \
		"$include_dirs" "$library_dirs" "$pkgconfig_dirs"
done
