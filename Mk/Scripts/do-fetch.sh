#!/bin/sh
# Archive executor following FreeBSD ports' procedural do-fetch.sh model.
# Reference: ecc6a37c0d3d10f3a9212be604f70f720cf4b9d6, portmgr@FreeBSD.org.
#
# Copyright (C) 1994-2022 The FreeBSD Project.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -eu
set -f

die() { printf '  ERR     %s\n' "$*" >&2; exit 1; }
for name in dp_DISTDIR dp_DIST_SUBDIR dp_DISTINFO_FILE dp_SITE_FLAVOR \
    dp_TARGET dp_FETCH_CMD dp_FETCH_TOOL dp_FETCH_TIMEOUT dp_FETCH_REGET; do
    eval 'test "${'"$name"'+set}" = set' || die "$name is undefined"
done
case $dp_TARGET in do-fetch|fetch-list|fetch-url-list) ;;
    *) die "unsupported fetch target: $dp_TARGET" ;; esac
case $dp_SITE_FLAVOR in MASTER) prefix=_MASTER_SITES ;; PATCH) prefix=_PATCH_SITES ;;
    *) die "unsupported site flavor: $dp_SITE_FLAVOR" ;; esac
case $dp_FETCH_TIMEOUT in ''|*[!0-9]*|0) die 'FETCH_TIMEOUT must be positive' ;;
esac
case $dp_FETCH_REGET in ''|*[!0-9]*|0) die 'FETCH_REGET must be positive' ;;
esac

temporary=
cleanup() { [ -z "$temporary" ] || rm -f -- "$temporary"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

sha256_file() {
    if command -v sha256 >/dev/null 2>&1; then sha256 -q "$1"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else shasum -a 256 "$1" | awk '{print $1}'; fi
}

quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# Stable preference buckets; overrides and backup are kept outside sorting.
order_sites() {
    FETCH_SORT=${dp_MASTER_SORT:-} FETCH_REGEX=${dp_MASTER_SORT_REGEX:-} \
    FETCH_RANDOM=${dp_RANDOMIZE_SITES:-no} awk '
    BEGIN {
        nd=split(ENVIRON["FETCH_SORT"],domains," ")
        nr=split(ENVIRON["FETCH_REGEX"],patterns," ")
        randomize=(ENVIRON["FETCH_RANDOM"] == "yes")
        if (randomize) srand()
    }
    {
        for (i=1;i<=NF;i++) {
            url=$i; host=tolower(url)
            sub("^[^:]*://", "", host); sub("/.*$", "", host)
            sub("^.*@", "", host); sub(":[0-9]+$", "", host)
            bucket=nr+nd+1
            for (j=1;j<=nd;j++) {
                d=tolower(domains[j]); n=length(host)-length(d)
                if (host==d || (n>0 && substr(host,n,1)=="." &&
                    substr(host,n+1)==d)) { bucket=nr+j; break }
            }
            for (j=1;j<=nr;j++) if (url ~ patterns[j]) {bucket=j;break}
            urls[++count]=url; ranks[count]=bucket
            keys[count]=(randomize ? rand() : count)
        }
    }
    END {
        for (k=1;k<=count;k++) {
            best=0
            for (i=1;i<=count;i++) if (!used[i] && (!best ||
                ranks[i]<ranks[best] || (ranks[i]==ranks[best] &&
                keys[i]<keys[best]))) best=i
            used[best]=1; print urls[best]
        }
    }'
}

# Commands/options/environment are whitespace-delimited words, never eval code.
# Explicit backend output options prevent redirects from choosing cache names.
download() {
    case $dp_FETCH_TOOL in
        wget)
            set -- --timeout="$dp_FETCH_TIMEOUT" --tries="$dp_FETCH_REGET"
            [ "${dp_NO_CHECK_CERTIFICATE:-no}" != yes ] ||
                set -- "$@" --no-check-certificate
            set -- "$@" -O "$temporary" -- "$url"
            ;;
        curl)
            set -- --fail --location --max-time "$dp_FETCH_TIMEOUT" \
                --retry "$((dp_FETCH_REGET - 1))" \
                --retry-max-time "$dp_FETCH_TIMEOUT"
            [ "${dp_NO_CHECK_CERTIFICATE:-no}" != yes ] ||
                set -- "$@" --insecure
            set -- "$@" --output "$temporary" --url "$url"
            ;;
        *) die "FETCH_TOOL must be wget or curl" ;;
    esac
    env ${dp_FETCH_ENV:-} $dp_FETCH_CMD ${dp_FETCH_BEFORE_ARGS:-} \
        ${dp_FETCH_AFTER_ARGS:-} "$@"
}

# Preserve the old fetch-sanity behavior even for an empty file list.
[ "$dp_TARGET" != do-fetch ] || mkdir -p -- "$dp_DISTDIR"

