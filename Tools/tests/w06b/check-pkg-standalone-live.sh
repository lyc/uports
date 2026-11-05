#!/bin/bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
framework=$(cd "$script_dir/../../.." && pwd)
project=$(cd "${1:-$framework/../..}" && pwd)
testdir=$(mktemp -d /tmp/uports-w06b-manual.XXXXXX)
log="$testdir/validation.log"
printf '%s\n' "$testdir" > /tmp/uports-w06b-latest
printf 'Evidence: %s\n' "$testdir"
exec > >(tee "$log") 2>&1

finish() {
    status=$?
    printf '\nexit=%s\nLog: %s\n' "$status" "$log"
    exit "$status"
}
trap finish EXIT

printf 'Project: %s\n' "$project"
printf 'Framework: %s\n' "$framework"
printf 'Started: %s\n' "$(date -Is)"
cp "$framework/Mk/Scripts/pkg.sh" "$testdir/pkg.sh"
tool="$testdir/pkg.sh"
cd "$testdir"

for selected in default libffcall; do
    work="$project/feeds/lang/gforth/work.compiler"
    name=gforth
    if [ "$selected" = libffcall ]; then
        work="$work.flavor-libffcall"
        name=gforth-libffcall
    fi
    [ -d "$work/stage/usr/local" ] &&
        [ -r "$work/.PLIST.resolved" ] || {
        printf 'Missing real staged gforth files: %s\n' "$work" >&2
        exit 1
    }

    case_dir="$testdir/$selected"
    mkdir "$case_dir"
    export STAGEDIR="$work/stage" PREFIX=/usr/local
    export PKGNAME="$name-0.7.9" VERSION=0.7.9 ORIGIN=lang/gforth
    export INDEX=devel COMPRESS=XZ EXT=linux-x86_64
    export PLIST="$case_dir/manifest" DESTDIR="$case_dir/install"
    export WRKDIR_PKGFILE="$case_dir/$PKGNAME.pkg"
    export PROVENANCE= PACKAGE_BUILD_ID=

    printf '\nChecking %s\n' "$selected"
    sed \
        -e 's|^\./share/man$|@dir share/man|' \
        -e 's|^\./share/man/man1$|@rmdir ./share/man/man1|' \
        "$work/.PLIST.resolved" > "$PLIST"
    grep -qx '@dir share/man' "$PLIST"
    grep -qx '@rmdir ./share/man/man1' "$PLIST"
    printf '%s\n' \
        '@comment ignored text' \
        '@rmdir share/gforth/.w06b-old' \
        '@rmdir /usr/local/share/gforth/.w06b-old-absolute' >> "$PLIST"
    cp "$PLIST" "$case_dir/valid-manifest"

    "$tool" check-plist "$STAGEDIR$PREFIX" "$PLIST" "$PREFIX"
    "$tool" create
    sha256sum "$WRKDIR_PKGFILE" > "$case_dir/before.sha256"

    for bad in \
        '@exec do-not-run' '@dir ../escape' '@rmdir /etc/escape'; do
        cp "$case_dir/valid-manifest" "$PLIST"
        printf '%s\n' "$bad" >> "$PLIST"
        if "$tool" create; then
            printf 'FAIL: accepted %s\n' "$bad" >&2
            exit 1
        else
            printf 'Expected rejection: %s (exit=%s)\n' "$bad" "$?"
        fi
        sha256sum -c "$case_dir/before.sha256"
    done
    cp "$case_dir/valid-manifest" "$PLIST"

    "$tool" add -q "$WRKDIR_PKGFILE"
    "$tool" info -e "$name"
    "$tool" delete -n "$name" > "$case_dir/preview.log"
    test -e "$DESTDIR/usr/local/bin/gforth"
    printf 'preserve\n' > "$DESTDIR/usr/local/share/man/w06b-user-file"
    "$tool" delete -q "$name"
    test ! -e "$DESTDIR/usr/local/bin/gforth"
    test ! -L "$DESTDIR/usr/local/bin/gforth"
    test -f "$DESTDIR/usr/local/share/man/w06b-user-file"
    if "$tool" info -e "$name"; then
        printf 'FAIL: package registration survived removal\n' >&2
        exit 1
    fi
    printf 'PASS: %s\n' "$selected"
done

printf '\nPASS: W06B standalone package checks\n'
