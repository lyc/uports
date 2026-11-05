#!/bin/sh
# uPorts/Mk/Scripts/pkg.sh - called from uPorts/Mk/linuxl.port.post.mk
#
# MAINTAINER: yowching@gmail.com
#
# This script serves for pkg manipulation

set -e

validate_env() {
    local envfault=""
    for i ; do
	set -f
	if ! (eval ": \${${i}?}" ) >/dev/null; then
	    envfault="${envfault}${envfault:+" "}${i}"
	fi
	set +f
    done
    if [ -n "${envfault}" ]; then
	echo "Environment variable ${envfault} undefined. Aborting." \
	    | fmt >&2
	exit 1
    fi
}

#
# uPorts package format
#

# (L1) PVER: "1" for the legacy header, "2" with provider provenance
# (L2) NAME: pacakge name
# (L3) VER: package version
# (L4) PATH: The path of port directory
# (L5) PREFIX: prefix
# (L6) INDEX: The categories this port is part of
# (L7) COMPRESS: XZ (only support XZ format now)
# (L8) EXT: extension of pkg-plist.EXT file
# (PVER 2) PROVENANCE: %%%%%-PROVENANCE
#      ... (versioned dependency-provider provenance records)
#      %%%%%-PROVENANCE
# (next line) PLIST: %%%%% (separator, can be any)
#      ... (content of pkg-plist.EXT)
#      ... (multiple lines)
#      ...
#      %%%%% (end of pkg-plist.EXT, must same as separator defined in previously)
#      TXZ BLOB

# match_packages query database [match-origin]
match_packages() {
    awk -v p="$1" -v match_origin="${3:-0}" '
# Match an installed full name or its exact base, never a name prefix.
{
    name = $1
    sub(/:$/, "", name)
    suffix = "-" $2
    base = name
    if (substr(name, length(name) - length(suffix) + 1) == suffix)
        base = substr(name, 1, length(name) - length(suffix))
    if (name == p || base == p || (match_origin && $3 == p))
        print
}
    ' "$2"
}

