# Native provider discovery registry.
#
# This file declares interfaces that may be satisfied by a validated native
# provider.  It does not inspect the host or select a provider.

include $(portdir)/Tools/Providers/linux.mk
include $(portdir)/Tools/Providers/macos.mk

DEPENDENCY_PROVIDER_PROFILE ?= auto
dependency-provider-profiles = linux macos
dependency-provider-auto-profile = $(if $(filter linux,$(DEPENDENCY_BUILD_OPSYS)),linux,$(if $(filter darwin,$(DEPENDENCY_BUILD_OPSYS)),macos))
dependency-provider-profile = $(if $(filter auto,$(DEPENDENCY_PROVIDER_PROFILE)),$(dependency-provider-auto-profile),$(DEPENDENCY_PROVIDER_PROFILE))
ifneq ($(filter $(DEPENDENCY_PROVIDER_PROFILE),auto $(dependency-provider-profiles)),$(DEPENDENCY_PROVIDER_PROFILE))
$(error DEPENDENCY_PROVIDER_PROFILE must be one of: auto $(dependency-provider-profiles))
endif

dependency-provider-profile-opsys = $(dependency-provider-profile-$(dependency-provider-profile)-opsys)
dependency-provider-profile-pkg-config-candidates = $(dependency-provider-profile-$(dependency-provider-profile)-pkg-config-candidates)
dependency-provider-profile-cc-candidates = $(dependency-provider-profile-$(dependency-provider-profile)-cc-candidates)
dependency-provider-profile-prefixes = $(dependency-provider-profile-$(dependency-provider-profile)-prefixes)
dependency-provider-profile-error = $(strip \
	$(if $(dependency-provider-profile),,unsupported-build-opsys:$(DEPENDENCY_BUILD_OPSYS)) \
	$(if $(and $(dependency-provider-profile),$(filter-out $(DEPENDENCY_BUILD_OPSYS),$(dependency-provider-profile-opsys))),profile-opsys-mismatch:$(dependency-provider-profile):$(DEPENDENCY_BUILD_OPSYS)))

DEPENDENCY_PROVIDER_REGISTRY ?= ncurses readline libffi zlib

DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.ncurses ?= devel/ncurses
DEPENDENCY_PROVIDER_REGISTRY_METHOD.ncurses ?= pkg-config
DEPENDENCY_PROVIDER_REGISTRY_MODULE.ncurses ?= ncurses
DEPENDENCY_PROVIDER_REGISTRY_HEADER.ncurses ?= ncurses.h
DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.ncurses ?= ncurses

DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.readline ?= devel/readline
DEPENDENCY_PROVIDER_REGISTRY_METHOD.readline ?= pkg-config
DEPENDENCY_PROVIDER_REGISTRY_MODULE.readline ?= readline
DEPENDENCY_PROVIDER_REGISTRY_HEADER.readline ?= readline/readline.h
DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.readline ?= readline

DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.libffi ?= devel/libffi
DEPENDENCY_PROVIDER_REGISTRY_METHOD.libffi ?= pkg-config
DEPENDENCY_PROVIDER_REGISTRY_MODULE.libffi ?= libffi
DEPENDENCY_PROVIDER_REGISTRY_HEADER.libffi ?= ffi.h
DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.libffi ?= ffi

DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.zlib ?= archivers/zlib
DEPENDENCY_PROVIDER_REGISTRY_METHOD.zlib ?= pkg-config
DEPENDENCY_PROVIDER_REGISTRY_MODULE.zlib ?= zlib
DEPENDENCY_PROVIDER_REGISTRY_HEADER.zlib ?= zlib.h
DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.zlib ?= z

define dependency-provider-registry-input
  $(foreach r,$(DEPENDENCY_PROVIDER_REGISTRY),printf '%s\n' 'registry|$r|$(DEPENDENCY_PROVIDER_REGISTRY_ORIGIN.$r)|$(DEPENDENCY_PROVIDER_REGISTRY_METHOD.$r)|$(DEPENDENCY_PROVIDER_REGISTRY_MODULE.$r)|$(DEPENDENCY_PROVIDER_REGISTRY_HEADER.$r)|$(DEPENDENCY_PROVIDER_REGISTRY_LINK_NAME.$r)';)
endef

DEPENDENCY_PROVIDER_PKG_CONFIG ?=
DEPENDENCY_PROVIDER_PKG_CONFIG_ORIGIN ?= devel/pkg-config
DEPENDENCY_PROVIDER_CC ?=
DEPENDENCY_PROVIDER_PKG_CONFIG_CANDIDATES ?= $(dependency-provider-profile-pkg-config-candidates)
DEPENDENCY_PROVIDER_CC_CANDIDATES ?= $(dependency-provider-profile-cc-candidates)
DEPENDENCY_PROVIDER_PREFIXES ?= $(dependency-provider-profile-prefixes)

