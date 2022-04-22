#!/bin/sh
# uPorts/Mk/Scripts/pkg.sh - called from uPorts/Mk/linuxl.port.post.mk
#
# MAINTAINER: yowching@gmail.com
#
# This script serves for pkg manipulation

set -e

validate_env() {
    local envfault
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

# (L1) PVER: always "1"
# (L2) NAME: pacakge name
# (L3) VER: package version
# (L4) PATH: The path of port directory
# (L5) PREFIX: prefix
# (L6) INDEX: The categories this port is part of
# (L7) COMPRESS: XZ (only support XZ format now)
# (L8) EXT: extension of pkg-plist.EXT file
# (L9) PLIST: %%%%% (separator, can be any)
#      ... (content of pkg-plist.EXT)
#      ... (multiple lines)
#      ...
#      %%%%% (end of pkg-plist.EXT, must same as separator defined in previously)
#      TXZ BLOB

do_create() {
    local rc

    rc=0

    echo "PVER: 1"              > $WRKDIR_PKGFILE
    echo "NAME: $PKGNAME"      >> $WRKDIR_PKGFILE
    echo "VER: $VERSION"       >> $WRKDIR_PKGFILE
    echo "PATH: $ORIGIN"       >> $WRKDIR_PKGFILE
    echo "PREFIX: $PREFIX"     >> $WRKDIR_PKGFILE
    echo "INDEX: $INDEX"       >> $WRKDIR_PKGFILE
    echo "COMPRESS: $COMPRESS" >> $WRKDIR_PKGFILE
    echo "EXT: $EXT"           >> $WRKDIR_PKGFILE
    echo "PLIST: %%%%%"        >> $WRKDIR_PKGFILE
    cat $PLIST                 >> $WRKDIR_PKGFILE
    echo "%%%%%"               >> $WRKDIR_PKGFILE
    case "$COMPRESS" in
        XZ)
            cd $STAGEDIR/$PREFIX && tar Jc * >> $WRKDIR_PKGFILE ;;
    esac

    return ${rc}
}

do_add() {
    local rc destdir db
    local quiet pkgname
    local pver name ver path prefix index compress ext sep p_start plist txz

    rc=0
    destdir=$DESTDIR
    db=${destdir}/var/db

#    echo "==>$*"
#    echo destdir=$destdir
#    echo db=$db

    quiet=
    pkgname=

    while getopts oq OPT
    do
        case "$OPT" in
            q) eval quiet=1 ;;
            *) echo >&2 "Usage: pkg add [ -q ] pkgname"; exit 1 ;;
        esac
    done

#    echo quiet=$quiet

#    echo OPTIND=$OPTIND
    if [ $OPTIND -gt 1 ]; then
        shiftcount=`expr $OPTIND - 1`
        shift $shiftcount
    fi

#    echo 0=$0
    pkgname=$1
    if [ -z "$pkgname" ]; then
	echo "Usage: $0 add [ -q ] {pkgname} " ; exit 1
    fi
#    echo pkgname=$pkgname

    pver=`sed -n -e '1p' $pkgname | awk '{ print $2 }'`
    if [ $pver -eq 1 ]; then
        name=`sed -n -e '2p' $pkgname | awk '{ print $2 }'`
        ver=`sed -n -e '3p' $pkgname | awk '{ print $2 }'`
        path=`sed -n -e '4p' $pkgname | awk '{ print $2 }'`
        prefix=`sed -n -e '5p' $pkgname | awk '{ print $2 }'`
        index=`sed -n -e '6p' $pkgname | awk '{ print $2 }'`
        compress=`sed -n -e '7p' $pkgname | awk '{ print $2 }'`
        ext=`sed -n -e '8p' $pkgname | awk '{ print $2 }'`
        sep=`sed -n -e '9p' $pkgname | awk '{ print $2 }'`
        p_start=10
    else
	echo >&2 "Unsupported pkg format" ; exit 1
    fi
    plist=${db}/${name}-pkg-plist.${ext}
    txz=`mktemp --suffix=$name.txz`

#    echo pver=$pver
#    echo name=$name
#    echo ver=$ver
#    echo path=$path
#    echo prefix=$prefix
#    echo index=$index
#    echo compress=$compress
#    echo ext=$ext
#    echo sep=$sep
#    echo p_start=$p_start
#    echo plist=$plist
#    echo txz=$txz

    if [ ! -d ${destdir}${prefix} ]; then
        mkdir -p ${destdir}${prefix}
    fi

    local topts=
    if [ -z ${quiet} ]; then
        topts="v"
    fi
    sed -e "1,/^${sep}/d" $pkgname > $txz
    case "$compress" in
        XZ)
            (cd ${destdir}${prefix} && tar Jx${topts}f $txz) ;;
    esac
    rm $txz

    if [ ! -d ${db} ]; then
        mkdir -p ${db}
    fi

    # update db
    touch ${db}/pkg
    sed -i -e "/${name}/d" ${db}/pkg
    echo "$name: $ver $path $prefix \"${index}\" ${name}-pkg-plist.${ext}" >> ${db}/pkg

    # copy pkg-plist.$EXT to $db
    sed -n -e "${p_start},/^${sep}/p" $pkgname | grep -v $sep > $plist

    return ${rc}
}

# obtain operating mode from command line
ret=0
add=0
create=0
case "$1" in
    add) add=1 ;;
    create) create=1 ;;
    *) echo >&2 "Usage: $0 {add|create}" ; exit 1 ;;
esac

shift 1
args=$*

if [ ${create} -eq 1 ]; then
    # validate environment
    validate_env STAGEDIR PKGNAME VERSION ORIGIN PREFIX INDEX COMPRESS EXT PLIST WRKDIR_PKGFILE

    do_create
else
    validate_env DESTDIR

    if [ ${add} -eq 1 ]; then
        do_add $args
    fi
fi

exit ${ret}