for declaration do
    file=${declaration%%:*}
    case $file in ''|/*|../*|*/../*|*/..|..|./*|*/./*|*/.|.|-*)
        die "unsafe distfile name: $file" ;; esac
    case $file in *[![:print:]]*) die "invalid distfile name" ;; esac
    groups=DEFAULT
    [ "$declaration" = "$file" ] ||
        groups=$(printf '%s' "${declaration#*:}" | tr ',' ' ')
    selected=
    for group in $groups; do
        case $group in ''|*[!A-Za-z0-9_]*) die "invalid group: $group" ;;
        esac
        eval 'mirrors=${'"${prefix}_${group}"'-}'
        [ -n "$mirrors" ] || [ "$group" = DEFAULT ] ||
            die "missing $dp_SITE_FLAVOR sites group: $group"
        selected="$selected $mirrors"
    done
    selected=$(printf '%s\n' "$selected" | order_sites)
    sites="${dp_MASTER_SITE_OVERRIDE:-} $selected ${dp_MASTER_SITE_BACKUP:-}"
    destination=$dp_DISTDIR/$file
    case $dp_TARGET in
        fetch-url-list)
            for site in $sites; do printf '%s\n' "$site$file"; done
            continue ;;
        fetch-list)
            # Print safe, executable invocations of this same atomic executor.
            for name in dp_DISTDIR dp_DIST_SUBDIR dp_DISTINFO_FILE \
                dp_SITE_FLAVOR dp_FETCH_CMD dp_FETCH_TOOL dp_FETCH_TIMEOUT \
                dp_FETCH_REGET dp_FETCH_ENV dp_FETCH_BEFORE_ARGS \
                dp_FETCH_AFTER_ARGS dp_FORCE_FETCH_ALL dp_FORCE_FETCH_LIST \
                dp_NO_CHECKSUM dp_DISABLE_SIZE dp_DISTINFO_REQUIRED \
                dp_NO_CHECK_CERTIFICATE dp_MASTER_SITE_OVERRIDE \
                dp_MASTER_SITE_BACKUP dp_MASTER_SORT dp_MASTER_SORT_REGEX \
                dp_RANDOMIZE_SITES; do
                eval 'value=${'"$name"'-}'
                printf '%s=' "$name"; quote "$value"; printf ' '
            done
            for group in $groups; do
                eval 'value=${'"${prefix}_${group}"'-}'
                printf '%s=' "${prefix}_${group}"
                quote "$value"; printf ' '
            done
            printf 'dp_TARGET=do-fetch /bin/sh '; quote "$0"
            printf ' '; quote "$declaration"; printf '\n'
            continue ;;
    esac
    force=${dp_FORCE_FETCH_ALL:-no}
    for candidate in ${dp_FORCE_FETCH_LIST:-}; do
        [ "${candidate##*/}" != "${file##*/}" ] || force=yes
    done
    if [ -f "$destination" ] && [ "$force" != yes ]; then continue; fi
    # Legacy basename cache lookup, retained for existing nested distfiles.
    if [ -f "$dp_DISTDIR/${file##*/}" ] && [ "$force" != yes ]; then
        continue
    fi
    [ ! -L "$destination" ] || die "symlink fetch destination: $destination"
    [ ! -e "$destination" ] || [ -f "$destination" ] ||
        die "not a regular cache file: $destination"
    key=${dp_DIST_SUBDIR:+$dp_DIST_SUBDIR/}$file
    expected_size= expected_sha=
    if [ "${dp_NO_CHECKSUM:-no}" != yes ]; then
        if [ -f "$dp_DISTINFO_FILE" ]; then
            expected_size=$(awk -v k="($key)" \
                '$1=="SIZE" && $2==k && $3=="=" {print $4}' \
                "$dp_DISTINFO_FILE")
            expected_sha=$(awk -v k="($key)" \
                '$1=="SHA256" && $2==k && $3=="=" {print $4}' \
                "$dp_DISTINFO_FILE")
            [ -n "$expected_size" ] && [ -n "$expected_sha" ] ||
                die "distinfo missing entry for $key"
        elif [ "${dp_DISTINFO_REQUIRED:-no}" = yes ]; then
            die "missing distinfo: $dp_DISTINFO_FILE"
        fi
    fi
    mkdir -p -- "${destination%/*}"
    [ -w "${destination%/*}" ] || die "cache is not writable: $destination"
    temporary=$(mktemp "${destination%/*}/.fetch.XXXXXXXX")
    success=no
    for site in $sites; do
        url=$site$file
        printf '  FETCH   %s\n' "$url"
        if download; then
            actual_size=$(wc -c < "$temporary" | tr -d '[:space:]')
            if [ "${dp_DISABLE_SIZE:-no}" != yes ] &&
                [ -n "$expected_size" ] &&
                [ "$actual_size" != "$expected_size" ]; then
                printf '  RETRY   SIZE mismatch: %s\n' "$key" >&2
                continue
            fi
            if [ -n "$expected_sha" ] &&
                [ "$(sha256_file "$temporary")" != "$expected_sha" ]; then
                printf '  RETRY   SHA256 mismatch: %s\n' "$key" >&2
                continue
            fi
            # Concurrent writers publish only complete verified files.
            [ ! -L "$destination" ] || die "cache became a symlink"
            # mktemp starts at 0600; respect umask for shared-cache readers.
            chmod +r "$temporary"
            mv -f -- "$temporary" "$destination"
            temporary= success=yes
            break
        fi
    done
    [ "$success" = yes ] || die "could not fetch $file into $dp_DISTDIR"
done
