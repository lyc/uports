#!/bin/sh
# Compatibility baseline only. Intentional alignment changes must update tests.
set -eu
testdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
portdir=$(CDPATH= cd -- "$testdir/../.." && pwd)
probe() {
    make --no-print-directory -s -C "$testdir/cases/fetch-contract" \
        PORTSDIR="$portdir" "$@"
}
contains() {
    printf '%s\n' "$1" | grep -F -x -- "$2" >/dev/null || {
        printf 'missing expected fetch contract: %s\n' "$2" >&2
        exit 1
    }
}
snapshot=$(probe snapshot)
contains "$snapshot" 'distfiles=source.tar.gz:src,extra plain.tar.gz:DEFAULT'
contains "$snapshot" 'patchfiles=fix.patch:fix'
contains "$snapshot" 'src=https://dist.invalid:8443/releases/'
contains "$snapshot" 'extra=https://dist.invalid:8443/releases/'
contains "$snapshot" 'default=https://plain.invalid/'
contains "$snapshot" 'patch=https://patch.invalid/fixes/'
ordered=$(probe snapshot MASTER_SITE_OVERRIDE=https://first.invalid/ MASTER_SITE_BACKUP=https://last.invalid/)
contains "$ordered" 'src=https://first.invalid/ https://dist.invalid:8443/releases/ https://last.invalid/'
# Slice 2 preserves the usable mirror base when a subdir is absent.
omitted=$(probe snapshot MASTER_SITE_SUBDIR=)
contains "$omitted" 'src=https://dist.invalid:8443/'
short=$(probe snapshot MASTER_SITES=SF/project/release:src,extra \
    MASTER_SITE_SOURCEFORGE=https://sf.invalid/%SUBDIR%/)
contains "$short" 'src=https://sf.invalid/project/release/'
contains "$short" 'extra=https://sf.invalid/project/release/'
family=$(probe snapshot MASTER_SITES=GNU:src MASTER_SITE_GNU=https://gnu.invalid/%SUBDIR%/ \
    MASTER_SITE_SUBDIR=manual:src)
contains "$family" 'src=https://gnu.invalid/manual/'
default_family=$(probe snapshot MASTER_SITES=GNU MASTER_SITE_GNU=https://gnu.invalid/%SUBDIR%/ \
    OMIT_SUBDIR=yes)
contains "$default_family" 'default=https://gnu.invalid/fetch-contract/'
patch_family=$(probe snapshot PATCH_SITES=SF/patches:fix \
    MASTER_SITE_SOURCEFORGE=https://sf.invalid/%SUBDIR%/ DIST_SUBDIR=another)
contains "$patch_family" 'patch=https://sf.invalid/patches/'
if probe snapshot MASTER_SITES=NOT_A_MIRROR >/dev/null 2>&1; then
    echo 'unknown mirror family unexpectedly accepted' >&2; exit 1
fi
if probe fetch-groups-check DISTFILES=missing.tar.gz:absent >/dev/null 2>&1; then
    echo 'missing distfile group unexpectedly accepted' >&2; exit 1
fi
if probe fetch-groups-check PATCHFILES=missing.patch:absent >/dev/null 2>&1; then
    echo 'missing patchfile group unexpectedly accepted' >&2; exit 1
fi
if probe snapshot MASTER_SITE_SUBDIR=bad:default >/dev/null 2>&1; then
    echo 'reserved subdirectory group unexpectedly accepted' >&2; exit 1
fi
git_snapshot=$(probe snapshot USE_SCM=git MASTER_SITES=git.invalid/ \
    MASTER_SITE_SUBDIR=team SCM_PROTOCOL=https://)
contains "$git_snapshot" 'repo=https://git.invalid/team/fetch-contract.git'
contains "$git_snapshot" 'cache=git.invalid_team_fetch-contract'
contains "$git_snapshot" 'timeout=0'
override=$(probe snapshot USE_SCM=git MASTER_SITES=git.invalid \
    SCM_REPO_URL=https://fork.invalid/project.git SCM_TIMEOUT=15)
contains "$override" 'repo=https://fork.invalid/project.git'
contains "$override" 'timeout=15'
# Inspect the real checkout recipe without running clone or touching worktrees.
checkout=$(probe -n do-extract USE_SCM=git MASTER_SITES=git.invalid \
    SCM_REPO_URL=https://git.invalid/project.git SCM_BRANCH=feature SCM_DETACH=pinned)
case "$checkout" in
    *'if [ ! -z "feature" ]'*'clone -b $branch'*'checkout --detach pinned'*) ;;
    *) echo 'legacy branch/detach checkout structure changed' >&2; exit 1 ;;
esac
if probe snapshot MASTER_SITES=https://invalid/:all >/dev/null 2>&1; then
    echo 'reserved mirror group unexpectedly accepted' >&2
    exit 1
fi
printf '%s\n' 'fetch compatibility contract: passed'
