# Cross-Toolchain Architecture And Design Proposal

## Status And Document Ownership

This report records design rationale, interface contracts and implementation
results. Proposed behavior is identified explicitly; describing a contract does
not establish manual acceptance or completed toolchain support. Public names,
target syntax, origins and paths labeled proposed require implementation
review before becoming supported interfaces.

[11-CROSS-TOOLCHAIN-TASKS.md](11-CROSS-TOOLCHAIN-TASKS.md) owns implementation
order, task checkboxes, acceptance and commit/evidence mapping. HANDOFF.md
owns the changing checkpoint, next action and blockers. This report owns
design rationale and supported-interface descriptions as implementation lands.
Keep work-item numbers, temporary restrictions, validation progress and commit
history in the tracker. Update results after acceptance without duplicating
the execution history here.

The proposal extends [group/instance design](10.1-GROUP.md) and
[dependency handling](10.4-DEPENDENCY.md), preserving the
[fetch architecture](01-FETCH.md) and local cache contract.

## Objectives And Profiles

Generate tools from maintained port recipes with pinned sources, inspectable
dependencies and isolated output identities. A generated compiler must be
validated by building and running its intended software, not just by printing
its version. Linux is the initial build host; macOS acceptance is separate.

| Profile | Generated-code target | Target libc | Runtime/debug environment |
| --- | --- | --- | --- |
| MIT 2018 JOS | i386-jos-elf, 32-bit x86 ELF | None | MIT-patched x86 QEMU and target-capable GDB |
| MIT 2026 xv6 | riscv64-unknown-elf, 64-bit RISC-V | None | Upstream QEMU >= 7.2 and target-capable GDB >= 8.3 |
| Trixie ARM64 capability | aarch64-linux-gnu | glibc | Real ARM64 or QEMU user emulation for validation |

QEMU is a required generated deliverable for each MIT profile. Keep the
historical MIT-patched emulator independent from upstream QEMU. Both must be
explicitly selectable; installing one must not silently change the other
profile's emulator. The lab source revision is also pinned for acceptance.

The ARM64 objective is a C/C++ SDK comparable in purpose to Trixie's
crossbuild-essential-arm64 dependency set, not identical Debian packages.
The baseline includes Binutils, GCC/G++, libgcc, libstdc++, Linux UAPI headers,
glibc runtime/development files and a usable target sysroot. Exact versions,
patches, ABI/ISA settings and kernel baseline are selected before building.

Neither MIT profile needs target glibc or Linux UAPI headers. A host library
used by the compiler or emulator is distinct from a target runtime library.

## Proposed Port Boundaries

The accepted core inventory contains seven port definitions. Concrete recipe
versions and any additional prerequisite ports require later review:

| Port | Responsibility |
| --- | --- |
| devel/binutils | Target assembler, linker and binary inspection tools |
| lang/gcc | Compiler and selected target runtimes, including stage recipes |
| devel/gdb | Host-running debugger with selected target support |
| emulators/qemu | Upstream system/user emulation configurations |
| emulators/qemu-mit | Separately pinned MIT debugging fork |
| devel/linux-headers | Sanitized Linux UAPI headers for the target sysroot |
| devel/glibc | Target headers, startup objects, loader and C libraries |

Reuse these recipes across target configurations and bootstrap passes rather
than creating a separate GCC directory for every target/stage. GCC runtime
package splitting is a later explicit packaging decision, not an assumption
that a single GCC install can overwrite every stage safely.

Reuse suitable native GMP/MPFR/MPC providers. Audit QEMU and GDB dependencies,
including legacy Python requirements and pinned submodules, before fixing the
total port count. Missing prerequisites may require additional ports, subject
to scope review. JOS/xv6 validation checkouts are separate from package ports.

## Build, Host And Target Roles

| Role | Meaning | Initial example |
| --- | --- | --- |
| Build | Machine executing configure/build commands | Current Linux machine |
| Host | Machine executing the produced tool | Same Linux machine |
| Target | Machine/ABI executing compiler output | JOS x86, xv6 RISC-V or ARM64 Linux |

