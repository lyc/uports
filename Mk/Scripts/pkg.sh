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

# obtain operating mode from command line
ret=0
create=0
case "$1" in
    create) create=1 ;;
    *) echo >&2 "Usage: $0 create" ; exit 1 ;;
esac

if [ ${create} -eq 1 ]; then
    # validate environment
    validate_env STAGEDIR PKGNAME VERSION ORIGIN PREFIX INDEX COMPRESS EXT PLIST WRKDIR_PKGFILE

    do_create
fi

exit ${ret}