# Native build-tool discovery is deliberately separate from the pkg-config
# library registry.  Each entry describes the command interface that may
# satisfy one build-context origin.  Commands are searched only below the
# active profile prefixes unless an explicit path is supplied for the entry.
DEPENDENCY_PROVIDER_TOOL_REGISTRY ?= m4 autoconf automake libtool cmake

DEPENDENCY_PROVIDER_TOOL_ORIGIN.m4 ?= devel/m4
DEPENDENCY_PROVIDER_TOOL_CANDIDATES.m4 ?= m4
DEPENDENCY_PROVIDER_TOOL_MIN_VERSION.m4 ?= 1.4.19
DEPENDENCY_PROVIDER_TOOL_REQUIRED.m4 ?= m4

DEPENDENCY_PROVIDER_TOOL_ORIGIN.autoconf ?= devel/autoconf
DEPENDENCY_PROVIDER_TOOL_CANDIDATES.autoconf ?= autoreconf
DEPENDENCY_PROVIDER_TOOL_MIN_VERSION.autoconf ?= 2.69
DEPENDENCY_PROVIDER_TOOL_REQUIRED.autoconf ?= autoconf autoreconf autoheader autom4te autoscan autoupdate ifnames

DEPENDENCY_PROVIDER_TOOL_ORIGIN.automake ?= devel/automake
DEPENDENCY_PROVIDER_TOOL_CANDIDATES.automake ?= automake
DEPENDENCY_PROVIDER_TOOL_MIN_VERSION.automake ?= 1.16.1
DEPENDENCY_PROVIDER_TOOL_REQUIRED.automake ?= automake aclocal

DEPENDENCY_PROVIDER_TOOL_ORIGIN.libtool ?= devel/libtool
DEPENDENCY_PROVIDER_TOOL_CANDIDATES.libtool ?= libtoolize
DEPENDENCY_PROVIDER_TOOL_MIN_VERSION.libtool ?= 2.4.6
DEPENDENCY_PROVIDER_TOOL_REQUIRED.libtool ?= libtoolize libtool

DEPENDENCY_PROVIDER_TOOL_ORIGIN.cmake ?= devel/cmake
DEPENDENCY_PROVIDER_TOOL_CANDIDATES.cmake ?= cmake
DEPENDENCY_PROVIDER_TOOL_MIN_VERSION.cmake ?= 3.20
DEPENDENCY_PROVIDER_TOOL_REQUIRED.cmake ?= cmake ctest

define dependency-provider-tool-registry-input
  $(foreach r,$(DEPENDENCY_PROVIDER_TOOL_REGISTRY),printf '%s\n' 'tool|$r|$(DEPENDENCY_PROVIDER_TOOL_ORIGIN.$r)|$(DEPENDENCY_PROVIDER_TOOL_MIN_VERSION.$r)|$(DEPENDENCY_PROVIDER_TOOL_CANDIDATES.$r)|$(DEPENDENCY_PROVIDER_TOOL.$r)|$(DEPENDENCY_PROVIDER_TOOL_REQUIRED.$r)';)
endef

dependency-provider-discovery-command = \
	DEPENDENCY_PROVIDER_PKG_CONFIG='$(DEPENDENCY_PROVIDER_PKG_CONFIG)' \
	DEPENDENCY_PROVIDER_PKG_CONFIG_ORIGIN='$(DEPENDENCY_PROVIDER_PKG_CONFIG_ORIGIN)' \
	DEPENDENCY_PROVIDER_CC='$(DEPENDENCY_PROVIDER_CC)' \
	DEPENDENCY_PROVIDER_PKG_CONFIG_CANDIDATES='$(DEPENDENCY_PROVIDER_PKG_CONFIG_CANDIDATES)' \
	DEPENDENCY_PROVIDER_CC_CANDIDATES='$(DEPENDENCY_PROVIDER_CC_CANDIDATES)' \
	DEPENDENCY_PROVIDER_PREFIXES='$(DEPENDENCY_PROVIDER_PREFIXES)' \
	"$(portdir)/Tools/Providers/pkg-config.sh"

dependency-provider-tool-discovery-command = \
	DEPENDENCY_PROVIDER_PREFIXES='$(DEPENDENCY_PROVIDER_PREFIXES)' \
	"$(portdir)/Tools/Providers/tool.sh"

dependency-provider-discovery-field = $(word $1,$(subst $(VERTICAL_BAR), ,$2))
dependency-provider-discovery-paths = $(if $(filter none,$1),,$(subst :, ,$1))
dependency-provider-discovery-policy-field = $(word $1,$(subst $(AT), ,$2))
dependency-provider-discovery-policy-exists = $(strip $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),\
	$(if $(and \
	  $(filter $1,$(call dependency-provider-discovery-policy-field,2,$p)),\
	  $(filter $2,$(call dependency-provider-discovery-policy-field,3,$p)),\
	  $(filter $3,$(call dependency-provider-discovery-policy-field,4,$p)),\
	  $(filter $4,$(call dependency-provider-discovery-policy-field,5,$p)),\
	  $(filter $5,$(call dependency-provider-discovery-policy-field,6,$p))),yes)))

