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
contains "$snapshot" 'src=https://dist.invalid:8443/releases/ https://dist.invalid:8443/releases/'
contains "$snapshot" 'extra=https://dist.invalid:8443/releases/ https://dist.invalid:8443/releases/'
contains "$snapshot" 'default=https://plain.invalid/'
contains "$snapshot" 'patch=https://patch.invalid/fixes/'
ordered=$(probe snapshot MASTER_SITE_OVERRIDE=https://first.invalid/ MASTER_SITE_BACKUP=https://last.invalid/)
contains "$ordered" 'src=https://first.invalid/ https://dist.invalid:8443/releases/ https://dist.invalid:8443/releases/ https://last.invalid/'
# Legacy omission drops the template. Slice 2 deliberately changes this.
omitted=$(probe snapshot MASTER_SITE_SUBDIR=)
contains "$omitted" 'src='
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
