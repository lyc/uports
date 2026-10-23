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

do_create() {
    local rc pver

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

    echo "PVER: $pver"          > "$WRKDIR_PKGFILE"
    echo "NAME: $PKGNAME"      >> "$WRKDIR_PKGFILE"
    echo "VER: $VERSION"       >> "$WRKDIR_PKGFILE"
    echo "PATH: $ORIGIN"       >> "$WRKDIR_PKGFILE"
    echo "PREFIX: $PREFIX"     >> "$WRKDIR_PKGFILE"
    echo "INDEX: $INDEX"       >> "$WRKDIR_PKGFILE"
    echo "COMPRESS: $COMPRESS" >> "$WRKDIR_PKGFILE"
    echo "EXT: $EXT"           >> "$WRKDIR_PKGFILE"
    if [ "$pver" -eq 2 ]; then
	echo "PROVENANCE: %%%%%-PROVENANCE" >> "$WRKDIR_PKGFILE"
	[ -z "${PROVENANCE:-}" ] ||
	    cat "$PROVENANCE" >> "$WRKDIR_PKGFILE"
	[ -z "${PACKAGE_BUILD_ID:-}" ] ||
	    printf 'package-build-id|%s\n' "$PACKAGE_BUILD_ID" \
		   >> "$WRKDIR_PKGFILE"
	echo "%%%%%-PROVENANCE" >> "$WRKDIR_PKGFILE"
    fi
    echo "PLIST: %%%%%"        >> "$WRKDIR_PKGFILE"
    cat "$PLIST"               >> "$WRKDIR_PKGFILE"
    echo "%%%%%"               >> "$WRKDIR_PKGFILE"
    case "$COMPRESS" in
        XZ)
            cd "$STAGEDIR$PREFIX" && tar Jcf - . >> "$WRKDIR_PKGFILE" ;;
    esac

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
        info=$(awk -v p="$pkgname" '{name=$1; sub(/:$/, "", name)}
            name == p || index(name, p "-") == 1 || $3 == p {print}' "${db}/pkg")
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
    local quiet dryrun all p info plist prefix root f fname dir
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
        info=$(awk -v p="$p" '{name=$1; sub(/:$/, "", name)}
            name == p || index(name, p "-") == 1 {print}' "$DESTDIR/var/db/pkg")
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
                while IFS= read -r f
                do
                    case "$f" in
                        @rmdir\ *)
                            f=${f#@rmdir }
                            case "$f" in
                                /*)
                                    fname="$DESTDIR$f"
                                    ;;
                                *)
                                    fname="$root/${f#./}"
                                    ;;
                            esac
                            ;;
                        ./*)
                            fname="$root/${f#./}"
                            ;;
                        *)
                            continue
                            ;;
                    esac
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
                    if [ -d "$fname" ] && [ ! -L "$fname" ]; then
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
                done < "$plist"
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
case "$1" in
    add) add=1 ;;
    create) create=1 ;;
    delete) delete=1 ;;
    info) info=1 ;;
    version) version=1 ;;
    *) echo >&2 "Usage: $0 {add|create|delete|info|version}" ; exit 1 ;;
esac

shift 1


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
