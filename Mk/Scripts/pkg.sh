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

# Reject symlink/file parents before package writes or removals.
# check_package_parents destination-path [operation]
check_package_parents() {
    local parent operation

    operation=${2:-Install}
    parent=${1%/*}
    while [ "$parent" != "$DESTDIR" ] && [ "$parent" != / ] &&
        [ -n "$parent" ]; do
        if [ -L "$parent" ] ||
            { [ -e "$parent" ] && [ ! -d "$parent" ]; }; then
            echo "$operation conflict: unsafe destination parent $parent" >&2
            exit 1
        fi
        parent=${parent%/*}
    done
}

# Build an ownership index from installed manifests, not filename prefixes.
# collect_package_owners database scratch [incoming-name incoming-prefix]
collect_package_owners() {
    local db scratch incoming new_prefix entry owner old_prefix
    local manifest kind file type

    db=$1
    scratch=$2
    incoming=${3:-}
    new_prefix=${4:-}
    : > "$scratch/owners"
    [ -f "$db/pkg" ] || return 0
    while IFS= read -r entry
    do
        owner=$(printf '%s\n' "$entry" | awk '{sub(/:$/, "", $1); print $1}')
        old_prefix=$(printf '%s\n' "$entry" | awk '{print $4}')
        manifest=$(printf '%s\n' "$entry" | awk '{print $NF}')
        case "$old_prefix" in
            /) ;;
            *)
                case "$old_prefix/" in
                    /*/../*|*/./*|*//*|*[[:space:]\|]*)
                        echo "Invalid installed prefix: $old_prefix" >&2
                        exit 1
                        ;;
                esac
                ;;
        esac
        case "$old_prefix" in
            /*) ;;
            *)
                echo 'Invalid installed package record' >&2
                exit 1
                ;;
        esac
        case "$manifest" in
            ""|.|..|*[!A-Za-z0-9_.+:-]*)
                echo 'Invalid installed manifest name' >&2
                exit 1
                ;;
        esac
        if [ -n "$incoming" ] && [ "$owner" = "$incoming" ] &&
            [ "$old_prefix" != "$new_prefix" ]; then
            echo 'Install conflict: remove package before changing PREFIX' >&2
            exit 1
        fi
        [ -r "$db/$manifest" ] || {
            echo "Missing installed manifest: $db/$manifest" >&2
            exit 1
        }
        parse_plist "$old_prefix" "$db/$manifest" > "$scratch/old-records"
        while IFS='|' read -r kind file
        do
            file="${old_prefix%/}/${file#./}"
            type=file
            if [ "$kind" != path ] ||
                { [ -d "$DESTDIR$file" ] && [ ! -L "$DESTDIR$file" ]; }; then
                type=dir
            fi
            printf '%s|%s|%s\n' "$file" "$owner" "$type" >> "$scratch/owners"
        done < "$scratch/old-records"
    done < "$db/pkg"
}

# Validate every prospective path before creating destination directories.
# check_install_conflicts scratch-directory incoming-name runtime-prefix
check_install_conflicts() {
    local scratch incoming runtime_prefix kind file source type present target

    scratch=$1
    incoming=$2
    runtime_prefix=$3
    collect_package_owners "$DESTDIR/var/db" "$scratch" \
        "$incoming" "$runtime_prefix"
    : > "$scratch/incoming"
    while IFS='|' read -r kind file
    do
        source="$scratch/stage/${file#./}"
        [ -e "$source" ] || [ -L "$source" ] || continue
        type=file
        if [ -d "$source" ] && [ ! -L "$source" ]; then
            type=dir
        fi
        file="${runtime_prefix%/}/${file#./}"
        target="$DESTDIR$file"
        check_package_parents "$target"
        present=missing
        if [ -L "$target" ] || [ -e "$target" ]; then
            present=file
            if [ -d "$target" ] && [ ! -L "$target" ]; then
                present=dir
            fi
        fi
        printf '%s|%s|%s\n' "$file" "$type" "$present" >> "$scratch/incoming"
    done < "$scratch/records"
    awk -F '|' -v incoming="$incoming" '
    FILENAME == ARGV[1] {
        if ($3 == "dir")
            directories[$1] = 1
        else {
            files[$1] = 1
            if ($2 == incoming)
                own[$1] = 1
            else
                other[$1] = $2
        }
        next
    }
    {
        reason = ""
        if ($2 == "dir" && (files[$1] || $3 == "file"))
            reason = "directory would replace a file or symlink"
        if ($2 == "file") {
            if (other[$1])
                reason = "owned by " other[$1]
            else if (directories[$1] || $3 == "dir")
                reason = "file would replace a directory"
            else if ($3 != "missing" && !own[$1])
                reason = "unmanaged existing file or symlink"
        }
        if (reason != "") {
            print "Install conflict: " $1 ": " reason > "/dev/stderr"
            failed = 1
        }
    }
    END {exit failed}
    ' "$scratch/owners" "$scratch/incoming"
}

# Serialize package changes in a destination, including path aliases.
# acquire_package_lock destination-root
acquire_package_lock() {
    local parent suffix canonical key lock attempts

    parent=${1:-/}
    suffix=
    while [ ! -d "$parent" ]; do
        suffix="/${parent##*/}$suffix"
        parent=${parent%/*}
        [ -n "$parent" ] || parent=/
    done
    canonical=$(cd "$parent" && pwd -P)
    canonical="${canonical%/}$suffix"
    [ -n "$canonical" ] || canonical=/
    key=$(printf '%s' "$canonical" | cksum | awk '{print $1}')
    # Coordination must not depend on a caller-specific TMPDIR.
    lock="/tmp/uports-pkg-add.$(id -u).$key"
    attempts=0
    until mkdir "$lock" 2>/dev/null; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 30 ]; then
            echo "Package operation lock timed out: $lock" >&2
            exit 1
        fi
        sleep 1
    done
    printf '%s\n' "$lock"
}

do_add() {
    local quiet strip pkgname db name ver path prefix index compress ext
    local pver sep p_start provenance_end plist_line payload_line
    local tmpdir root install_lock

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
    install_lock=
    trap 'rm -rf -- "$tmpdir"; [ -z "$install_lock" ] ||
        rmdir -- "$install_lock"' EXIT
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
                /*/../*|*/./*|*//*|*[[:space:]\|]*)
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
    # Inspect the actual payload in private storage before destination writes.
    mkdir "$tmpdir/stage"
    tar -xJf "$tmpdir/payload" -C "$tmpdir/stage"
    check_plist "$tmpdir/stage" "$tmpdir/plist" "$prefix"
    # Preserve runtime PREFIX; DESTDIR is only the installation root.
    if [ -n "$strip" ]; then
        prefix=/
        awk -F '|' '
            $1 == "path" {print $2}
            $1 == "dir" {print "@dir " $2}
            $1 == "cleanup" {print "@rmdir " $2}
            ' "$tmpdir/records" > "$tmpdir/plist"
    fi
    db="$DESTDIR/var/db"
    root="$DESTDIR${prefix%/}"
    [ -n "$root" ] || root=/
    install_lock=$(acquire_package_lock "$DESTDIR")
    check_install_conflicts "$tmpdir" "$name" "$prefix"
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
    rmdir -- "$install_lock"
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

# Build complete removal plans before deleting any package files.
# plan_package_removals scratch-directory
plan_package_removals() {
    local scratch number entry owner prefix manifest kind file target dir

    scratch=$1
    number=0
    cp "$scratch/owners" "$scratch/remaining"
    : > "$scratch/plans"
    while IFS= read -r entry
    do
        number=$((number + 1))
        owner=$(printf '%s\n' "$entry" | awk '{sub(/:$/, "", $1); print $1}')
        prefix=$(printf '%s\n' "$entry" | awk '{print $4}')
        manifest=$(printf '%s\n' "$entry" | awk '{print $NF}')
        parse_plist "$prefix" "$DESTDIR/var/db/$manifest" \
            > "$scratch/records"
        awk -F '|' -v owner="$owner" '$2 != owner' \
            "$scratch/remaining" > "$scratch/after"
        awk -F '|' '
        {
            path = $1
            while (path != "" && path != "/") {
                print path
                sub(/\/[^/]*$/, "", path)
            }
        }
        ' "$scratch/after" > "$scratch/protected"
        # Administrative records are removed only by registration updates.
        printf '/var/db/pkg\n' >> "$scratch/protected"
        awk '{print "/var/db/" $NF}' "$DESTDIR/var/db/pkg" \
            >> "$scratch/protected"
        : > "$scratch/candidates"
        : > "$scratch/dirs"
        while IFS='|' read -r kind file
        do
            file="${prefix%/}/${file#./}"
            target="$DESTDIR$file"
            check_package_parents "$target" Removal
            if [ "$kind" != path ] ||
                { [ -d "$target" ] && [ ! -L "$target" ]; }; then
                printf '%s\n' "$file" >> "$scratch/dirs"
            else
                printf 'remove|%s\n' "$file" >> "$scratch/candidates"
                dir=${file%/*}
                while [ "$dir" != "${prefix%/}" ] &&
                    [ "$dir" != / ] && [ -n "$dir" ]; do
                    printf '%s\n' "$dir" >> "$scratch/dirs"
                    dir=${dir%/*}
                done
            fi
        done < "$scratch/records"
        awk '{print length($0) "|" $0}' "$scratch/dirs" | sort -rn |
            cut -d'|' -f2- | awk '!seen[$0]++ {print "rmdir|" $0}' \
            >> "$scratch/candidates"
        awk -F '|' '
        FILENAME == ARGV[1] {protected[$0] = 1; next}
        {
            action = ($2 in protected) ? "keep" : $1
            record = action "|" $2
            if (!seen[record]++) print record
        }
        ' "$scratch/protected" "$scratch/candidates" \
            > "$scratch/plan.$number"
        printf '%s|%s|%s\n' "$number" "$owner" "$manifest" \
            >> "$scratch/plans"
        mv "$scratch/after" "$scratch/remaining"
    done < "$scratch/selected"
}

do_delete()
{
    local quiet dryrun all p plist fname action entry installed number
    local tmpdir names package_lock

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
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/uports-pkg-delete.XXXXXX")
    package_lock=
    trap 'rm -rf -- "$tmpdir"; [ -z "$package_lock" ] ||
        rmdir -- "$package_lock"' EXIT
    package_lock=$(acquire_package_lock "$DESTDIR")
    if [ -f "$DESTDIR/var/db/pkg" ]; then
        if [ "$all" -eq 1 ]; then
            names=$(awk '{sub(/:$/, "", $1); print $1}' \
                "$DESTDIR/var/db/pkg")
        else
            names=$1
        fi
        : > "$tmpdir/matches"
        for p in $names
        do
            match_packages "$p" "$DESTDIR/var/db/pkg" >> "$tmpdir/matches"
        done
        awk '!seen[$0]++' "$tmpdir/matches" > "$tmpdir/selected"
        if [ -s "$tmpdir/selected" ]; then
            collect_package_owners "$DESTDIR/var/db" "$tmpdir"
            plan_package_removals "$tmpdir"
            while IFS='|' read -r number installed plist
            do
                while IFS='|' read -r action entry
                do
                    fname="$DESTDIR$entry"
                    case "$action" in
                        keep)
                            if [ "$quiet" -eq 0 ] || [ "$dryrun" -eq 1 ]; then
                                printf 'keep %s (other package ownership)\n' \
                                    "$fname"
                            fi
                            ;;
                        remove)
                            if [ "$dryrun" -eq 1 ]; then
                                printf 'rm -f %s\n' "$fname"
                            else
                                [ "$quiet" -eq 1 ] || \
                                    printf 'delete %s\n' "$fname"
                                rm -f -- "$fname"
                            fi
                            ;;
                        rmdir)
                            if [ "$dryrun" -eq 1 ]; then
                                printf 'rmdir %s\n' "$fname"
                            else
                                rmdir -- "$fname" 2>/dev/null || :
                            fi
                            ;;
                    esac
                done < "$tmpdir/plan.$number"
                if [ "$dryrun" -ne 1 ]; then
                    rm -f -- "$DESTDIR/var/db/$plist"
                    awk -v name="$installed:" '$1 != name' \
                        "$DESTDIR/var/db/pkg" > "$tmpdir/db"
                    cp "$tmpdir/db" "$DESTDIR/var/db/pkg"
                fi
            done < "$tmpdir/plans"
        fi
        if [ "$dryrun" -ne 1 ] && [ ! -s "$DESTDIR/var/db/pkg" ]; then
            rm -f -- "$DESTDIR/var/db/pkg"
        fi
    fi
    rm -rf -- "$tmpdir"
    rmdir -- "$package_lock"
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
