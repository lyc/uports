#!/bin/sh

set -eu
set -f

provider_prefixes=${DEPENDENCY_PROVIDER_PREFIXES:-}

safe_token()
{
	case "$1" in
		'' | *[!A-Za-z0-9_./+,@:%-]* | .. | ../* | */.. | */../*) return 1 ;;
	esac
	return 0
}

find_profile_command()
{
	for candidate do
		case "$candidate" in */*) continue ;; esac
		for prefix in $provider_prefixes; do
			safe_token "$prefix" || continue
			path=$prefix/bin/$candidate
			if [ -x "$path" ]; then
				printf '%s\n' "$path"
				return 0
			fi
		done
	done
	return 1
}

version_at_least()
{
	awk -v actual="$1" -v minimum="$2" 'BEGIN {
		n = split(actual, a, "."); m = split(minimum, b, ".")
		for (i = 1; i <= (n > m ? n : m); i++) {
			x = a[i] + 0; y = b[i] + 0
			if (x > y) exit 0
			if (x < y) exit 1
		}
		exit 0
	}'
}

probe_version()
{
    # Preserve the command status before parsing its output: POSIX pipelines
    # otherwise return the parser's status even when the tool failed.
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

while IFS='|' read -r record key origin minimum candidates explicit required extra; do
	[ "$record" = tool ] || continue
	state=unavailable
	reason=command-missing
	bindir=none
	commands=none
	command_path=

	if [ -n "${extra:-}" ]; then
		reason=invalid-registry
	elif [ -n "$explicit" ]; then
		case "$explicit" in
			/*) command_path=$explicit ;;
			*) reason=unsafe-command-path ;;
		esac
	else
		# Candidate splitting is intentional; registry validation restricts it.
		command_path=$(find_profile_command $candidates || :)
	fi

	if [ -n "$command_path" ]; then
		if ! safe_token "$command_path" || [ ! -x "$command_path" ]; then
			reason=unsafe-command-path
		else
			version=
			if probe_version "$command_path"; then
				state=available
				reason=validated:$version
				bindir=$(dirname "$command_path")
				for command_name in $required; do
					if [ ! -x "$bindir/$command_name" ]; then
						state=unavailable; reason=command-missing:$command_name; break
					elif ! probe_version "$bindir/$command_name"; then
						state=unavailable; reason=interface-check-failed:$command_name; break
					fi
				done
				[ "$state" = available ] || bindir=none
				if [ "$state" = available ]; then
					commands=
					for command_name in $required; do
						case "$command_name" in
							m4) variable=M4 ;; autoconf) variable=AUTOCONF ;;
							autoreconf) variable=AUTORECONF ;; autoheader) variable=AUTOHEADER ;;
							autom4te) variable=AUTOM4TE ;; automake) variable=AUTOMAKE ;;
							aclocal) variable=ACLOCAL ;; libtoolize) variable=LIBTOOLIZE ;;
							libtool) variable=LIBTOOL ;; cmake) variable=CMAKE_BIN ;;
							ctest) variable=CTEST ;; *) continue ;;
						esac
						commands=${commands:+$commands:}$variable=$bindir/$command_name
					done
					commands=${commands:-none}
				fi
			elif [ -n "$version" ]; then
				reason=version-too-old:$version
			else
				reason=version-check-failed
			fi
		fi
	fi

	printf 'discovery|%s-tool|%s|%s|%s|none|none|none|%s|build|%s\n' \
		"$key" "$origin" "$state" "$reason" "$bindir" "$commands"
done
