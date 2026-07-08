#!/bin/sh

set -eu

scriptdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
uports=$(CDPATH= cd -- "$scriptdir/.." && pwd)

usage()
{
	cat <<EOF
usage: $0 output-directory [port-count]

Generate a deterministic tools.mk scaling fixture.
The default port count is 200.
EOF
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	usage >&2
	exit 2
fi

output=$1
count=${2:-200}

case "$count" in
	''|*[!0-9]*|0)
		printf 'port count must be a positive integer: %s\n' "$count" >&2
		exit 2
		;;
esac

if [ -e "$output" ]; then
	printf 'output already exists: %s\n' "$output" >&2
	exit 2
fi

mkdir -p "$output/feeds"
ports_file=$output/ports.list
: >"$ports_file"

i=1
while [ "$i" -le "$count" ]; do
	case $(((i - 1) % 4)) in
		0) category=devel ;;
		1) category=lang ;;
		2) category=math ;;
		3) category=textproc ;;
	esac
	group_number=$((((i - 1) % 4) + 1))
	group=g$group_number
	port=$(printf 'synthetic-%04d' "$i")
	origin=$category/$port

	mkdir -p "$output/feeds/$origin"
	printf '# synthetic planner fixture\n' >"$output/feeds/$origin/Makefile"

	if [ $((i % 10)) -eq 0 ] && [ "$group" != g1 ]; then
		printf 'g1@%s@%s\n' "$group" "$origin" >>"$ports_file"
	else
		printf '%s@%s\n' "$group" "$origin" >>"$ports_file"
	fi
	i=$((i + 1))
done

{
	printf 'UPORTS := %s\n' "$uports"
	printf 'FEEDS := %s/feeds\n' "$output"
	printf 'PREFIX := /usr\n'
	printf 'DESTDIR := %s/local\n' "$output"
	printf 'PORTS_GROUP_DEFAULT := g1\n'
	printf 'PORTS_LISTS :='
	while IFS= read -r port; do
		printf ' %s' "$port"
	done <"$ports_file"
	printf '\n'
	for group in g1 g2 g3 g4; do
		printf 'PORTS_%s_ENVS := PREFIX=/usr DESTDIR=%s/local/%s\n' \
			"$group" "$output" "$group"
	done
	printf 'include $(UPORTS)/Tools/tools.mk\n'
} >"$output/Makefile"

rm -f "$ports_file"