define add-dependency-provider-discovery-policy
  $(if $(call dependency-provider-discovery-policy-exists,$1,$2,$(DEPENDENCY_BUILD_OPSYS),$(DEPENDENCY_BUILD_ARCH),$(dependency_discovery_origin)),,\
    $(eval DEPENDENCY_PROVIDER_POLICIES += system@$1@$2@$(DEPENDENCY_BUILD_OPSYS)@$(DEPENDENCY_BUILD_ARCH)@$(dependency_discovery_origin)@$(dependency_discovery_identity)))
endef

define apply-dependency-provider-discovery
  $(eval dependency_discovery_origin := $(call dependency-provider-discovery-field,3,$1))
  $(eval dependency_discovery_key := $(call dependency-provider-discovery-field,2,$1))
  $(eval dependency_discovery_identity := $(dependency-provider-profile)-$(if $(filter %-tool,$(dependency_discovery_key)),$(patsubst %-tool,%,$(dependency_discovery_key)),pkg-config)-$(DEPENDENCY_BUILD_ARCH))
  $(eval dependency_discovery_origin_key := $(subst /,_,$(dependency_discovery_origin)))
  $(eval DEPENDENCY_PROVIDER_CHECK.$(dependency_discovery_identity).$(dependency_discovery_origin_key) := true)
  $(eval DEPENDENCY_PROVIDER_INCLUDEDIRS.$(dependency_discovery_identity).$(dependency_discovery_origin_key) := $(call dependency-provider-discovery-paths,$(call dependency-provider-discovery-field,6,$1)))
  $(eval DEPENDENCY_PROVIDER_LIBDIRS.$(dependency_discovery_identity).$(dependency_discovery_origin_key) := $(call dependency-provider-discovery-paths,$(call dependency-provider-discovery-field,7,$1)))
  $(eval DEPENDENCY_PROVIDER_RUNTIMEDIRS.$(dependency_discovery_identity).$(dependency_discovery_origin_key) := $(call dependency-provider-discovery-paths,$(call dependency-provider-discovery-field,7,$1)))
  $(eval DEPENDENCY_PROVIDER_PKGCONFIGDIRS.$(dependency_discovery_identity).$(dependency_discovery_origin_key) := $(call dependency-provider-discovery-paths,$(call dependency-provider-discovery-field,8,$1)))
  $(eval DEPENDENCY_PROVIDER_BINDIRS.$(dependency_discovery_identity).$(dependency_discovery_origin_key) := $(call dependency-provider-discovery-paths,$(call dependency-provider-discovery-field,9,$1)))
  $(eval DEPENDENCY_PROVIDER_COMMANDS.$(dependency_discovery_identity).$(dependency_discovery_origin_key) := $(call dependency-provider-discovery-paths,$(call dependency-provider-discovery-field,11,$1)))
  $(eval dependency_discovery_context := $(or $(call dependency-provider-discovery-field,10,$1),both))
  $(if $(filter build both,$(dependency_discovery_context)),\
    $(foreach g,$(groups_all),$(call add-dependency-provider-discovery-policy,build,$g)))
  $(if $(filter target both,$(dependency_discovery_context)),\
    $(foreach g,$(groups_all),$(call add-dependency-provider-discovery-policy,target,$g)))
endef

define load-dependency-provider-discovery
  $(if $(filter yes,$(dependency-provider-discovery-enabled)),
    $(if $(dependency-provider-profile-error),$(error invalid dependency provider profile: $(dependency-provider-profile-error)))
    $(eval dependency_provider_registry_validation := $(shell $(dependency-provider-registries-validate-command)))
    $(if $(filter-out 0,$(.SHELLSTATUS)),$(error invalid dependency provider registry))
    $(eval dependency_provider_discovery := $(shell { $(dependency-provider-registry-input) :; } | $(dependency-provider-discovery-command) && { $(dependency-provider-tool-registry-input) :; } | $(dependency-provider-tool-discovery-command)))
    $(if $(filter-out 0,$(.SHELLSTATUS)),$(error dependency provider discovery failed))
    $(foreach d,$(dependency_provider_discovery),
      $(if $(filter available,$(call dependency-provider-discovery-field,4,$d)),
        $(call apply-dependency-provider-discovery,$d))))
endef

dependency-provider-registries-validate-command = \
	{ $(dependency-provider-registry-input) :; } | \
	  awk -v fail=1 -f "$(portdir)/Tools/dependency-provider-registry.awk" >/dev/null && \
	{ $(dependency-provider-tool-registry-input) :; } | \
	  awk -v fail=1 -f "$(portdir)/Tools/dependency-provider-tool-registry.awk" >/dev/null
