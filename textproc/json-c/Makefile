# Prts collection:	json-c
# Date created:		14/Feb/2006
# Whom:                 colin@askey.com.tw

PORTNAME		= json-c
DISTVERSION		= 0.16
DISTVERSIONSUFFIX	= -20220414
CATEGORIES		= textproc
MASTER_SITES 		= $(MASTER_SITE_GITHUB)
MASTER_SITE_SUBDIR	= $(PORTNAME)/$(PORTNAME)

MAINTAINER		= dtchang@askey.com.tw
COMMENT			= A JSON implementation in C

LICENSE			= MIT

USES			= cmake

ifeq ($(USE_SCM),git)
MASTER_SITES		:= github.com
MASTER_SITE_SUBDIR	:= json-c
NO_SCM_PATCH_APPLY	= yes
endif

EXTRACT_TRANSFORM	= /json-c-json-c/json-c/g

CMAKE_ARGS		+= -DCMAKE_INSTALL_LIBDIR=lib

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