Existing CONFIGURE_TARGET handling is the starting point for producing cross
tools. Existing CROSS_COMPILE handling selects an already available toolchain
to compile target software. Do not set the latter merely because GCC emits
foreign code: that could try to build the compiler itself for the target.

GMP used by host-running GCC is a host dependency. glibc being built for ARM64
is a target dependency. Dependency exports must keep their include/library
paths and compiler commands separate. Host utilities used during a target
build, such as xv6's filesystem-image generator, must use the host compiler.

Project profiles own target selection, installation roots and provider policy.
Ports own supported configuration and dependency intent. Preserve existing
host system-or-host/bs restrictions; adding toolchains does not authorize a
global group-policy change. Canadian cross builds are deferred.

## Relationship Between Groups, Flavors And Bootstrap Stages

| Concept | Responsibility | Example |
| --- | --- | --- |
| Group | Shared build/install environment and provider policy | ARM64 toolchain environment |
| Port | Component recipe | GCC or glibc |
| Flavor/variant | Supported configuration of one port | GCC bootstrap or final configuration |
| Bootstrap stage | Configured build's role, prerequisites and required outputs in an ordered flow | Minimal compiler enabling libc construction |
| Build instance | One selected port configuration in a group | ARM64 group's GCC bootstrap instance |

Group provides context; Flavor selects configuration; stage dependencies
establish order. Group membership alone does not order builds. The existing
bs group collects bootstrap tools; it is not a numbered compiler bootstrap
pass. Native bootstrap dependencies may come from bs/host according to
project provider policy without making each pass a separate group.

A single stage instance belongs to one port configuration. A complete
bootstrap sequence spans several such instances, potentially repeating the
same port with different flavors. For example, conceptually:

```text
Group: ARM64 toolchain
    binutils:target
          |
    gcc:bootstrap
          |
    initial libc / intermediate compiler instances
          |
    glibc:full
          |
    gcc:final
```

Names and separators here are illustrative, not approved command syntax or
a finalized bootstrap recipe. The same GCC recipe supplies distinct bootstrap
and final configurations; the dependency graph identifies their stage roles.
Each instance retains independent state and declared outputs. A stage may
produce temporary tools, headers or startup objects without producing a public
distributable package.

Use one configuration identity, represented by Flavor/variant, with explicit
dependency edges and output-readiness requirements for bootstrap participants.
Do not introduce a redundant public STAGE selector alongside FLAVOR, such as
FLAVOR=bootstrap STAGE=bootstrap. If a future requirement needs an additional
identity dimension, review it explicitly rather than adding it implicitly.
Bootstrap stages are also distinct from the existing package stage lifecycle
and STAGEDIR, which assemble installation files for packaging.

## Flavors And Instance Identity

### Declaration And Selection

Ports declare FLAVORS before their first framework include. Names contain
lowercase ASCII letters, digits and underscores, are unique and preserve
declaration order. The first entry is the default. FLAVOR selects exactly one
declared entry; an explicitly empty selection on a flavored port is rejected.
An unflavored port leaves FLAVOR empty and reports implicit `default` metadata,
preserving its existing internal variant key and lifecycle behavior.

For example, a port can declare two configurations:

```make
FLAVORS = default libffcall
```

Declaration alone does not map recipe options or establish build support.
The tracker records the real-port pilot, execution availability and acceptance.

### Discovery Interface

Direct-port `uports-flavor-metadata` emits the versioned record set:

```text
flavor-schema|1
flavors|default libffcall
default|default
selected|libffcall
```

An additional execution record reports lifecycle availability; its temporary
implementation states are documented in the tracker. Duplicate names, invalid
characters, multiple selections and undeclared selections fail explicitly.
No shell probe is needed to validate declaration syntax.

Project diagnostics are `flavor-list` and `flavor-check`. FLAVOR_REQUEST accepts
one selected `[group:]port` using existing canonical/unique-alias resolution;
the output prefixes each record with the existing instance key. Omit the request
to inspect all selected instances, including fallbacks, in planner order.
Unscoped inherited FLAVOR is cleared during all-instance discovery; scoped
discovery retains the requested selection. No provider execution is involved.
Port parsing retains its existing cache-directory preparation contract; these
diagnostics do not fetch, extract, patch, build or install sources/packages.

