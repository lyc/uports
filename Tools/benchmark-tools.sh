#!/bin/sh

set -eu

scriptdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
directory=$scriptdir/tests
runs=5
label=tools-tests

usage()
{
	cat <<EOF
usage: $0 [-C directory] [-n runs] [-l label] [make-variable=value ...]

Benchmark tools.mk planning without running package recipes.

Examples:
  $0
  $0 -C /path/to/project -l full
  $0 -C /path/to/project -l cpython PORTS_LISTS=lang/cpython
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		-C)
			[ "$#" -ge 2 ] || {
				usage >&2
				exit 2
			}
			directory=$2
			shift 2
			;;
		-n)
			[ "$#" -ge 2 ] || {
				usage >&2
				exit 2
			}
			runs=$2
			shift 2
			;;
		-l)
			[ "$#" -ge 2 ] || {
				usage >&2
				exit 2
			}
			label=$2
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		--)
			shift
			break
			;;
		-*)
			printf 'unknown option: %s\n' "$1" >&2
			usage >&2
			exit 2
			;;
		*)
			break
			;;
	esac
done

case "$runs" in
	''|*[!0-9]*|0)
		printf 'runs must be a positive integer: %s\n' "$runs" >&2
		exit 2
		;;
esac

directory=$(CDPATH= cd -- "$directory" && pwd)
make_arguments=$*
tmpdir=${TMPDIR:-/tmp}/uports-tools-benchmark.$$
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

planner_file=$tmpdir/planner
database_file=$tmpdir/database
timings_file=$tmpdir/timings
times_file=$tmpdir/time

time_mode=posix
if /usr/bin/time --version 2>/dev/null | grep -q 'GNU time'; then
	time_mode=gnu
fi

make --no-print-directory -s -C "$directory" USE_HOSTTOOLS= \
	planner-stats "$@" >"$planner_file"

i=1
while [ "$i" -le "$runs" ]; do
	if [ "$time_mode" = gnu ]; then
		/usr/bin/time -f 'real %e\nuser %U\nsys %S\nrss %M' \
			-o "$times_file" \
			make --no-print-directory -s -C "$directory" \
			USE_HOSTTOOLS= planner-stats "$@" >/dev/null
	else
		/usr/bin/time -p -o "$times_file" \
			make --no-print-directory -s -C "$directory" \
			USE_HOSTTOOLS= planner-stats "$@" >/dev/null
	fi
	awk '
	  $1 == "real" { real = $2 }
	  $1 == "user" { user = $2 }
	  $1 == "sys"  { sys = $2 }
	  $1 == "rss"  { rss = $2 }
	  END {
	    if (rss == "") {
	      rss = "unavailable"
	    }
	    printf "%.6f %.6f %.6f %s\n", real, user, sys, rss
	  }
	' "$times_file" >>"$timings_file"
	i=$((i + 1))
done

make --no-print-directory -np -C "$directory" USE_HOSTTOOLS= \
	planner-stats "$@" >"$database_file" 2>/dev/null

median_times=$(awk '
  {
    real[NR] = $1
    user[NR] = $2
    sys[NR] = $3
    rss[NR] = $4
  }
  END {
    for (i = 1; i <= NR; i++) {
      for (j = i + 1; j <= NR; j++) {
        if (real[i] > real[j]) { t = real[i]; real[i] = real[j]; real[j] = t }
        if (user[i] > user[j]) { t = user[i]; user[i] = user[j]; user[j] = t }
        if (sys[i] > sys[j]) { t = sys[i]; sys[i] = sys[j]; sys[j] = t }
        if (rss[i] != "unavailable" && rss[j] != "unavailable" &&
            rss[i] > rss[j]) { t = rss[i]; rss[i] = rss[j]; rss[j] = t }
      }
    }
    mid = int((NR + 1) / 2)
    if (NR % 2) {
      r = real[mid]
      u = user[mid]
      s = sys[mid]
      m = rss[mid]
    } else {
      r = (real[mid] + real[mid + 1]) / 2
      u = (user[mid] + user[mid + 1]) / 2
      s = (sys[mid] + sys[mid + 1]) / 2
      if (rss[mid] == "unavailable") {
        m = "unavailable"
      } else {
        m = (rss[mid] + rss[mid + 1]) / 2
      }
    }
    printf "%.6f %.6f %.6f %s", r, u, s, m
  }
' "$timings_file")
set -- $median_times
median_real=$1
median_user=$2
median_sys=$3
median_rss=$4

database_counts=$(awk '
  BEGIN { rules = 0; phony = 0 }
  /^[^#.%][^=]*:([^=]|$)/ { rules++ }
  /^\.PHONY:/ {
    for (i = 2; i <= NF; i++) {
      phony++
    }
  }
  END { printf "%d %d", rules, phony }
' "$database_file")
set -- $database_counts
rule_lines=$1
phony_names=$2

make_version=$(make --version | sed -n '1p')
host_os=$(uname -s)
host_arch=$(uname -m)
database_bytes=$(wc -c <"$database_file" | tr -d ' ')

printf '%s\n' \
	'benchmark_format=1' \
	"label=$label" \
	"make_version=$make_version" \
	"host_os=$host_os" \
	"host_arch=$host_arch" \
	"directory=$directory" \
	"runs=$runs" \
	"make_arguments=$make_arguments"
cat "$planner_file"
printf '%s\n' \
	"median_real_seconds=$median_real" \
	"median_user_seconds=$median_user" \
	"median_sys_seconds=$median_sys" \
	"memory_max_rss_kb=$median_rss" \
	"make_database_bytes=$database_bytes" \
	"make_database_rule_lines=$rule_lines" \
	"make_database_phony_names=$phony_names"
