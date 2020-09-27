# Ports collection:	webp
# Date created:		2020/05/01
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME 		= webp
PORTVERSION 		= 1.1.0
CATEGORIES 		= graphics
MASTER_SITES 		= http://downloads.webmproject.org/releases/webp/ \
			  https://storage.googleapis.com/downloads.webmproject.org/releases/webp/
DISTNAME		= lib$(PORTNAME)-$(PORTVERSION)
LICENSE			= BSD3CLAUSE

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= Google WebP image format conversion tool


ifeq ($(USE_SCM),git)
SCM_PROTOCOL		= https://
MASTER_SITES		:= chromium.googlesource.com
SCM_REPO_PREFIX		= webm/lib
endif

GNU_CONFIGURE		= yes
CONFIGURE_ARGS		+= --enable-libwebpdecoder			\
			   --enable-libwebpdemux			\
			   --enable-libwebpmux
ifneq ($(WITH_GL),yes)
CONFIGURE_ARGS		+= --disable-gl
endif

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