```sh
make FLAVOR_REQUEST=compiler:gforth flavor-list
make FLAVOR_REQUEST=compiler:gforth FLAVOR=libffcall flavor-check
make flavor-list
```

This is demand-driven metadata collection: no extra port probes or selected
nondefault instance records are added to ordinary planner startup. Existing
info.debug.variants still describes the implemented planner's implicit default
instances. FLAVOR_REQUEST is an inspection selector. It may include the selected
Flavor as [group:]port@flavor; existing scoped FLAVOR queries remain supported.
Conflicting selections are rejected. Lifecycle target syntax is defined below.

### Toolchain Profile Contract

Profile roots use the target tuple. Keep DESTDIR and PREFIX as the standard
installation controls; development/testing uses DESTDIR=$(topdir)/local.
These contracts do not activate groups or change the parent Makefile.

| Profile / target tuple | Proposed native tool group | PREFIX | Development installation root |
| --- | --- | --- | --- |
| i386-jos-elf | toolchain | /i386-jos-elf | $(topdir)/local/i386-jos-elf |
| riscv64-unknown-elf | toolchain | /riscv64-unknown-elf | $(topdir)/local/riscv64-unknown-elf |
| aarch64-linux-gnu | toolchain | /aarch64-linux-gnu | $(topdir)/local/aarch64-linux-gnu |

Keep compiler for the existing normal compiler/development environment and
declare one toolchain group for cross-toolchain production. They coexist as
separate groups; do not rename compiler, move its current packages, or change
its installation defaults. Selected port Flavors distinguish target/stage
configurations inside toolchain. Flavor identifiers follow the declaration
syntax; they map explicitly to tuples rather than requiring tuple strings as
Flavor names. The same origin can therefore have several selected instances
once flavored dispatch/dependency support is implemented.

Set producer CONFIGURE_TARGET and tuple PREFIX per selected instance, not
globally on toolchain. GCC/Binutils/GDB need their selected output target;
QEMU and native prerequisites need their own configuration. CROSS_COMPILE
stays unset for native tool production. Do not generate groups implicitly or
set CONFIGURE_TARGET and CROSS_COMPILE together on a compiler-producing port.

Cross compilers, Binutils, GDB and QEMU are host-running tools. Install them
beneath local/<tuple>, not local/compiler, during development. This does not
automatically assign them to the existing host group: group/provider policy
and installation layout are separate decisions. Only selected profiles need
directories; the layout is unchanged when a single profile is enabled.
All three profiles must coexist with isolated build/package/install identities
and explicit compiler/debugger/emulator selection. DESTDIR may instead be /opt
or another chosen root; no particular DESTDIR is a permanent runtime location.
The tuple identifies the target, not multiple incompatible SDK versions for
that same target; those would need an explicitly reviewed additional root.

Tools are exposed below DESTDIR+PREFIX/bin. Build/host are the actual native
system; CONFIGURE_TARGET selects the generated-code target for Binutils/GCC/GDB.
QEMU runs natively with its selected emulation configuration, not with
CROSS_COMPILE targeting JOS/xv6.
The two MIT profiles have no target libc/sysroot construction requirement.

Target libraries use a reusable target/sysroot environment, with a separate
instance for each target/compiler/ABI context. ARM64 Linux is the first instance;
the framework must not hard-code ARM64-specific group names or paths. Concrete
project group names are implementation configuration, not a new public selector.
For ARM64, DESTDIR is the selected profile root plus /sysroot, PREFIX=/usr,
and CROSS_COMPILE=aarch64-linux-gnu selects the target compiler. The same
DESTDIR/PREFIX model applies to other supported target tuples. Supporting a new
CPU also requires reviewed recipes, ABI settings and bootstrap requirements;
changing the tuple alone does not establish support. The MIT bare-metal profiles
do not require this Linux/glibc environment. This is a justified context boundary,
not one group per bootstrap pass. The exact GCC
sysroot configure/search-path and relocatable SDK packaging rules must be
reviewed against selected versions before staged SDK execution.

