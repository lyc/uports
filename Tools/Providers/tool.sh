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

while IFS='|' read -r record key origin minimum candidates explicit extra; do
	[ "$record" = tool ] || continue
	state=unavailable
	reason=command-missing
	bindir=none
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
			version=$($command_path --version 2>/dev/null | awk '
				NR == 1 {
					for (i = 1; i <= NF; i++) {
						value = $i
						gsub(/^[^0-9]+|[^0-9.]+$/, "", value)
						if (value ~ /^[0-9]+(\.[0-9]+)+$/) {
							print value
							exit
						}
					}
				}')
			if [ -z "$version" ]; then
				reason=version-check-failed
			elif ! version_at_least "$version" "$minimum"; then
				reason=version-too-old:$version
			else
				state=available
				reason=validated:$version
				bindir=$(dirname "$command_path")
			fi
		fi
	fi

	printf 'discovery|%s-tool|%s|%s|%s|none|none|none|%s|build\n' \
		"$key" "$origin" "$state" "$reason" "$bindir"
done