# parse_plist runtime-prefix manifest
parse_plist() {
    awk -v prefix="$1" '
# Normalize the bounded uports plist subset into kind|prefix-relative-path.
function invalid(message) {
	printf "invalid plist entry at %s:%d: %s\n", FILENAME, FNR, \
	    message > "/dev/stderr"
	exit 1
}
{
	line = $0
	if (line == "" || line ~ /^@comment([[:space:]]|$)/)
		next
	kind = "path"
	if (line ~ /^@dir[[:space:]]+/) {
		kind = "dir"
		sub(/^@dir[[:space:]]+/, "", line)
	} else if (line ~ /^@rmdir[[:space:]]+/) {
		kind = "cleanup"
		sub(/^@rmdir[[:space:]]+/, "", line)
	} else if (line ~ /^@/)
		invalid("unsupported or malformed directive: " line)
	if (line ~ /%%/ || line ~ /[[:space:]|]/)
		invalid("unresolved token or unsupported path: " line)
	if (line ~ /^\//) {
		if (kind != "cleanup")
			invalid("absolute paths are only supported for @rmdir")
		base = prefix
		sub(/\/$/, "", base)
		if (prefix !~ /^\// || index(line, base "/") != 1)
			invalid("cleanup path is outside PREFIX: " line)
		line = substr(line, length(base) + 2)
	}
	if (line ~ /\/\//)
		invalid("empty path component: " line)
	sub(/^\.\//, "", line)
	sub(/\/$/, "", line)
	if (line == "" || line ~ /(^|\/)\.\.?($|\/)/ || line ~ /^\//)
		invalid("path must stay below PREFIX: " line)
	path = "./" line
	if (path in seen)
		invalid("duplicate path: " path)
	seen[path] = 1
	print kind "|" path
}
    ' "$2"
}

# check_plist staged-prefix manifest runtime-prefix
# Isolate its temporary-directory trap from the archive writer's trap.
check_plist() (
    set -eu
    root=$1
    plist=$2
    prefix=$3
    temporary=$(mktemp -d "${TMPDIR:-/tmp}/uports-plist-check.XXXXXX")
    trap 'rm -rf -- "$temporary"' EXIT HUP INT TERM

    [ -d "$root" ] || {
        printf '  ERR     staged prefix is missing: %s\n' "$root" >&2
        exit 1
    }
    [ -r "$plist" ] || {
        printf '  ERR     package manifest is not readable: %s\n' "$plist" >&2
        exit 1
    }
    parse_plist "$prefix" "$plist" > "$temporary/records"
    : > "$temporary/expected-paths"
    while IFS='|' read -r kind path
    do
        case "$kind" in
            dir)
            if [ ! -d "$root/${path#./}" ] ||
                [ -L "$root/${path#./}" ]; then
                printf '  ERR     declared directory is missing: %s\n' \
                    "$path" >&2
                exit 1
            fi
            ;;
            cleanup)
            if [ ! -e "$root/${path#./}" ] &&
                [ ! -L "$root/${path#./}" ]; then
                continue
            fi
            if [ ! -d "$root/${path#./}" ] ||
                [ -L "$root/${path#./}" ]; then
                printf '  ERR     invalid cleanup directory: %s\n' \
                    "$path" >&2
                exit 1
            fi
            ;;
        esac
        printf '%s\n' "$path" >> "$temporary/expected-paths"
    done < "$temporary/records"
    LC_ALL=C sort "$temporary/expected-paths" > "$temporary/expected"
    (cd "$root" && find . -print) > "$temporary/inventory"
    sed '/^\.$/d' "$temporary/inventory" > "$temporary/paths"
    LC_ALL=C sort "$temporary/paths" > "$temporary/actual"
    if ! diff -u "$temporary/expected" "$temporary/actual"; then
        printf '  ERR     package manifest differs from staged contents\n' >&2
        exit 1
    fi
)

do_create() {
    local rc pver temporary

    rc=0
    if [ -n "${PROVENANCE:-}${PACKAGE_BUILD_ID:-}" ]; then
	if [ -n "${PROVENANCE:-}" ] && [ ! -r "$PROVENANCE" ]; then
	    echo "Provider provenance file is not readable: $PROVENANCE" >&2
	    exit 1
	fi
	pver=2
    else
	pver=1
    fi

    check_plist "$STAGEDIR$PREFIX" "$PLIST" "$PREFIX"
    temporary=$(mktemp "$WRKDIR_PKGFILE.XXXXXX")
    trap 'rm -f -- "$temporary"' EXIT HUP INT TERM
    echo "PVER: $pver"          > "$temporary"
    echo "NAME: $PKGNAME"      >> "$temporary"
    echo "VER: $VERSION"       >> "$temporary"
    echo "PATH: $ORIGIN"       >> "$temporary"
    echo "PREFIX: $PREFIX"     >> "$temporary"
    echo "INDEX: $INDEX"       >> "$temporary"
    echo "COMPRESS: $COMPRESS" >> "$temporary"
    echo "EXT: $EXT"           >> "$temporary"
    if [ "$pver" -eq 2 ]; then
	echo "PROVENANCE: %%%%%-PROVENANCE" >> "$temporary"
	[ -z "${PROVENANCE:-}" ] ||
	    cat "$PROVENANCE" >> "$temporary"
	[ -z "${PACKAGE_BUILD_ID:-}" ] ||
	    printf 'package-build-id|%s\n' "$PACKAGE_BUILD_ID" \
		   >> "$temporary"
	echo "%%%%%-PROVENANCE" >> "$temporary"
    fi
    echo "PLIST: %%%%%"        >> "$temporary"
    cat "$PLIST"               >> "$temporary"
    echo "%%%%%"               >> "$temporary"
    case "$COMPRESS" in
        XZ)
            (cd "$STAGEDIR$PREFIX" && tar Jcf - .) >> "$temporary" ;;
        *)
            echo "Unsupported package compression: $COMPRESS" >&2
            exit 1
            ;;
    esac
    # Match ordinary archive creation permissions, honoring the current umask.
    chmod =rw "$temporary"
    mv -f -- "$temporary" "$WRKDIR_PKGFILE"
    trap - EXIT HUP INT TERM

    return ${rc}
}