For example, toolchain's GCC is built with the native compiler and executes on
the host, while the ARM64 sysroot's glibc uses that generated ARM64 GCC and
contains ARM64 objects. Build utilities used during glibc construction still
run natively. Keep native dependency include/library/runtime paths separate
from target sysroot and pkg-config paths; do not put target libraries on the
host LD_LIBRARY_PATH. Linux header installation is architecture-specific;
not every header-producing step requires an executable cross compiler.
The separate context is needed even though both outputs share one profile root.
Bootstrap/final passes remain flavored instances with ordered sysroot writes,
not additional groups for each pass. No ARM64 target libraries go into the
ordinary local/compiler tree through this profile.

The ARM64 SDK includes target C headers and libraries. Sanitized Linux UAPI
headers come from the kernel's headers-install procedure; standard C/POSIX and
target-specific libc headers come from glibc. Both install under
<profile-root>/sysroot/usr/include. Target runtime/development libraries and
the loader belong under that sysroot; exact lib/lib64/multiarch placement is
reviewed with the selected versions. GCC also supplies compiler-specific
headers and target runtimes in its own configured, versioned directories.
Do not copy host /usr/include or use host libraries to populate the sysroot.

Configure the installed GCC with a default sysroot beneath its execution
prefix, and supply the actual build-time location separately. Proposed final
compiler arguments for the development ARM64 layout are:

```text
--target=aarch64-linux-gnu
--prefix=/aarch64-linux-gnu
--with-sysroot=/aarch64-linux-gnu/sysroot
--with-build-sysroot=<project>/local/aarch64-linux-gnu/sysroot
```

