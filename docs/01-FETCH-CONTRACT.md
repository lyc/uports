# Fetch Compatibility Contract

## Reference And Status

Slice 1 baseline, 2026-10-16. Runtime behavior is unchanged. The local FreeBSD
ports reference is commit `ecc6a37c0d3d10f3a9212be604f70f720cf4b9d6`.
Consulted: `Mk/bsd.sites.mk`, fetch sections of `Mk/bsd.port.mk`,
`Mk/Scripts/do-fetch.sh`, and `Mk/Scripts/functions.sh`.

The collection COPYRIGHT identifies Copyright (C) 1994-2022 The FreeBSD
Project, with two-clause BSD redistribution conditions and warranty disclaimer.
The consulted scripts identify portmgr@FreeBSD.org as maintainer; sites lists
ports@FreeBSD.org. This slice imports no reference code. Any later adaptation
must retain the complete applicable copyright, conditions, disclaimer, and
file-specific notices, not merely this summary.

## Existing Interfaces And Inventory

`Mk/linux.port.mk` owns grouping, inline archive/patch download loops, Git
cache retrieval, checkout, alternative-source relocation, and bootstrap.
`Mk/linux.sites.mk` supplies the mirror catalog. `makesum.sh`/`checksum.sh`
own distinfo; submodule prepare/patch/info scripts own explicit submodules.

- Archives: `MASTER_SITES`, `MASTER_SITE_SUBDIR`, `DISTFILES`, `DISTNAME`,
  `EXTRACT_SUFX`; independent `PATCH_SITES`, `PATCH_SITE_SUBDIR`, `PATCHFILES`.
  `DIST_SUBDIR` changes local storage/distinfo keys, not remote URLs.
- Ordering: override, group-selected sites, backup. Defaults assign DEFAULT;
  comma groups are supported. Legacy grouped subdirs use `path/:group`.
  Shared-group expansion can duplicate URLs; missing subdirs drop templates.
  Slice 2 intentionally revisits these quirks rather than freezing them forever.
- Fetch controls: `FETCH_CMD`, `FETCH_ENV`, before/after arguments, FORCE_FETCH;
  distinfo controls remain as documented in 01-FETCH.md.
- Git: `USE_SCM=git`, protocol/user/host/subdir-derived or explicit
  `SCM_REPO_URL`, command/options, destination, branch/detach, cache name/path,
  update/required-update, fetch environment, and timeout controls remain public.
  The legacy timeout is zero, not bounded by default. Branch selection wins
  over detach in the checkout recipe and currently permits substring matching.
- Lifecycle: pre/post fetch/extract/patch hooks, pre-init-repo bootstrap,
  USE_PATCH V1/V2, alternative source locations, explicit SCM_SUBMODULES.
  Do not replace an existing edited worktree to implement the new selector.
- Wrapper: Tools/tools.mk composes PORTS_ENVS, group environments, and port/
  instance extra/exclude settings. Recursive make also inherits command-line
  assignments. SOURCE_MODE forwarding must be tested at those boundaries;
  it is not implemented by this contract.

Representative parent declarations: guile uses GNU mirrors; lua uses a full
archive URL; cpython/gforth/clisp/quickjs offer legacy Git choices; chezscheme
uses clone options; sbcl has a distinct destination; ad-libitum declares four
submodules and a selectable patch series. No current parent Makefile declares
PATCH_SITES or SCM_BRANCH; synthetic fixtures must retain their coverage.

## Proposed Normalized Source Record v1

This is an internal logical schema, not an implemented wire format or a
dependency-record extension. Choose escaping/serialization before code emits it.
Lists preserve declaration order unless a documented normalization says otherwise.

| Field           | Meaning                                                         |
|-----------------|-----------------------------------------------------------------|
| instance        | Existing group/port/variant identity                            |
| source_id       | DEFAULT or declared source group; unique within instance/flavor |
| flavor          | distfile, patchfile, or repository                              |
| mode            | Selected dist or git backend                                    |
| provider        | plain, github, or later gitlab archive helper; not a mode       |
| filename        | Archive name without group suffix; absent for repository        |
| mirrors         | Ordered expanded archive bases, including override/backup       |
| repository      | Effective explicit or derived Git URL                           |
| ref_kind / ref  | commit, tag, branch, or default-ref request                     |
| resolved_commit | Verified commit after retrieval; absent before resolution       |
| cache_key       | Local archive namespace/name or repository-cache identity       |
| source_root     | Mode-specific materialization root                              |
| placement       | Confined relative placement for grouped sources                 |
| bootstrap       | Selected-mode port-declared bootstrap requirements/hooks        |

Group memberships are lists, not concatenated identity strings. Local paths,
credentials, timestamps, and mirror ordering do not belong in portable artifact
identity. Revision, selected mode, relevant layout/bootstrap inputs, and patch
identity do; integration with dependency state/provenance remains slice 6 work.

## Proposed Selection Rules

Explicit SOURCE_MODE wins; otherwise USE_SCM=git maps to git; otherwise dist.
An explicitly empty/unknown SOURCE_MODE or unsupported nonempty USE_SCM fails
clearly. Ordinary GNU make precedence applies; no override assignment may defeat
operator policy. Missing declarations fail without switching backends.

Explicit SCM_REPO_URL wins over GitHub-derived URL. Explicit SCM_BRANCH replaces
an implicitly derived GH_TAGNAME detach; explicit SCM_DETACH replaces that
implicit ref too. Two nonempty explicit branch/detach declarations are rejected
by the new selector, while legacy USE_SCM behavior stays unchanged until an
explicit migration. An implicit default ref remains a development choice, not
an immutable package identity. Unsupported grouped Git layouts fail explicitly.

SOURCE_MODE is not yet available. Mode selection must precede dependency
metadata so SCM bootstrap providers are installed before bootstrap hooks.

## Verification

The former `Tools/tests/check-fetch-contract` fixture is archived under
`Tools/tests-backup` and is not an active validation command. It checked
group/default mapping, URL ports, independent patch mirrors, ordering, omitted
subdirs, Git URL/cache defaults and overrides, timeout defaults, reserved groups,
and the branch/detach recipe through make dry-run. It does not download, clone,
extract, patch, or mutate worktrees. Real local HTTP/Git lifecycle coverage is
required by the later implementation slices; this fixture does not replace it.
For current real-world validation and implementation-commit mapping, see
[Tools/tests](../Tools/tests/README.md).
