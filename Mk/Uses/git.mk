# Bring gitfix scripts up to date.
#
# Feature:	git
# Usage:	USES=git or USES=git:args
# Valid args:	ownership  in aarch64 container, some of git version may
#                          complain "detected dubious ownership in $(WRKDIR)",
#                          add git config safe.directory variable temporary
#                          during init git repoistory.
#
# MAINTAINER:	yowching.lee@gmail.com

ifndef _INCLUDE_USES_GIT_MK
_INCLUDE_USES_GIT_MK	:= yes
_USES_POST		+= git
endif

ifdef _POSTMKINCLUDED
ifndef _INCLUDE_USES_GIT_POST_MK
_INCLUDE_USES_GIT_POST_MK= yes

ifeq ($(ARCH),aarch64)
ifneq ($(call find-uses-arg,ownership,$(git_ARGS)),)
quiet_cmd_set-gitval	?= GIT     $(PKGNAME) set safe.directory
      cmd_set-gitval	?= set -e;					\
	git config --global --add safe.directory `realpath $(WRKSRC)`

quiet_cmd_unset-gitval	?= GIT     $(PKGNAME) unset safe.directory
      cmd_unset-gitval	?= set -e;					\
	git config --global --unset safe.directory `realpath $(WRKSRC)`

_USES_patch		+= 120:set-gitval 870:unset-gitval
set-gitval:
	$(call cmd,set-gitval)
unset-gitval:
	$(call cmd,unset-gitval)
endif
endif

endif
endif
