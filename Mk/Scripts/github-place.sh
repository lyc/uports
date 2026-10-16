#!/bin/sh
# Assemble archive groups before alternative-source linking and Git patching.
# Inputs are validated group|extracted-basename|relative-placement records.
set -eu
set -f
die() { printf '  ERR     GitHub placement: %s\n' "$*" >&2; exit 1; }
: "${GH_EXTRACT_ROOT:?}" "${GH_MAIN_ROOT:?}"
extract=${GH_EXTRACT_ROOT%/}
main=${GH_MAIN_ROOT%/}
case $extract:$main in /*:/*) ;; *) die 'source roots must be absolute' ;; esac

# Validate records independently of make, sort shallow-to-deep, and reject
# ambiguous roots/destinations before touching any directory.
ordered=$(printf '%s\n' "$@" | awk -F'|' '
function fail(msg) {print msg > "/dev/stderr"; bad=1; exit 1}
{
    if (NF!=3 || $1 !~ /^[A-Za-z0-9_]+$/) fail("invalid layout record")
    if ($1!="DEFAULT" && ($2 !~ /^[A-Za-z0-9_.+-]+$/ || $2 ~ /^[-.]/))
        fail("unsafe archive root")
    if ($3!="-" && ($3 !~ /^[A-Za-z0-9_.+\/-]+$/ || $3 ~ /^[-\/]/ ||
        $3 ~ /(^|\/)(\.|\.\.|)(\/|$)/)) fail("unsafe placement path")
    if ($1=="DEFAULT") {alias=$3; next}
    if ($2 in roots && roots[$2]!=$3) fail("archive root placed twice")
    roots[$2]=$3
    if ($3!="-" && $3 in targets && targets[$3]!=$2)
        fail("duplicate placement destination")
    targets[$3]=$2
    n=split($3,p,"/"); printf "%d\t%d\t%s\n",n,NR,$0
    paths[NR]=$3
}
END {
    if (bad) exit 1
    if (alias!="" && alias!="-") {
        for (i in paths) if (paths[i]==alias ||
            index(paths[i],alias "/")==1 || index(alias,paths[i] "/")==1)
            fail("default GH_SUBDIR overlaps a grouped placement")
        printf "999999\t0\tDEFAULT|-|%s\n",alias
    }
}') || die 'invalid or conflicting layout'
ordered=$(printf '%s\n' "$ordered" | sort -n -k1,1 -k2,2 | cut -f3-)

# No path component inspected by this phase may redirect outside its tree.
inspect() {
    inspect_base=$1 inspect_relative=$2
    [ ! -L "$inspect_base" ] || die "symlink source root: $inspect_base"
    old_ifs=$IFS; IFS=/; set -- $inspect_relative; IFS=$old_ifs
    for component do
        inspect_base=$inspect_base/$component
        [ ! -L "$inspect_base" ] || die "symlink in placement: $inspect_base"
        [ ! -e "$inspect_base" ] || [ -d "$inspect_base" ] ||
            die "non-directory placement: $inspect_base"
    done
    inspected=$inspect_base
}

self_link() {
    alias_parent=${1%/*}; alias_link=.
    if [ "$alias_parent" != "$1" ]; then
        alias_ifs=$IFS; IFS=/; set -- $alias_parent; IFS=$alias_ifs
        alias_link=
        for alias_component do alias_link=../$alias_link; done
    fi
}

# Check all source roots first. Repeated calls accept only our exact link to
# a real confined destination; no reset, stash, or recursive removal is used.
[ ! -L "$main" ] || die "unexpected main-root symlink: $main"
for record in $ordered; do
    group=${record%%|*}; rest=${record#*|}
    source=$extract/${rest%%|*}; placement=${rest#*|}
    [ "$group" != DEFAULT ] || continue
    [ "$source" != "$main" ] || [ "$placement" = - ] ||
        die 'group root cannot be moved inside itself'
    if [ -L "$source" ]; then
        [ "$placement" != - ] &&
            [ "$(readlink "$source")" = "$main/$placement" ] ||
            die "unexpected source symlink: $source"
        inspect "$main" "$placement"
        [ -d "$inspected" ] || die "missing previously placed source"
    else
        [ -d "$source" ] || die "missing archive root: $source"
    fi
done

# Inspect the *future* parent source for nested placements, not just the old
# main tree. This catches archive-provided symlinks before moving any group.
for record in $ordered; do
    group=${record%%|*}; rest=${record#*|}
    source=$extract/${rest%%|*}; placement=${rest#*|}
    [ "$placement" != - ] || continue
    base=$main relative=$placement longest=0
    for parent in $ordered; do
        parent_group=${parent%%|*}; parent_rest=${parent#*|}
        parent_source=$extract/${parent_rest%%|*}
        parent_path=${parent_rest#*|}
        [ "$parent_group" != DEFAULT ] && [ "$parent_path" != - ] || continue
        case $placement in "$parent_path"/*)
            if [ "${#parent_path}" -gt "$longest" ]; then
                longest=${#parent_path}
                base=$parent_source relative=${placement#"$parent_path"/}
                if [ -L "$base" ]; then base=$main/$parent_path; fi
            fi ;;
        esac
    done
    if [ "$group" = DEFAULT ] && [ -L "$main/$placement" ]; then
        self_link "$placement"
        [ "$(readlink "$main/$placement")" = "$alias_link" ] ||
            die "unexpected default self-alias: $placement"
        if [ "${placement%/*}" != "$placement" ]; then
            inspect "$main" "${placement%/*}"
        fi
        continue
    fi
    inspect "$base" "$relative"
    if [ -d "$inspected" ]; then
        if [ "$group" = DEFAULT ] || [ ! -L "$source" ]; then
            [ -z "$(ls -A "$inspected")" ] ||
                die "populated destination would be overwritten: $inspected"
        fi
    fi
done

mkdir -p -- "$main"
for record in $ordered; do
    group=${record%%|*}; rest=${record#*|}
    source=$extract/${rest%%|*}; placement=${rest#*|}
    [ "$placement" != - ] || continue
    target=$main/$placement
    if [ "$group" = DEFAULT ]; then
        self_link "$placement"
        if [ -L "$target" ]; then
            [ "$(readlink "$target")" = "$alias_link" ] ||
                die "unexpected default self-alias: $target"
            continue
        fi
        [ ! -d "$target" ] || rmdir -- "$target"
        mkdir -p -- "${target%/*}"
        ln -s "$alias_link" "$target"
    else
        [ ! -L "$source" ] || continue
        [ ! -d "$target" ] || rmdir -- "$target"
        mkdir -p -- "${target%/*}"
        mv -- "$source" "$target"
        ln -s "$target" "$source"
    fi
done
