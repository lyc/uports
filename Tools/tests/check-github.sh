#!/bin/sh
set -eu
testdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
portdir=$(CDPATH= cd -- "$testdir/../.." && pwd)
probe() {
    make --no-print-directory -s -C "$testdir/cases/github" \
        PORTSDIR="$portdir" "$@" snapshot
}
contains() {
    printf '%s\n' "$1" | grep -F -x -- "$2" >/dev/null || {
        printf 'missing GitHub contract: %s\n' "$2" >&2
        exit 1
    }
}
snapshot=$(probe)
contains "$snapshot" 'account=demo'
contains "$snapshot" 'project=demo'
contains "$snapshot" 'tag=1.2'
contains "$snapshot" 'name=demo-demo-1.2_GH0'
contains "$snapshot" 'files=demo-demo-1.2_GH0.tar.gz'
contains "$snapshot" 'source=demo-1.2'
contains "$snapshot" 'urls=https://codeload.github.com/demo/demo/tar.gz/1.2?dummy=/'
tagged=$(probe GH_ACCOUNT=owner GH_PROJECT=project GH_TAGNAME=v2.0+rc--1)
contains "$tagged" 'name=owner-project-1.2-v2.0+rc--1_GH0'
contains "$tagged" 'source=project-2.0-rc-1'
slashed=$(probe GH_TAGNAME=release/v2.0)
contains "$slashed" 'sanitized=release-v2.0'
contains "$slashed" 'source=demo-release-v2.0'
commit=0123456789abcdef0123456789abcdef01234567
pinned=$(probe GH_TAGNAME="$commit")
contains "$pinned" "name=demo-demo-1.2-${commit}_GH0"
overridden=$(probe DISTNAME=custom DISTFILES=custom.tar.gz WRKSRC=/custom/tree \
    MASTER_SITES=https://mirror.invalid/)
contains "$overridden" 'name=custom'
contains "$overridden" 'files=custom.tar.gz'
contains "$overridden" 'source=tree'
contains "$overridden" 'urls=https://mirror.invalid/'
extra=$(probe --eval='DISTFILES = license.txt:extra')
contains "$extra" 'files=license.txt:extra demo-demo-1.2_GH0.tar.gz'
for setting in GH_TAGNAME=master GH_TAGNAME=main GH_TAGNAME=HEAD \
    GH_TAGNAME=refs/heads/feature GH_ACCOUNT=owner:default \
    GH_TAGNAME=version:all USE_GITHUB=invalid GH_TUPLE=owner:project \
    GH_SUBDIR=../escape MASTER_SITES=GH:extra; do
    if probe "$setting" >/dev/null 2>&1; then
        echo "invalid/unimplemented GitHub declaration accepted: $setting" >&2
        exit 1
    fi
done
legacy=$(probe USE_SCM=git MASTER_SITES=git.invalid SCM_PROTOCOL=https:// \
    MASTER_SITE_SUBDIR=owner)
contains "$legacy" 'name=demo-1.2'
contains "$legacy" 'source=demo-1.2'
printf '%s\n' 'GitHub archive metadata contract: passed'
