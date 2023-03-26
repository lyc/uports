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
#   sed --in-place operation will be failed inside aarch64 docker environment
#    sed -i -e "/${name}/d" ${db}/pkg > ${tmp}
    tmp=`mktemp`
    sed -e "/${name}/d" ${db}/pkg > ${tmp}
    cp ${tmp} ${db}/pkg
    rm ${tmp}
    echo "$name: $ver $path $prefix \"${index}\" ${name}-pkg-plist.${ext}" >> ${db}/pkg

    # copy pkg-plist.$EXT to $db
    sed -n -e "${p_start},/^${sep}/p" $pkgname | grep -v $sep > $plist

    return ${rc}
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

    if [ -f ${db}/pkg ]; then
        info=`cat ${db}/pkg | grep $pkgname`
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
    local rc destdir db
    local quiet force all dryrun pkgname

#    echo "do_delete ..."

    rc=0
    destdir=$DESTDIR
    db=${destdir}/var/db

#    echo "2==>$*"
#    echo destdir=$destdir
#    echo db=$db

    all=0
    dryrun=0
    quiet=0
    force=0
    while getopts afnq OPT
    do
        case "$OPT" in
            a) eval all=1 ;;
            f) eval force=1 ;;
            n) eval dryrun=1 ;;
            q) eval quiet=1 ;;
            *) echo >&2 "Usage: pkg delete [ -afnq ] pkgname"; exit 1 ;;
        esac
    done

#    echo all=$all
#    echo quiet=$quiet
#    echo force=$force

    if [ $OPTIND -gt 1 ]; then
        shiftcount=`expr $OPTIND - 1`
        shift $shiftcount
    fi

#    echo "3==>$*"
#    echo 0=$0
#    echo 1=$1

    if [ $all -ne 1 ]; then
        pkgname=$1
        if [ -z $pkgname ]; then
            echo >&2 "Usage: pkg delete [ -afnq ] pkgname"; exit 1
        fi
    fi

    if [ -f ${db}/pkg ]; then
        local info plist prefix fname size

        # prepare pkgname for delete...
        if [ $all -eq 1 ]; then
            pkgname=`cat ${db}/pkg | awk '{ print $1 }' | sed -e 's/://g'`
        fi

        # do delete pkgname ...
        for p in $pkgname; do
#            echo pkgname=$p
            info=`cat ${db}/pkg | grep $p`
            if [ ! -z "$info" ]; then
                plist=${db}/`echo $info | awk '{ print $6 }'`
                prefix=`echo $info | awk '{ print $4 }'`
                if [ -f $plist ]; then
#                    echo plist=$plist
#                    echo prefix=$prefix
                    if [ $quiet -ne 1 ]; then
                        echo "delete $p ..."
                    fi
                    for f in `cat $plist`; do
                        case $f in
                            .*)
                                fname=$destdir$prefix/$f
                                ;;
                            @rmdir*)
                                ;;
                        esac
                        if [ -f $fname ] || [ -h $fname ] || [ -c $fname ]; then
                            if [ $dryrun -eq 1 ]; then
                                echo rm -fr $fname
                            else
                                rm -fr $fname
                            fi
                        fi
                    done
                    if [ $dryrun -eq 1 ]; then
                        echo rm -fr $plist
                    else
                        rm -fr $plist
                    fi
                fi
                if [ $dryrun -eq 1 ]; then
#                    echo sed -i -e "/^$p/d" ${db}/pkg
                    echo sed -e "/^$p/d" ${db}/pkg > ${tmp}
                else
#                    sed -i -e "/^$p/d" ${db}/pkg
                    tmp=`mktemp`
                    sed -e "/^$p/d" ${db}/pkg > ${tmp}
                    cp ${tmp} ${db}/pkg
                    rm ${tmp}
                fi
            fi
        done

        # delete ${db}/pkg if empty...
        size=`ls -al ${db}/pkg | awk '{ print $5 }'`
        if [ $size -eq 0 ]; then
            rm -fr ${db}/pkg
        fi
    fi
    return ${rc}
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
args=$*

# echo "1==>$*"

if [ ${create} -eq 1 ]; then
    # validate environment
    validate_env STAGEDIR PKGNAME VERSION ORIGIN PREFIX INDEX COMPRESS EXT PLIST WRKDIR_PKGFILE

    do_create
else
    validate_env DESTDIR

    if [ ${add} -eq 1 ]; then
        do_add $args
    fi
    if [ ${delete} -eq 1 ]; then
        do_delete $args
    fi
    if [ ${info} -eq 1 ]; then
        do_info $args || ret=1
    fi
    if [ ${version} -eq 1 ]; then
        do_version $args
    fi
fi

# echo ret=$ret
exit ${ret}
