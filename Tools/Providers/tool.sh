#!/bin/sh

set -eu
set -f

provider_prefixes=${DEPENDENCY_PROVIDER_PREFIXES:-}

safe_path()
{
	case "$1" in /*) ;; *) return 1 ;; esac
	case "$1" in
		*[!A-Za-z0-9_./+,@:%-]* | */.. | */../*) return 1 ;;
	esac
}

version_at_least()
{
	awk -v actual="$1" -v minimum="$2" 'BEGIN {
		n = split(actual, a, "."); m = split(minimum, b, ".")
		for (i = 1; i <= (n > m ? n : m); i++) {
			if (a[i] + 0 > b[i] + 0) exit 0
			if (a[i] + 0 < b[i] + 0) exit 1
		}
		exit 0
	}'
}

probe_version()
{
	version=
	# Check status before parsing: a valid banner does not imply success.
	banner=$("$1" --version 2>/dev/null) || return 1
	version=$(printf '%s\n' "$banner" | awk 'NR == 1 {
		for (i = 1; i <= NF; i++) {
			value = $i
			gsub(/^[^0-9]+|[^0-9.]+$/, "", value)
			if (value ~ /^[0-9]+(\.[0-9]+)+$/) { print value; exit }
		}
	}')
	[ -n "$version" ] && version_at_least "$version" "$minimum"
}

command_variable()
{
	case "$1" in
		m4) printf M4 ;; autoconf) printf AUTOCONF ;;
		autoreconf) printf AUTORECONF ;; autoheader) printf AUTOHEADER ;;
		autom4te) printf AUTOM4TE ;; automake) printf AUTOMAKE ;;
		aclocal) printf ACLOCAL ;; libtoolize) printf LIBTOOLIZE ;;
		libtool) printf LIBTOOL ;; cmake) printf CMAKE_BIN ;;
		ctest) printf CTEST ;;
		python3) printf PYTHON ;; ninja) printf NINJA ;;
	esac
}

validate_candidate()
{
	command_path=$1
	if ! safe_path "$command_path" || [ ! -x "$command_path" ]; then
		reason=unsafe-command-path; return 1
	fi
	if ! probe_version "$command_path"; then
		reason=${version:+version-too-old:$version}
		reason=${reason:-version-check-failed}
		return 1
	fi
	primary_version=$version
	bindir=$(dirname "$command_path")
	commands=
	versions=
	for command_name in $required; do
		required_path=$bindir/$command_name
		# An explicit or alternate candidate replaces the canonical primary
		# command; companion commands still come from that installation.
		[ "$command_name" != "$primary" ] || required_path=$command_path
		if [ ! -x "$required_path" ]; then
			reason=command-missing:$command_name; return 1
		fi
		if ! probe_version "$required_path"; then
			reason=interface-check-failed:$command_name; return 1
		fi
		versions=${versions:+$versions:}$command_name=$version
		variable=$(command_variable "$command_name")
		if [ -n "$variable" ]; then
			commands=${commands:+$commands:}$variable=$required_path
		fi
	done
	valid_count=$((valid_count + 1))
	printf 'discovery|%s-tool|%s|available|validated:%s|none|none|none|%s|%s|%s|%s|%s\n' \
		"$key" "$origin" "$primary_version" "$bindir" \
		"$context" "${commands:-none}" "$versions" "$valid_count"
}

while IFS='|' read -r record key origin minimum candidates explicit required primary context extra; do
	[ "$record" = tool ] || continue
	context=${context:-build}
	valid_count=0
	reason=command-missing
	if [ -n "${extra:-}" ]; then
		reason=invalid-registry
	elif [ "$context" != build ] && [ "$context" != both ]; then
		reason=invalid-context
	elif [ -n "$explicit" ]; then
		# Explicit choice is authoritative: never silently try another path.
		validate_candidate "$explicit" || :
	else
		seen_paths=
		for candidate in $candidates; do
			case "$candidate" in */*) continue ;; esac
			for prefix in $provider_prefixes; do
				safe_path "$prefix" || continue
				path=$prefix/bin/$candidate
				[ -x "$path" ] || continue
				case " $seen_paths " in *" $path "*) continue ;; esac
				seen_paths="$seen_paths $path"
				validate_candidate "$path" || :
			done
		done
	fi
	if [ "$valid_count" -eq 0 ]; then
		printf 'discovery|%s-tool|%s|unavailable|%s|none|none|none|none|build|none\n' \
			"$key" "$origin" "$reason"
	fi
done
