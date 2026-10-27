#
# linux.flavor.mk - Flavor declarations and read-only discovery
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
flavor-execution	:= legacy
ifneq ($(flavor-declared),)
flavor-execution	:= pending
ifeq ($(flavor-selected),$(flavor-default))
flavor-execution	:= legacy-default
endif
endif

endif
