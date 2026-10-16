#
# linux.github.mk - single-repository GitHub archive declarations
#
# Semantics follow FreeBSD ports ecc6a37c0d3d10f3a9212be604f70f720cf4b9d6.
# Independently implemented GNU make adapter; see 01-FETCH-CONTRACT.md.
#

ifneq ($(strip $(USE_GITHUB)),)
ifneq ($(USE_GITHUB),yes)
$(error USE_GITHUB currently supports only yes; groups/nodefault are pending)
endif

GH_ACCOUNT		?= $(PORTNAME)
GH_PROJECT		?= $(PORTNAME)
GH_TAGNAME		?= $(DISTVERSIONFULL)

# $(call github-quote, value)
github-quote		= '$(subst ','"'"',$1)'

# $(call github-valid, value, pattern)
github-valid		= $(shell printf '%s\n'			       \
			    $(call github-quote,$1) | LC_ALL=C	       \
			    grep -E $(call github-quote,$2))

_GH_NAME_PATTERN	= ^[A-Za-z0-9_][A-Za-z0-9_.-]*$$
_GH_TAG_PATTERN		= ^[A-Za-z0-9_][A-Za-z0-9_./+-]*$$

$(foreach field,GH_ACCOUNT GH_PROJECT,				       \
  $(if $(call github-valid,$($(field)),$(_GH_NAME_PATTERN)),,	       \
    $(error Invalid $(field); grouped declarations are not supported yet)))
$(if $(call github-valid,$(GH_TAGNAME),$(_GH_TAG_PATTERN)),,	       \
  $(error Invalid GH_TAGNAME; use one ungrouped tag or commit))

ifneq ($(strip $(GH_TUPLE) $(GH_SUBDIR)),)
$(error GH_TUPLE/GH_SUBDIR require grouped-source support, not yet implemented)
endif
ifneq ($(filter GH:% GITHUB:%,$(MASTER_SITES)),)
$(error Grouped GitHub sites are not implemented yet)
endif
ifneq ($(filter master main HEAD refs/heads/%,$(GH_TAGNAME)),)
$(error GH_TAGNAME must identify a release tag or commit, not a moving branch)
endif

GH_TAGNAME_SANITIZED	= $(subst /,-,$(GH_TAGNAME))
GH_TAGNAME_EXTRACT	:= $(shell printf '%s\n'		       \
			$(call github-quote,$(GH_TAGNAME_SANITIZED))   \
			    | sed -e 's/^[vV]\([0-9]\)/\1/'	       \
			        -e 's/+/-/g' -e 's/--*/-/g')

ifeq ($(strip $(USE_SCM)),)
_GH_PATH		=					       \
	$(GH_ACCOUNT)/$(GH_PROJECT)/tar.gz/$(GH_TAGNAME)?dummy=/
_GH_SITE		= https://codeload.github.com/$(_GH_PATH)
_GH_DIST_PREFIX		= $(GH_ACCOUNT)-$(GH_PROJECT)
ifneq ($(GH_TAGNAME),$(DISTVERSIONFULL))
_GH_DIST_PREFIX		:= $(_GH_DIST_PREFIX)-$(DISTVERSIONFULL)
endif
DISTNAME		= $(_GH_DIST_PREFIX)-$(GH_TAGNAME_SANITIZED)_GH0
DISTFILES		+= $(DISTNAME).tar.gz
ifeq ($(filter GH GITHUB,$(MASTER_SITES)),)
MASTER_SITES		+= GH
endif
WRKSRC			?= $(WRKDIR)/$(GH_PROJECT)-$(GH_TAGNAME_EXTRACT)
endif
endif
