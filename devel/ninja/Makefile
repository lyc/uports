# Ports collection:	ninja
# Date created:		2026/07/06
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= ninja
DISTVERSIONPREFIX	= v
DISTVERSION		= 1.13.1
CATEGORIES		= devel
USE_GITHUB		= yes
GH_ACCOUNT		= ninja-build
DIST_SUBDIR		= $(PORTNAME)

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= Small build system closest in spirit to Make

LICENSE			= APACHE20
LICENSE_FILE		= $(WRKSRC)/COPYING

BUILD_DEPENDS		+= python3>=0:lang/cpython
PYTHON			?= python3

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= do-build do-install

do-build:
	@cd $(WRKSRC) && $(PYTHON) configure.py --bootstrap

do-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/bin
	@cp $(WRKSRC)/ninja $(STAGEDIR)$(PREFIX)/bin/ninja

include $(PORTSDIR)/Mk/linux.port.post.mk
