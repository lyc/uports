# uports

uports is a **FreeBSD ports-inspired build and package system with project group
support**. Recipes describe software; groups describe the environments in which
that software is built and used. Its goal is simple, readable configuration for
small-to-medium project development environments.

The name means "micro Ports": a simple way to manage third-party open-source
libraries, toolchains and utilities needed during software development.

## Architecture

| Layer | Responsibility |
|---|---|
| Recipes | Declare sources, versions, dependencies, configuration, build/install rules and package manifests. |
| Flavors | Provide named variations of a recipe, including alternate versions or build configurations. |
| Groups | Define package membership, build environments, installation settings and dependency-provider policy. |
| Dependency resolver | Select compatible system or uports providers, resolve recursive dependencies, detect cycles and order execution. |
| Lifecycle and state | Execute package phases and track progress and relevant configuration changes. |
| Package manager | Create, install and remove packages, record installed files and detect ownership conflicts. |

A **recipe, group and Flavor** identify a build instance. Instances keep separate
work and state paths. Installation coexistence also depends on their prefixes,
package identities and installed file paths.

Recipes declare requirements through `BUILD_DEPENDS`, `LIB_DEPENDS` and
`RUN_DEPENDS`. Dependencies may specify an exact `@flavor`. Provider policy
determines which system tools or group instances may satisfy those requirements.
Required dependencies are prepared before their consumers; valid installed
dependencies can be reused.

Group membership defines aggregate operations. An explicit command can select
any discovered recipe in a declared group without adding it to that group's
aggregate membership. The first declared group is the default unless explicitly
overridden. Group names describe project environments, rather than recipe
categories such as `devel` or `lang`.

The lifecycle is:

```text
fetch -> extract -> patch -> configure -> build -> stage -> package -> install
```

`DESTDIR` and `PREFIX` control installation layout. Staging collects package
contents before installation. By default, development installs prepare sources
for review even when a compatible prebuilt package can skip compilation;
`FORCE_DEVELOPMENT_INSTALL=no` allows reuse without source preparation.

## Configuration ownership

| Location | Responsibility |
|---|---|
| `Mk/` | Per-port source handling, lifecycle, state and package rules. |
| `Mk/Scripts/pkg.sh` | Package creation, installation, removal and ownership tracking. |
| `Tools/` | Recipe discovery, group instances, dependency orchestration and command wrappers. |
| `Tools/group.mk` | Reusable framework group defaults and helpers. |
| `<category>/<port>/` | Built-in recipes. |
| Project `feeds/group.mk` | Project memberships, environments, Flavor defaults and provider policy. |
| Project `Makefile` | Framework integration and application/module selection. |

A consuming project includes `Tools/tools.mk` and may supply an external recipe
collection through `FEEDS`. Matching feed origins override built-in recipes.
Project-specific group names, toolchain profiles and application policy belong
in the consuming project.

## Command interface

From an integrated project, lifecycle targets use
`[group:]port[@flavor].phase`. Omit the group when the package resolves through
the default group or a unique configured group. Omit the Flavor to use its
scoped group setting or the recipe's declared default.

Common aggregate and inspection commands are:

```sh
make info.ports
make ports.install
make ports.distclean
```

`ports.install` installs configured group members and their dependencies.
Aggregate `clean` and `distclean` cover every declared Flavor of their members.
An explicit flavored cleanup stays scoped to that instance. Dependency plans
can be inspected with `DEPENDENCY_REQUEST=<target>` and
`dependency-execution-plan`.

`info.ports` displays versions, licenses and group/Flavor lifecycle cookies. It
does not resolve dependencies or verify installed-file health. Use
`INFO_PORTS_GROUP` or `INFO_PORTS_PORT` to filter it, and
`INFO_PORTS_VIEW=detailed` for the per-group view.

## Design and implementation documentation

- [Groups and project configuration](docs/10.1-GROUP.md)
- [Dependency handling](docs/10.4-DEPENDENCY.md)
- [Flavors](docs/10.5-FLAVOR.md)

## Development history

The framework's development follows these branch scopes. Recent work is grouped
under the planned `flavor` and `group` branches.

- **infra** — Initial fetch, extract, patch, configure, build, install and
  package targets, with source configuration and cross-compilation controls.
- **infra2** — Staging, stage QA, a package repository and package-based
  install/deinstall through `pkg.sh`.
- **tools** — Project groups, per-group installation environments, host tools
  and convenient lifecycle wrappers, alongside closer FreeBSD ports alignment.
- **tools2** — External feed integration, bootstrap/host defaults, normalized
  instance records and shared dispatch paths, with wrapper performance work.
- **patch** — Declared Git submodules and patch-series handling for subprojects.
- **tools3** — Dependency normalization and graphs, provider-first execution,
  phase-aware state, external provider policy and environments, provenance and
  default dependency execution.
- **tools4** — Native tool discovery and validation, fallback provider handling,
  scoped dependency checks and installed dependency/package reuse refinements.
- **fetch** — Atomic archive fetching, grouped GitHub sources, explicit
  archive/Git selection, source provenance, developer worktree preservation and
  bounded SCM operations.
- **flavor** — Flavor declarations, isolated source/work/state paths, exact
  flavored dependencies, package/manifest identity and `group:port@flavor.phase`
  wrappers. Related package work strengthens manifest validation, standalone
  package handling, ownership safety and development-install reuse.
- **group** — Ordered group declarations, native contexts, bounded provider
  discovery and aggregate selection directly from group membership. Compact
  group/Flavor listings and metadata scheduling improve inspection performance
  and responsiveness.
