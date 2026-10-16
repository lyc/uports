#
# linux.github.mk - GitHub archive declarations and grouped layout
#
# FreeBSD reference: ecc6a37c0d3d10f3a9212be604f70f720cf4b9d6.
# Independently implemented GNU make adapter; see 01-FETCH-CONTRACT.md.
#

ifneq ($(strip $(USE_GITHUB)),)
ifneq ($(filter-out yes nodefault,$(USE_GITHUB)),)
$(error USE_GITHUB supports yes and nodefault)
endif

GH_ACCOUNT		?= $(PORTNAME)
GH_PROJECT		?= $(PORTNAME)
GH_TAGNAME		?= $(DISTVERSIONFULL)
_GH_NODEFAULT		:= $(filter nodefault,$(USE_GITHUB))

# $(call github-quote, value)
github-quote		= '$(subst ','"'"',$1)'

# $(call github-field, record, field-number)
github-field		= $(word $2,$(subst |, ,$1))

# $(call github-record, group)
github-record		= $(filter $1|%,$(_GH_RECORDS))

_GH_RECORDS		:= $(shell				       \
	gh_portname=$(call github-quote,$(PORTNAME))		       \
	gh_distversion=$(call github-quote,$(DISTVERSIONFULL))	       \
	gh_account=$(call github-quote,$(GH_ACCOUNT))		       \
	gh_project=$(call github-quote,$(GH_PROJECT))		       \
	gh_tag=$(call github-quote,$(GH_TAGNAME))		       \
	gh_subdir=$(call github-quote,$(GH_SUBDIR))		       \
	gh_tuple=$(call github-quote,$(GH_TUPLE))		       \
	gh_nodefault=$(call github-quote,$(_GH_NODEFAULT))	       \
	awk -f "$(SCRIPTSDIR)/github-normalize.awk")

ifeq ($(strip $(_GH_RECORDS)),)
$(error GitHub declaration normalization failed)
endif
ifneq ($(filter ERROR|%,$(_GH_RECORDS)),)
$(error $(subst |, ,$(filter ERROR|%,$(_GH_RECORDS))) $(_GH_RECORDS))
endif

_GITHUB_GROUPS		:= $(foreach record,$(_GH_RECORDS),	       \
			    $(call github-field,$(record),1))

# $(call github-extract-tag, tag)
github-extract-tag	= $(shell printf '%s\n'			       \
	$(call github-quote,$(strip $1)) | sed			       \
	  -e 's|/|-|g' -e 's/^[vV]\([0-9]\)/\1/'		       \
	  -e 's/+/-/g' -e 's/--*/-/g')

# $(call github-group-fields, group)
define github-group-fields
GH_ACCOUNT_$1		:= $(call github-field,$(call github-record,$1),2)
GH_PROJECT_$1		:= $(call github-field,$(call github-record,$1),3)
GH_TAGNAME_$1		:= $(call github-field,$(call github-record,$1),4)
GH_SUBDIR_$1		:= $(filter-out -,			       \
  $(call github-field,$(call github-record,$1),5))
GH_TAGNAME_$1_SANITIZED	:= $$(subst /,-,$$(GH_TAGNAME_$1))
GH_TAGNAME_$1_EXTRACT	:= $(call github-extract-tag,		       \
  $(call github-field,$(call github-record,$1),4))
endef

$(foreach group,$(_GITHUB_GROUPS),				       \
  $(eval $(call github-group-fields,$(group))))

GH_TAGNAME_SANITIZED	= $(GH_TAGNAME_DEFAULT_SANITIZED)
GH_TAGNAME_EXTRACT	= $(GH_TAGNAME_DEFAULT_EXTRACT)

# $(call github-mirror-token, declaration)
github-mirror-token	= $(filter GH GITHUB,$(call get-file-name,$1))

# $(call github-mirror-sites, declaration)
define github-mirror-sites
$(foreach group,$(call remove-comma,				       \
  $(or $(call get-file-group,$1),DEFAULT)),			       \
  $(if $(GH_SITE_$(group)),$(GH_SITE_$(group)):$(group),	       \
    $(error No GitHub group '$(group)' declared for $1)))
endef

# $(call github-site, group)
github-site		= https://codeload.github.com/		       \
$(GH_ACCOUNT_$1)/$(GH_PROJECT_$1)/tar.gz/$(GH_TAGNAME_$1)?dummy=/

