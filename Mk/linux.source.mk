#
# linux.source.mk - source backend selection and compatibility mapping
#

ifndef _INCLUDE_LINUX_SOURCE_MK
_INCLUDE_LINUX_SOURCE_MK := yes

ifneq ($(strip $(USE_SCM)),)
ifneq ($(USE_SCM),git)
$(error Unsupported USE_SCM=$(USE_SCM); only git is available)
endif
endif
ifeq ($(origin SOURCE_MODE),undefined)
_SOURCE_MODE_EXPLICIT	:= no
_SOURCE_MODE		:= $(if $(filter git,$(USE_SCM)),git,dist)
else
_SOURCE_MODE_EXPLICIT	:= yes
_SOURCE_MODE		:= $(strip $(SOURCE_MODE))
ifeq ($(_SOURCE_MODE),)
$(error SOURCE_MODE was selected but is empty; use dist or git)
endif
ifneq ($(filter-out dist git,$(_SOURCE_MODE)),)
$(error Unsupported SOURCE_MODE=$(_SOURCE_MODE); use dist or git)
endif
endif

SOURCE_MODE_EFFECTIVE	:= $(_SOURCE_MODE)

endif

ifdef _POSTMKINCLUDED
ifndef _INCLUDE_LINUX_SOURCE_POST_MK
_INCLUDE_LINUX_SOURCE_POST_MK := yes

ifeq ($(_SOURCE_MODE_EXPLICIT):$(_SOURCE_MODE),yes:git)
_SOURCE_ROOT_SUFFIX	= -git
WRKSRC			?= $(WRKDIR)/$(DISTNAME)$(_SOURCE_ROOT_SUFFIX)
SCM_DEST		?= $(notdir $(WRKSRC))
endif

# Deferred until all hosted-source and SCM compatibility declarations load.
_SOURCE_PROVIDER	= $(if $(strip $(USE_GITHUB)),github,plain)
_SOURCE_REF_KIND	= $(strip					\
			    $(if $(strip $(SCM_BRANCH)),branch,		\
			      $(if $(strip $(SCM_DETACH)),		\
			        $(if $(strip $(USE_GITHUB)),		\
			          tag-or-commit,commit),default)))
_SOURCE_REF		= $(or $(SCM_BRANCH),$(SCM_DETACH),-)
SOURCE_STATE_FILE	?= $(WRKDIR)/source.state
_SOURCE_ROOT_IDENTITY	= $(if						\
			    $(filter $(WRKDIR)/%,$(WRKSRC)),		\
			    $(patsubst $(WRKDIR)/%,%,$(WRKSRC)),	\
			    $(WRKSRC))
source-request-identity = mode=$(_SOURCE_MODE)|				\
provider=$(_SOURCE_PROVIDER)|repository=$(or $(SCM_REPO_URL),-)|	\
ref-kind=$(_SOURCE_REF_KIND)|ref=$(_SOURCE_REF)|			\
root=$(_SOURCE_ROOT_IDENTITY)|						\
archives=$(strip $(DISTFILES) $(PATCHFILES))|				\
layout=$(strip $(_GH_RECORDS))
# $(call source-quote, value)
source-quote		= '$(subst ','"'"',$1)'
source-identity-key	= $(shell printf '%s\n'				\
			    $(call source-quote,			\
			      $(source-request-identity)) |		\
			    $(SH) $(SCRIPTSDIR)/source-hash.sh | cut -c1-16)

_USES_extract		+= 875:uports-source-state-save

.PHONY: uports-source-metadata
uports-source-metadata:
	@printf '%s\n'							\
	  'source_mode=$(_SOURCE_MODE)'					\
	  'source_mode_explicit=$(_SOURCE_MODE_EXPLICIT)'		\
	  'source_provider=$(_SOURCE_PROVIDER)'				\
	  'source_repository=$(or $(SCM_REPO_URL),-)'			\
	  'source_ref_kind=$(_SOURCE_REF_KIND)'				\
	  'source_ref=$(_SOURCE_REF)'					\
	  'source_root=$(WRKSRC)'
endif
endif