do_add() {
    local quiet strip pkgname db name ver path prefix index compress ext
    local pver sep p_start provenance_end plist_line payload_line
    local tmpdir root

    quiet=
    strip=
    OPTIND=1
    while getopts pq OPT
    do
        case "$OPT" in
            q)
                quiet=1
                ;;
            p)
                strip=1
                ;;
            *)
                exit 1
                ;;
        esac
    done
    shift "$((OPTIND - 1))"
    [ "$#" -eq 1 ] || {
        echo "Usage: pkg add [-pq] package" >&2
        exit 1
    }
    pkgname=$1
    [ -r "$pkgname" ] || {
        echo "Cannot read package: $pkgname" >&2
        exit 1
    }
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/uports-pkg.XXXXXX")
    trap 'rm -rf -- "$tmpdir"' EXIT
    # Read only the text header, never interpret the binary payload as text.
    awk 'NR <= 8 {print} NR == 8 {exit}' "$pkgname" > "$tmpdir/header"
    pver=$(sed -n '1s/^PVER: //p' "$tmpdir/header")
    name=$(sed -n '2s/^NAME: //p' "$tmpdir/header")
    ver=$(sed -n '3s/^VER: //p' "$tmpdir/header")
    path=$(sed -n '4s/^PATH: //p' "$tmpdir/header")
    prefix=$(sed -n '5s/^PREFIX: //p' "$tmpdir/header")
    index=$(sed -n '6s/^INDEX: //p' "$tmpdir/header")
    compress=$(sed -n '7s/^COMPRESS: //p' "$tmpdir/header")
    ext=$(sed -n '8s/^EXT: //p' "$tmpdir/header")
    case "$name:$ext" in
        *[!A-Za-z0-9_.+:-]*|:*|*:)
            echo 'Invalid package identity' >&2
            exit 1
            ;;
    esac
    case "$prefix" in
        /) ;;
        *)
            case "$prefix/" in
                /*/../*|*/./*|//*)
                    echo 'Invalid package prefix' >&2
                    exit 1
                    ;;
            esac
            ;;
    esac
    case "$prefix" in
        /*) ;;
        *)
            echo 'Package prefix must be absolute' >&2
            exit 1
            ;;
    esac
    case "$pver" in
        1)
            plist_line=9
            ;;
        2)
            provenance_end=$(awk '
                NR == 9 && $0 != "PROVENANCE: %%%%%-PROVENANCE" {exit}
                NR > 9 && $0 == "%%%%%-PROVENANCE" {print NR; exit}
                ' "$pkgname")
            [ -n "$provenance_end" ] || {
                echo 'Invalid provenance block' >&2
                exit 1
            }
            plist_line=$((provenance_end + 1))
            ;;
        *)
            echo 'Unsupported package format' >&2
            exit 1
            ;;
    esac
    sep=$(sed -n "${plist_line}s/^PLIST: //p;${plist_line}q" "$pkgname")
    [ "$sep" = '%%%%%' ] || {
        echo 'Invalid package plist header' >&2
        exit 1
    }
    p_start=$((plist_line + 1))
    payload_line=$(awk -v start="$p_start" -v sep="$sep" \
        'NR >= start && $0 == sep {print NR + 1; exit}' "$pkgname")
    [ -n "$payload_line" ] || {
        echo 'Unterminated plist' >&2
        exit 1
    }
    awk -v start="$p_start" -v end="$payload_line" '
        NR >= start && NR < end - 1 {print}
        NR >= end - 1 {exit}
        ' "$pkgname" > "$tmpdir/plist"
    parse_plist "$prefix" "$tmpdir/plist" > "$tmpdir/records"
    tail -n +"$payload_line" "$pkgname" > "$tmpdir/payload"
    [ "$compress" = XZ ] || {
        echo 'Unsupported package compression' >&2
        exit 1
    }
    # Preserve runtime PREFIX; DESTDIR is only the installation root.
    [ -z "$strip" ] || prefix=/
    db="$DESTDIR/var/db"
    root="$DESTDIR${prefix%/}"
    [ -n "$root" ] || root=/
    mkdir -p "$root"
    if [ -n "$quiet" ]; then
        tar -xJf "$tmpdir/payload" -C "$root"
    else
        tar -xJvf "$tmpdir/payload" -C "$root"
    fi
    mkdir -p "$db"
    touch "$db/pkg"
    awk -v name="$name:" '$1 != name' "$db/pkg" > "$tmpdir/db"
    printf '%s: %s %s %s "%s" %s-pkg-plist.%s\n' \
        "$name" "$ver" "$path" "$prefix" "$index" "$name" "$ext" \
        >> "$tmpdir/db"
    cp "$tmpdir/plist" "$db/$name-pkg-plist.$ext"
    cp "$tmpdir/db" "$db/pkg"
    rm -rf -- "$tmpdir"
    trap - EXIT
}

do_info()
{
    local rc destdir db
    local by_origin origin quiet exist pkgname info

    rc=0
    destdir=$DESTDIR
    db=${destdir}/var/db

#    echo "==>$*"
#    echo destdir=$destdir
#    echo db=$db

    by_origin=0
    origin=0
    quiet=0
    exist=0
    pkgname=
    info=

    while getopts eoOq OPT
    do
        case "$OPT" in
            e) eval exist=1 ;;
            o) eval origin=1 ;;
            O) eval by_origin=1 ;;
            q) eval quiet=1 ;;
            *) echo >&2 "Usage: pkg info [ -eoOq ] pkgname"; exit 1 ;;
        esac
    done

#    echo origin=$origin
#    echo by_origin=$by_origin
#    echo quiet=$quiet

    if [ $OPTIND -gt 1 ]; then
        shiftcount=`expr $OPTIND - 1`
        shift $shiftcount
    fi

#    echo 0=$0
    pkgname=$1
    if [ -z "$pkgname" ]; then
	echo >&2 "Usage: $0 info [ -oq ] {pkgname} " ; exit 1
    fi
#    echo pkgname=$pkgname

    if [ -f "${db}/pkg" ]; then
        info=$(match_packages "$pkgname" "${db}/pkg" 1)
    fi
#    echo info=$info

    if [ $exist -eq 1 ]; then
        if [ -z "$info" ]; then
            rc=1
        fi
    elif [ $by_origin -eq 1 ]; then
        if [ $quiet -eq 1 ]; then
            if [ -n "$info" ]; then
                echo `echo $info | awk '{ print $1}' | sed -e 's/://g'`
            fi
        fi
    fi
#    echo rc=$rc
    return ${rc}
}

do_version()
{
    local rc destdir db
    local quiet test v1 v2

#    echo "do_version ..."

    rc=0
    destdir=$DESTDIR
    db=${destdir}/var/db

#    echo "2==>$*"
#    echo destdir=$destdir
#    echo db=$db

    quiet=0
    test=0

    while getopts qt OPT
    do
        case "$OPT" in
            q) eval quiet=1 ;;
            t) eval test=1 ;;
            *) echo >&2 "Usage: pkg version [ -qt ] pkgname"; exit 1 ;;
        esac
    done

#    echo quiet=$quiet
#    echo test=$test

    if [ $OPTIND -gt 1 ]; then
        shiftcount=`expr $OPTIND - 1`
        shift $shiftcount
    fi

#    echo "3==>$*"
#    echo 0=$0
#    echo 1=$1
#    echo 2=$2

    if [ $test -eq 1 ]; then
        local v1=$1
        local v2=$2
        if [ -z $v1 ] || [ -z $v2 ]; then
            echo >&2 "Usage: pkg version [ -t ] ver1 ver2"; exit 1
        fi
        if [ "$v1" = "$v2" ];then
            echo "="
        elif [ "$v1" > "$v2" ];then
            echo ">"
        else
            echo "<"
        fi
    fi
    return ${rc}
}

do_delete()
{
    local quiet dryrun all p info plist prefix root f fname dir kind
    local tmpdir names

    quiet=0
    dryrun=0
    all=0
    OPTIND=1
    while getopts afnq OPT
    do
        case "$OPT" in
            a)
                all=1
                ;;
            f)
                :
                ;;
            n)
                dryrun=1
                ;;
            q)
                quiet=1
                ;;
            *)
                exit 1
                ;;
        esac
    done
    shift "$((OPTIND - 1))"
    [ "$all" -eq 1 ] || [ "$#" -eq 1 ] || {
        echo 'Usage: pkg delete [-afnq] name' >&2
        exit 1
    }
    [ -f "$DESTDIR/var/db/pkg" ] || return 0
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/uports-pkg-delete.XXXXXX")
    trap 'rm -rf -- "$tmpdir"' EXIT
    if [ "$all" -eq 1 ]; then
        names=$(awk '{sub(/:$/, "", $1); print $1}' "$DESTDIR/var/db/pkg")
    else
        names=$1
    fi
    for p in $names
    do
        info=$(match_packages "$p" "$DESTDIR/var/db/pkg")
        [ -n "$info" ] || continue
        # Resolve each matching installed package independently.
        printf '%s\n' "$info" > "$tmpdir/matches"
        while IFS= read -r entry
        do
            prefix=$(printf '%s\n' "$entry" | awk '{print $4}')
            plist="$DESTDIR/var/db/$(printf '%s\n' "$entry" | awk '{print $NF}')"
            case "$prefix" in
                /) ;;
                *)
                    case "$prefix/" in
                        /*/../*|*/./*|//*)
                            echo 'Invalid installed prefix' >&2
                            exit 1
                            ;;
                    esac
                    ;;
            esac
            case "$prefix" in
                /*) ;;
                *)
                    exit 1
                    ;;
            esac
            root="$DESTDIR${prefix%/}"
            [ -n "$root" ] || root=/
            : > "$tmpdir/dirs"
            if [ -f "$plist" ]; then
                parse_plist "$prefix" "$plist" > "$tmpdir/records"
                while IFS='|' read -r kind f
                do
                    fname="$root/${f#./}"
                    case "$fname/" in
                        */../*|*/./*)
                            echo 'Invalid installed path' >&2
                            exit 1
                            ;;
                    esac
                    case "$fname" in
                        "${root%/}/"*) ;;
                        *)
                            echo 'Plist path outside install prefix' >&2
                            exit 1
                            ;;
                    esac
                    if [ "$kind" = dir ] || [ "$kind" = cleanup ]; then
                        printf '%s\n' "$fname" >> "$tmpdir/dirs"
                    elif [ -d "$fname" ] && [ ! -L "$fname" ]; then
                        printf '%s\n' "$fname" >> "$tmpdir/dirs"
                    else
                        [ "$quiet" -eq 1 ] || printf 'delete %s\n' "$fname"
                        if [ "$dryrun" -eq 1 ]; then
                            printf 'rm -f %s\n' "$fname"
                        else
                            rm -f -- "$fname"
                        fi
                        dir=${fname%/*}
                        while [ "$dir" != "$root" ] && \
                            [ "$dir" != / ] && [ -n "$dir" ]
                        do
                            printf '%s\n' "$dir" >> "$tmpdir/dirs"
                            dir=${dir%/*}
                        done
                    fi
                done < "$tmpdir/records"
                awk '{print length($0) "|" $0}' "$tmpdir/dirs" | sort -rn |
                    cut -d'|' -f2- | awk '!seen[$0]++' > "$tmpdir/ordered"
                while IFS= read -r dir
                do
                    if [ "$dryrun" -eq 1 ]; then
                        printf 'rmdir %s\n' "$dir"
                    else
                        rmdir -- "$dir" 2>/dev/null || :
                    fi
                done < "$tmpdir/ordered"
                [ "$dryrun" -eq 1 ] || rm -f -- "$plist"
            fi
            if [ "$dryrun" -ne 1 ]; then
                installed=$(printf '%s\n' "$entry" | awk '{print $1}')
                awk -v name="$installed" '$1 != name' \
                    "$DESTDIR/var/db/pkg" > "$tmpdir/db"
                cp "$tmpdir/db" "$DESTDIR/var/db/pkg"
            fi
        done < "$tmpdir/matches"
    done
    if [ "$dryrun" -ne 1 ] && [ ! -s "$DESTDIR/var/db/pkg" ]; then
        rm -f -- "$DESTDIR/var/db/pkg"
    fi
    rm -rf -- "$tmpdir"
    trap - EXIT
}

# obtain operating mode from command line
ret=0
add=0
create=0
delete=0
info=0
version=0
check=0
case "$1" in
    add) add=1 ;;
    create) create=1 ;;
    delete) delete=1 ;;
    info) info=1 ;;
    version) version=1 ;;
    check-plist) check=1 ;;
    *)
        echo >&2 "Usage: $0 {add|create|delete|info|version|check-plist}"
        exit 1
        ;;
esac

shift 1

if [ "$check" -eq 1 ]; then
    [ "$#" -eq 3 ] || {
        echo 'Usage: pkg check-plist staged-prefix manifest runtime-prefix' >&2
        exit 1
    }
    check_plist "$@"
    exit
fi

# echo "1==>$*"

if [ ${create} -eq 1 ]; then
    # validate environment
    validate_env STAGEDIR PKGNAME VERSION ORIGIN PREFIX INDEX COMPRESS EXT PLIST WRKDIR_PKGFILE

    do_create
else
    validate_env DESTDIR
    case "$DESTDIR" in
        ""|/*) ;;
        *)
            echo "DESTDIR must be absolute" >&2
            exit 1
            ;;
    esac
    DESTDIR=${DESTDIR%/}

    if [ ${add} -eq 1 ]; then
        do_add "$@"
    fi
    if [ ${delete} -eq 1 ]; then
        do_delete "$@"
    fi
    if [ ${info} -eq 1 ]; then
        do_info "$@" || ret=1
    fi
    if [ ${version} -eq 1 ]; then
        do_version "$@"
    fi
fi

# echo ret=$ret
exit ${ret}