# $(call github-group-artifacts, group)
_GH_ALTERNATIVE		= $(filter yes,$(USE_ALTERNATIVE))
_GH_EXTRACT_ROOT	=					       \
	$(if $(_GH_ALTERNATIVE),$(ALTERNATIVE_WRKDIR),$(WRKDIR))
_GH_MAIN_ROOT		=					       \
	$(if $(_GH_ALTERNATIVE),$(ALTERNATIVE_WRKSRC),$(WRKSRC))

define github-group-artifacts
GH_SITE_$1		:= $(subst $(SPACE),,$(call github-site,$1))
_GH_BASENAME_$1		:= $(GH_ACCOUNT_$1)-$(GH_PROJECT_$1)
_GH_ROOTNAME_$1		:= $(GH_PROJECT_$1)-$(GH_TAGNAME_$1_EXTRACT)
DISTNAME_$1		= $$(_GH_BASENAME_$1)-$$(GH_TAGNAME_$1_SANITIZED)_GH0
DISTFILE_$1		= $$(DISTNAME_$1).tar.gz
WRKSRC_$1		= $$(_GH_EXTRACT_ROOT)/$$(_GH_ROOTNAME_$1)
endef

$(foreach group,$(_GITHUB_GROUPS),				       \
  $(eval $(call github-group-artifacts,$(group))))

ifeq ($(strip $(USE_SCM)),)
_GH_EXTRA_GROUPS		:= $(filter-out DEFAULT,$(_GITHUB_GROUPS))
ifeq ($(filter nodefault,$(USE_GITHUB)),)
_GH_SITE		= $(GH_SITE_DEFAULT)
_GH_DIST_PREFIX		= $(GH_ACCOUNT_DEFAULT)-$(GH_PROJECT_DEFAULT)
ifneq ($(GH_TAGNAME_DEFAULT),$(DISTVERSIONFULL))
_GH_DIST_PREFIX		:= $(_GH_DIST_PREFIX)-$(DISTVERSIONFULL)
endif
DISTNAME		= $(_GH_DIST_PREFIX)-$(GH_TAGNAME_SANITIZED)_GH0
DISTNAME_DEFAULT	= $(DISTNAME)
DISTFILES		+= $(DISTNAME).tar.gz
ifeq ($(filter GH GITHUB,$(MASTER_SITES)),)
MASTER_SITES		+= GH
endif
WRKSRC			?= $(WRKDIR)/$(GH_PROJECT_DEFAULT)-$(GH_TAGNAME_EXTRACT)
else
DISTFILES		?=
endif

# $(call github-declared-groups)
github-declared-groups	= $(foreach token,			       \
  $(filter GH:% GITHUB:%,$(MASTER_SITES)),			       \
  $(call remove-comma,$(word 2,$(subst :, ,$(token)))))

_GH_GROUP_SITES		:= $(foreach group,$(_GH_EXTRA_GROUPS),	       \
  $(if $(filter $(group),$(call github-declared-groups)),,	       \
    $(GH_SITE_$(group)):$(group)))
DISTFILES		+= $(foreach group,$(_GH_EXTRA_GROUPS),	       \
			    $(DISTFILE_$(group)):$(group))

# $(call github-layout, group)
github-layout		= $1|$(_GH_ROOTNAME_$1)|$(or $(GH_SUBDIR_$1),-)

_GH_LAYOUT		:= DEFAULT|-|$(or $(GH_SUBDIR_DEFAULT),-)
_GH_LAYOUT		+= $(foreach group,$(_GH_EXTRA_GROUPS),	       \
			    $(subst $(SPACE),,$(call github-layout,$(group))))
ifneq ($(strip $(_GH_EXTRA_GROUPS) $(GH_SUBDIR_DEFAULT)),)
_USES_extract		+= 690:github-place-sources

.PHONY: github-place-sources
github-place-sources:
	@GH_EXTRACT_ROOT="$(_GH_EXTRACT_ROOT)"			       \
	GH_MAIN_ROOT="$(_GH_MAIN_ROOT)"				       \
	$(SH) "$(SCRIPTSDIR)/github-place.sh"			       \
	  $(foreach record,$(_GH_LAYOUT),$(call github-quote,$(record)))
endif
else
ifneq ($(filter-out DEFAULT,$(_GITHUB_GROUPS)),)
$(error Grouped GitHub archives cannot use legacy USE_SCM; no Git mapping)
endif
endif
endif