Derive these paths from the selected DESTDIR/PREFIX, not hard-coded project
paths. GCC documents relocation of a sysroot beneath its execution prefix
relative to the compiler binaries. --with-build-sysroot supplies the location
used while building target libraries; it does not replace the installed default.
See [GCC configuration](https://gcc.gnu.org/install/configure.html).
Bootstrap configurations may require different options. Validate -print-sysroot,
header/library searches and real compile/link behavior both in development and
after moving the complete profile to another DESTDIR. Configure Binutils
consistently and verify host runtime-library lookup; GCC's documented behavior
alone does not establish relocation of the complete SDK.

Proposed toolchain policy permits selected native providers from toolchain,
host, bs and compiler, plus validated native system providers. Reuse compiler's
GMP/MPFR/MPC only when their effective build environment and installed artifacts
are native-compatible. Group name alone does not prove this. Require explicit
selection when compatible candidates are ambiguous. Preserve host's existing
host/bs-only uports policy; toolchain's policy does not widen it.
Native dependency installation prefixes belong to their provider instances,
not the consuming toolchain's tuple root. Consumer flags must use those actual
paths; do not propagate CONFIGURE_TARGET or append /tools in library recipes.
This permits native prerequisites to be shared across the three profiles.
Target-library groups
must use target-compatible uports/explicit SDK providers; they cannot satisfy
target libc requirements with a host-system library. Preserve existing host
group restrictions rather than reassigning current host tools or dependencies.
Profile activation and acceptance are tracked separately from this contract.

Automatic consumer matching remains proposed: CROSS_COMPILE identifies a
required target, which must resolve to a compatible explicitly selected
toolchain instance or configured SDK. Match target/configuration/readiness,
reject missing or ambiguous providers, order installation before consumer
execution, and export the selected bin directory. A tuple alone does not prove
ABI or bootstrap readiness. Current preflight only searches prefixed commands
on PATH; it does not construct this dependency. Current target contexts are
group-based and reject mixed CROSS_COMPILE values, supporting a separate
target/sysroot environment. Its external-provider mode must explicitly support
cross dependencies; do not silently reuse native host discovery policy.

Instance identity remains group + origin + flavor. Target tuple, ABI/ISA,
source/patch configuration, runtime prefix and dependency identities belong
in artifact state; checkout/cache locations alone are not portable content
identity. Stages add readiness/dependency relationships to those instances,
not another public STAGE selector. New flavored artifact paths and provider
matching are prerequisites for safe nondefault execution.

The existing tools.mk normalized records, variant keys and shared lifecycle
dispatch are the integration boundary. Extend dependency metadata and execution
through that boundary instead of adding a second scheduler. Cross-toolchain
preflight checks existing compilers; constructing them is the responsibility of
component recipes. CONFIGURE_TARGET and CROSS_COMPILE retain their distinct
producer/consumer roles.

The core origins are the seven in the accepted inventory. Prerequisite closure and
exact component versions remain pending per-target audits; no additional ports
or unreviewed bootstrap passes are implicitly approved by this baseline.

### Artifact Identity And Isolation

The artifact contract isolates mutable state while preserving default names.
Implementation and manual acceptance status are recorded in the tracker.

Default/unflavored paths, names and source identity remain compatible:

| Artifact | Default example | Nondefault example |
| --- | --- | --- |
| Work | work.compiler | work.compiler.flavor-libffcall |
| Stage | work.compiler/stage | work.compiler.flavor-libffcall/stage |
| Generated plist | work.compiler/.PLIST.mktmp | work.compiler.flavor-libffcall/.PLIST.mktmp |
| Package base | gforth | gforth-libffcall |
| State/cookies | Within default work directory | Within nondefault work directory |
| Alternative source base | ALTERNATIVE_WRKDIR | ALTERNATIVE_WRKDIR.flavor-libffcall |

The public alternative-source setting is not overwritten. Extraction, checkout
placement and source links use its effective namespaced base, avoiding the
default checkout. Downloads and mirrors remain shared in the local caches.

Initial helpers are `<flavor>_PKGNAMEPREFIX`, `<flavor>_PKGNAMESUFFIX` and
`<flavor>_PLIST`. Defined helpers override the corresponding fallback, including
an explicitly empty value. Without a suffix helper, a nondefault Flavor appends
`-<flavor>` after the ordinary package suffix. Default selection adds nothing.
PKGBASE follows the same helpers as PKGNAME. A plist helper selects a read-only
input file and uses the platform as its package plist extension.
PLIST_SUB independently resolves conditional entries into a concrete manifest
under WRKDIR for packaging and staged-inventory comparison. It does not change
the input plist or the inventory produced by generate-plist. Gforth uses
conditional entries for its optional libffcall wrapper; see
[install/plist behavior](08-INSTALL.md). Separate package identities do not
make configurations with overlapping installed files safe to coinstall.

Nondefault WRKDIR overrides must retain the `.flavor-<name>` suffix. Mutable
source/build/stage directories, generated plists, cookies and saved-state/work
package files must remain under that namespace; external read-only dependency
input reports remain allowed. Alternative sources must use the effective
alternative root. Explicit package overrides cannot use the ordinary package
identity, and cache filenames must match the selected package name. Custom
helper mappings must remain distinct across Flavors; selected-instance
validation must detect conflicting mappings before execution. Separate artifacts
do not imply safe coinstallation in one destination root.

Port validation compares the selected package base/name with the mappings of
the other declared Flavors using the helpers visible in that configuration.
Matching mappings fail before lifecycle execution; distinct custom suffixes
remain permitted. This validates declared package naming, not installed file
ownership or arbitrary conditionally hidden recipe mappings.

Nondefault source request keys include `flavor=<name>`. Saved source state adds
`flavor|<name>`, and package creation uses the existing PVER 2 source-provenance
path even when SOURCE_MODE was selected through legacy defaults. Package reuse
therefore requires the matching source request key and available source
evidence. Default selection adds no Flavor field/hash. The contract reuses the
existing package format; planner integration owns dependency-instance identity.

Discovery exposes work/source/stage/plist/state paths, package name/base/
cache/work files, source key/Flavor and lifecycle cookies. Alternative-source
paths appear when enabled. Schema 1 permits additive artifact records. Metadata
inspection alone does not prove runtime isolation or safe coinstallation.

### Wrapper Selection And Dependency Contract

Use FreeBSD-compatible FLAVORS/FLAVOR concepts with GNU Make syntax. Map
them onto the existing internal variant dimension, not a second parallel
variant implementation. The initial scope includes declared choices, default
selection, relevant naming/plist/dependency helpers and wrapper integration.

Dependency selection follows these rules:

- A port declares supported flavors; its first declaration is the default.
- A project selects the needed flavor(s) for a group/port. Do not expand every
  flavor across every group automatically.
- A port without flavors retains its current public targets and behavior.
- Resolve defaults to a concrete identity before dependency planning. Existing
  implicit default-variant records need a compatibility mapping, not a global
  rename that invalidates unrelated installed state.
- Unknown selections and ambiguous aliases fail before execution.
- Exact dependency flavor requests resolve to that flavor under existing
  group/provider policy. No implicit fallback to an incompatible flavor.
- A consumer's FLAVOR must not leak into unrelated dependency metadata or
  recursive builds. An unspecified dependency flavor resolves to the provider's
  documented default; any deliberate propagation must be explicit.

Instance identity is group + resolved origin + selected flavor, with target
profile and configuration represented in saved build/package state. Bootstrap
roles and readiness are attached to these instances rather than introducing
a second configuration selector. Target triples/ABIs remain
first-class configuration: naming a flavor does not itself configure GCC.

Public lifecycle targets use `[group:]port[@flavor].phase`. Examples:

```sh
make gforth@libffcall.fetch
make compiler:gforth@libffcall.fetch
make compiler:gforth@default.fetch
make gforth@libffcall.flavor-check
```

Group-qualified unflavored commands use `compiler:gforth.build`; ordinary
aliases and group/category/global aggregates retain their previous spelling.
The old `group@port` and `port:flavor` wrapper syntax is rejected with a
migration hint. Planner `group@category/port` records, provider policy syntax,
dependency declarations and internal instance keys retain their meanings.
Only public command/request spelling changes; port Flavor declarations,
artifact paths and package identities remain unchanged. Saved dependency-state
comparison normalizes old/new uports command spellings, including embedded
build-state records. Syntax alone does not invalidate build state; provider,
Flavor and phase changes remain significant.

Resolve group/port through existing canonical and alias rules before applying
the Flavor. Rejected or ambiguous aliases require an explicit group. Preserve
unqualified targets; explicit default selection uses the existing default
instance and state rather than creating a second configuration. Validate the
selection against the actual port declaration before dispatch. Names follow
the declaration character rules, with exactly one nonempty Flavor qualifier.
Literal colons are escaped only at make rule/prerequisite syntax boundaries;
normalized target strings remain unescaped data through recursive dispatch.

Projects may select a Flavor through the existing per-instance environment,
for example PORTS_compiler_gforth_EXTRA_ENVS=FLAVOR=libffcall. A qualified target
overrides that instance selection. Do not use a global FLAVOR to select wrapper
lifecycle work; it could otherwise affect unrelated providers. Direct port
FLAVOR and the existing scoped discovery interface retain their meaning.
Generate rules only for requested/configured selections, without expanding all
declared Flavors across the project. Target .flavor-check performs metadata
inspection without executing the selected lifecycle. Implementation availability
and remaining dependency-enabled lifecycle work are recorded in the tracker.

`make info.ports` keeps one row per port/group instance and preserves the
original leading default-instance lifecycle status. Additional declared Flavors
always appear as compact entries such as `libffcall:I`, including after
distclean. A dot means no lifecycle cookie exists, for example `libffcall:.`.
Version/license differences are annotated on the affected entry; long lists
wrap onto aligned continuations. Status describes work cookies, not an audit of
installed files or package ownership.

Ordinary ports retain lightweight source scanning. Flavor declarations and
custom artifact mappings trigger actual port metadata evaluation, using exact
work/cookie paths. The scanner is not a complete Make interpreter; arbitrary
dynamic declarations hidden outside its include scan are not guaranteed to be
discovered. The display-only metadata goal avoids archive compatibility scans;
normal lifecycle checks remain in force. Display collection does not resolve
the dependency graph, execute builds or introduce a persistent metadata cache.

Dependency declarations use `requirement:category/port@flavor[:phase]`.
The qualifier is part of the logical requirement and is resolved against the
actual provider declaration. Existing origin/capability and group policy apply;
unqualified requirements use the provider's default independently of project
root selections. A generic external provider cannot substitute for a named
uports Flavor without an explicit configuration contract. See the detailed
[dependency interface](10.4-DEPENDENCY.md#flavor-selection-and-dependency-instances).

Default instance keys retain compatibility. Nondefault keys append
`__flavor_<name>` and carry their own metadata, cookies and saved state.
Metadata snapshots retain the chosen variants across recursive make. Probes
clear inherited FLAVOR before applying an instance selection. Flavor-specific
BUILD_DEPENDS/LIB_DEPENDS/RUN_DEPENDS helpers add to ordinary requirements.
Selected provider paths come from its installation root, including native build
tools and matching target libraries; consumer tuple prefixes do not replace
provider paths. OS/architecture checks support the native/target boundary;
bootstrap ABI/output readiness remains part of the stage contract.

Separate work/build/stage directories, cookies, dependency state, package
identity and install records for incompatible instances. Distinct package
names do not guarantee safe coinstallation: recipes must use disjoint paths
or explicit conflicts. Automatic language-flavor generation is deferred.

## Bootstrap Stages

Flavors describe supported configurations. Bootstrap stages additionally
describe prerequisite outputs and execution order. Extend the existing graph
and scheduler; do not introduce a separate orchestration system.

The MIT profiles need ordinary Binutils/compiler/runtime ordering but do not
require the full GCC/glibc bootstrap graph. Complete both profiles before
implementing general staged-libc support.

For ARM64, the conceptual sequence is:

```text
Binutils + Linux UAPI headers
              |
        bootstrap GCC
              |
   initial libc components / intermediate compiler support
              |
         complete glibc
              |
     final GCC C/C++ and runtimes
```

This is not a fixed executable recipe. Selected GCC/glibc versions determine
whether separate libc headers/start files, intermediate libgcc or other passes
are necessary. Review that concrete graph before enabling execution.

Each pass declares exact providers and readiness outputs, including which
compiler runs on the host and which objects belong in the target sysroot.
Intermediate headers/stubs must never satisfy final libc readiness. Stage
completion needs saved configuration/output evidence even when the stage
does not produce a public package.

Dependencies order any writers sharing a sysroot. Define file ownership,
temporary output replacement and promotion explicitly; do not let concurrent
stages overwrite files or replace an accepted final SDK during experiments.
Resume after failure must distinguish valid prerequisite outputs from partial
installation. An upstream stage/source/ABI change invalidates affected
downstream state without discarding unrelated work or developer edits.

## Installation, Caches And Source Handling

Use tuple-named installation roots beneath the selected DESTDIR, with
PREFIX=/<tuple>. Development installs use $(topdir)/local/<tuple>.
A profile exposes its host-running tools and, for ARM64, its target sysroot.
Honor staging via DESTDIR and the intended runtime prefix separately; never
embed a temporary staging path as the compiler's final installation prefix.

Preserve the existing development-install contract:
`FORCE_DEVELOPMENT_INSTALL=yes` prepares sources through fetch/extract/patch
even when a compatible package is reused, skipping configure/build/stage/
package creation. Explicit `no` skips source preparation for that compatible
package; without one, both settings follow the normal source build flow.
`FORCE_REBUILD=yes` remains a cache bypass, including existing group policy
that sets it. Do not silently change group policy to demonstrate reuse.
Flavor/stage identity must reject incompatible artifacts without treating
checkout-local paths or missing local build state alone as incompatibility.
See [08-INSTALL.md](08-INSTALL.md) for the implemented package contract.

Bind compiler, linker, debugger and QEMU selection explicitly in each profile
and lab invocation. Determine compiler search paths, runtime loader behavior
and host shared-library dependencies as part of packaging. Relocation is an
acceptance question to define, not an automatic property of staged installation.

Preserve PORTSDIR/distfiles, packages and scm as authoritative local paths;
existing directories/symlinks outrank global-site defaults. Source caches may
be shared where coordinates match. Mutable patched/configured source trees
must not be shared unsafely between concurrent flavors or stages. Use separate
out-of-source build directories for GCC/Binutils and preserve fetched checkouts.

Prefer reviewed release archives/checksums or pinned commits. Record local
compatibility patches. Preserve the historical MIT fork separately; do not
replace it with upstream QEMU just because upstream builds more easily.

## Delivery And Validation Boundaries

Establish the profile/identity contract and Flavor foundation before MIT tool
integration. Complete both MIT profiles before general staged-libc execution,
then use that foundation for the complete ARM64 SDK.

The [task tracker](11-CROSS-TOOLCHAIN-TASKS.md) owns the single ordered work list,
implementation order, temporary restrictions, acceptance evidence and commits.
Keep the architecture organized by responsibility as delivery units evolve.

Use a real two-configuration pilot to exercise the Flavor contract before
complex compiler recipes. Preserve shared planner dispatch and selected-instance
growth constraints in [10.2-TOOLS.md](10.2-TOOLS.md). Required plist helpers
belong in the framework contract rather than an implicit prerequisite.

The Flavor pilot precedes complex compiler bootstrapping. Stage framework
validation can use early ARM64 prerequisite work, retained for the complete
SDK phase; do not build the entire SDK merely to review its graph.

Stage support follows the MIT profiles because they exercise compiler recipes
and the Flavor foundation without libc bootstrapping. This is the chosen
risk-reduction sequence, not a technical restriction. Contract discussion can
occur earlier; execution waits for prerequisite acceptance. Retain early ARM64 stage
outputs and evidence for complete SDK acceptance. Do not repeat accepted builds
solely because a later delivery unit uses the same evidence.
The selected recipe determines actual compiler/libc passes; a conceptual graph
does not mandate unnecessary passes.

| Acceptance | Required evidence |
| --- | --- |
| Flavor framework | Real configurations, exact dependencies, isolated outputs, repeat reuse, invalid selection/conflict behavior |
| JOS profile | Generated tools compile the pinned lab, correct ELF32 output, boot in generated MIT QEMU, GDB breakpoint/step |
| xv6 profile | Generated tools compile kernel/users/image, boot in generated RISC-V QEMU, basic runtime tests and GDB breakpoint/step |
| Stage framework | Resolved order, output readiness, intermediate/final distinction, failure/resume and invalidation behavior |
| ARM64 SDK | C/C++ compile/link, ELF/loader inspection, threads/exceptions, runtime on ARM64 or QEMU and a real uports consumer |

ARM64 user-mode QEMU is distinct from MIT system emulation. If selected for
validation, explicitly build/select that capability and run with the generated
target loader/sysroot. It does not prove complete target-kernel compatibility.

User manually validates each component/change before dependent work advances.
No automatic regression runs, build execution or new test scripts are implied
by this proposal. Record source/configuration, commands, logs, platform and
commit mapping in the tracker. Separate framework, port and parent-policy
commits, with authorization before committing or updating the parent gitlink.

## Open Decisions And Limits

Resolve these in the corresponding tracker tasks before implementation:

- Exact source releases/commits and required modern-host compatibility patches.
- Final port origins, prerequisite closure, group placement and profile paths.
- Public Flavor/wrapper syntax, helper subset and default identity migration.
- Exact ARM64 bootstrap graph, intermediate output ownership and package split.
- ISA/ABI/kernel baseline, sysroot layout and relocation requirements.
- macOS support and native dependencies, separately from Linux acceptance.

Out of initial scope: complete Debian package reproduction, additional target
ABIs, Canadian cross, full automatic language Flavor generation, all-flavor
matrix execution and solving the course lab exercises.

## Reference Sources

- [MIT 2018 tool requirements](https://pdos.csail.mit.edu/6.828/2018/tools.html)
- [MIT 2018 lab setup](https://pdos.csail.mit.edu/6.828/2018/labs/lab1/)
- [MIT QEMU fork](https://github.com/mit-pdos/6.828-qemu)
- [MIT 2026 tool requirements](https://pdos.csail.mit.edu/6.828/2026/tools.html)
- [MIT 2026 first lab](https://pdos.csail.mit.edu/6.828/2026/labs/util.html)
- [Debian Trixie crossbuild-essential-arm64](https://packages.debian.org/trixie/crossbuild-essential-arm64)
- [Debian Trixie cross libc development files](https://packages.debian.org/trixie/libc6-dev-arm64-cross)
- [FreeBSD Flavors](https://docs.freebsd.org/en/books/porters-handbook/flavors/)
- [crosstool-NG toolchain construction](https://crosstool-ng.github.io/docs/toolchain-construction/)
