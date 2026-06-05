#!/bin/sh
# uPorts/Mk/Scripts/makesum.sh - generate distinfo checksums

set -e

makesum_usage() {
    echo "Usage: makesum.sh" >&2
    exit 1
}

validate_env() {
    envfault=
    for i do
        set -f
        if ! (eval ": \${${i}?}") >/dev/null 2>&1; then
            envfault="${envfault}${envfault:+" "}${i}"
        fi
        set +f
    done
    if [ -n "${envfault}" ]; then
        echo "Environment variable ${envfault} undefined. Aborting." | fmt >&2
        exit 1
    fi
}

sha256_file() {
    file=$1

    if command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$file"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{ print $1 }'
    else
        shasum -a 256 "$file" | awk '{ print $1 }'
    fi
}

size_file() {
    wc -c < "$1" | tr -d ' '
}

distinfo_key() {
    file=$1

    if [ -n "${DIST_SUBDIR}" ]; then
        echo "${DIST_SUBDIR}/${file}"
    else
        echo "${file}"
    fi
}

find_distfile() {
    file=$1

    if [ -f "$file" ]; then
        echo "$file"
        return 0
    fi

    base=`basename "$file"`
    if [ -f "$base" ]; then
        echo "$base"
        return 0
    fi

    return 1
}

[ $# -eq 0 ] || makesum_usage
validate_env DISTINFO_FILE _DISTDIR ALLFILES DIST_SUBDIR

case "${DISTINFO_FILE}" in
    /*) distinfo_file=${DISTINFO_FILE} ;;
    *) distinfo_file=`pwd`/${DISTINFO_FILE} ;;
esac

tmp=`mktemp`
trap 'rm -f "${tmp}"' EXIT HUP INT TERM

echo "  MKSUM   ${DISTINFO_FILE}"
echo "TIMESTAMP = `date +%s`" > "${tmp}"

cd "${_DISTDIR}"

for f in ${ALLFILES}; do
    key=`distinfo_key "$f"`
    file=`find_distfile "$f"` || {
        echo "  ERR     missing distfile for makesum: $f"
        exit 1
    }

    actual_sha=`sha256_file "$file"`
    actual_size=`size_file "$file"`

    echo "SHA256 (${key}) = ${actual_sha}" >> "${tmp}"
    echo "SIZE (${key}) = ${actual_size}" >> "${tmp}"
done

mv "${tmp}" "${distinfo_file}"
trap - EXIT HUP INT TERM
