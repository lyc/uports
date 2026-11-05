#
# linux.flavor.mk - Flavor declarations, artifact identity and discovery
#

ifndef _INCLUDE_LINUX_FLAVOR_MK
_INCLUDE_LINUX_FLAVOR_MK	:= yes

FLAVORS			?=
flavor-declared		:= $(strip $(FLAVORS))
flavor-default		:= $(firstword $(flavor-declared))
flavor-name-chars	= $(chars_lower) 0 1 2 3 4 5 6 7 8 9 _

# $(call flavor-remove-chars, value, allowed-character-list)
define flavor-remove-chars
$(if $2,							       \
  $(call flavor-remove-chars,					       \
    $(subst $(firstword $2),,$1),$(wordlist 2,$(words $2),$2)),$1)
endef

ifneq ($(words $(flavor-declared)),$(words $(sort $(flavor-declared))))
$(error FLAVORS contains duplicate names: $(flavor-declared))
endif
$(foreach f,$(flavor-declared),					       \
  $(if $(strip $(call flavor-remove-chars,$f,$(flavor-name-chars))),   \
    $(error Invalid flavor name '$f'; use lowercase letters, digits or _)))

FLAVOR			?= $(flavor-default)
ifneq ($(strip $(FLAVOR)),)
ifneq ($(words $(FLAVOR)),1)
$(error FLAVOR must select exactly one declared flavor)
endif
ifneq ($(strip $(call flavor-remove-chars,$(FLAVOR),$(flavor-name-chars))),)
$(error Invalid FLAVOR='$(FLAVOR)'; use lowercase letters, digits or _)
endif
ifeq ($(filter $(FLAVOR),$(flavor-declared)),)
$(error Unsupported FLAVOR='$(FLAVOR)'; declared flavors:	       \
  $(or $(flavor-declared),none))
endif
else
ifneq ($(flavor-declared),)
$(error FLAVOR is empty; omit it to select $(flavor-default))
endif
endif

flavor-selected		:= $(or $(strip $(FLAVOR)),default)
flavor-active		:= $(if $(flavor-declared),$(flavor-selected))
flavor-work-suffix	= $(if $(flavor-active),.flavor-$(flavor-selected))
flavor-work-name		= work$(TYPE_SUFFIX)$(flavor-work-suffix)
flavor-source-identity	= $(if $(flavor-active),|flavor=$(flavor-selected))

# $(call flavor-value, helper-name, fallback-value)
# An explicitly empty helper is intentional, not an absent declaration.
define flavor-value
$(if $(flavor-declared),					       \
  $(call flavor-value-for,$(flavor-selected),$1,$2),$2)
endef

# $(call flavor-value-for, flavor, helper-name, fallback-value)
define flavor-value-for
$(if $(filter undefined,					       \
  $(origin $(strip $1)_$(strip $2))),$3,$($(strip $1)_$(strip $2)))
endef

# $(call flavor-name-prefix, flavor)
define flavor-name-prefix
$(strip $(call flavor-value-for,$1,PKGNAMEPREFIX,$(PKGNAMEPREFIX)))
endef

# $(call flavor-name-suffix, flavor)
define flavor-name-suffix
$(strip $(call flavor-value-for,$1,PKGNAMESUFFIX,$(PKGNAMESUFFIX)))
endef

# $(call flavor-name-base, flavor)
define flavor-name-base
$(call flavor-name-prefix,$1)$(PORTNAME)$(call flavor-name-suffix,$1)
endef

flavor-pkgnameprefix	= $(strip $(call flavor-value,		       \
			    PKGNAMEPREFIX,$(PKGNAMEPREFIX)))
flavor-pkgnamesuffix	= $(strip $(call flavor-value,		       \
			    PKGNAMESUFFIX,$(PKGNAMESUFFIX)))
flavor-package-stem	= $(flavor-pkgnameprefix)$(PORTNAME)
flavor-package-base	= $(flavor-package-stem)$(flavor-pkgnamesuffix)

# Use the port directory name; PORTNAME can be shared by versioned ports.
flavor-port-name	= $(notdir $(CURDIR))
# All extraction destinations use this effective root, not the shared base.
flavor-alternative-root	= $(ALTERNATIVE_WRKDIR)$(if		       \
	$(flavor-active),/$(flavor-port-name)/flavor-$(flavor-selected))

flavor-execution	:= legacy
ifneq ($(flavor-declared),)
flavor-execution	:= enabled
endif

endif

ifdef _POSTMKINCLUDED
ifndef _INCLUDE_LINUX_FLAVOR_POST_MK
_INCLUDE_LINUX_FLAVOR_POST_MK	:= yes

flavor-package-collisions := $(strip				       \
	$(foreach f,$(filter-out $(flavor-selected),$(flavor-declared)), \
	  $(if $(filter $(call flavor-name-base,$f),$(PKGBASE)),$f,    \
	    $(if $(filter $(call flavor-name-base,$f)-$(PKGVERSION),   \
	      $(PKGNAME)),$f))))
ifneq ($(flavor-package-collisions),)
$(error Flavor package identity collides with: $(flavor-package-collisions))
endif

ifneq ($(flavor-active),)
ifeq ($(filter %$(flavor-work-suffix),$(WRKDIR)),)
$(error Flavor WRKDIR must end in $(flavor-work-suffix))
endif
ifneq ($(notdir $(PKGFILE)),$(PKGNAME)$(PKG_SUFX))
$(error Flavor PKGFILE must use the selected package filename)
endif

# $(call flavor-confined-path, variable-name)
# Reject mutable artifact overrides outside the selected work namespace.
define flavor-confined-path
$(if $(filter $(abspath $(WRKDIR))/%,$(abspath $($1))),,	       \
  $(error $1 must be inside the selected flavor WRKDIR))
endef

$(foreach v,WRKSRC PATCH_WRKSRC CONFIGURE_WRKSRC		       \
	BUILD_WRKSRC INSTALL_WRKSRC STAGEDIR TMPPLIST SOURCE_STATE_FILE \
	DEPENDENCY_STATE_FILE EXTRACT_COOKIE PATCH_COOKIE	       \
	CONFIGURE_COOKIE BUILD_COOKIE STAGE_COOKIE INSTALL_COOKIE      \
	PACKAGE_COOKIE WRKDIR_PKGFILE,				       \
  $(call flavor-confined-path,$v))

ifeq ($(USE_ALTERNATIVE),yes)
ifeq ($(filter $(abspath $(flavor-alternative-root))/%,		       \
	$(abspath $(ALTERNATIVE_WRKSRC))),)
$(error ALTERNATIVE_WRKSRC must use the selected flavor source root)
endif
endif
endif

endif
endif
