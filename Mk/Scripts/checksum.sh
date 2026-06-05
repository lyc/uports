#!/bin/sh
# uPorts/Mk/Scripts/checksum.sh - verify distinfo checksums

set -e

checksum_usage() {
    echo "Usage: checksum.sh" >&2
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

[ $# -eq 0 ] || checksum_usage
validate_env DISTINFO_FILE DISTINFO_REQUIRED _DISTDIR ALLFILES DIST_SUBDIR

case "${DISTINFO_FILE}" in
    /*) distinfo_file=${DISTINFO_FILE} ;;
    *) distinfo_file=`pwd`/${DISTINFO_FILE} ;;
esac

if [ ! -f "${distinfo_file}" ]; then
    if [ "${DISTINFO_REQUIRED}" = "yes" ]; then
        echo "  ERR     missing distinfo: ${DISTINFO_FILE}"
        exit 1
    fi
    echo "  SKIP    distinfo missing; run make makesum"
    exit 0
fi

cd "${_DISTDIR}"

for f in ${ALLFILES}; do
    key=`distinfo_key "$f"`
    file=`find_distfile "$f"` || {
        echo "  ERR     missing distfile for checksum: $f"
        exit 1
    }

    expected_sha=`awk -v k="$key" '$1 == "SHA256" && $2 == "(" k ")" && $3 == "=" { print $4 }' "${distinfo_file}"`
    expected_size=`awk -v k="$key" '$1 == "SIZE" && $2 == "(" k ")" && $3 == "=" { print $4 }' "${distinfo_file}"`
    if [ -z "${expected_sha}" ] || [ -z "${expected_size}" ]; then
        echo "  ERR     distinfo missing entry for ${key}"
        exit 1
    fi

    actual_sha=`sha256_file "$file"`
    actual_size=`size_file "$file"`

    if [ "${actual_sha}" != "${expected_sha}" ]; then
        echo "  ERR     SHA256 mismatch for ${key}"
        echo "          expected ${expected_sha}"
        echo "          actual   ${actual_sha}"
        exit 1
    fi

    if [ "${actual_size}" != "${expected_size}" ]; then
        echo "  ERR     SIZE mismatch for ${key}"
        echo "          expected ${expected_size}"
        echo "          actual   ${actual_size}"
        exit 1
    fi

    echo "  CHKSUM  ${key}"
done
