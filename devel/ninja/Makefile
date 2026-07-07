# Ports collection:	ninja
# Date created:		2026/07/06
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= ninja
DISTVERSION		= 1.13.1
CATEGORIES		= devel
MASTER_SITES		= https://github.com/ninja-build/ninja/archive/refs/tags/
DISTFILES		= v$(DISTVERSION)$(EXTRACT_SUFX)
WRKSRC			= $(WRKDIR)/$(PORTNAME)-$(DISTVERSION)
DIST_SUBDIR		= $(PORTNAME)

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= Small build system closest in spirit to Make

LICENSE			= APACHE20
LICENSE_FILE		= $(WRKSRC)/COPYING

BUILD_DEPENDS		+= python3>=0:lang/cpython

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= do-build do-install

do-build:
	@cd $(WRKSRC) && python3 configure.py --bootstrap

do-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/bin
	@cp $(WRKSRC)/ninja $(STAGEDIR)$(PREFIX)/bin/ninja

include $(PORTSDIR)/Mk/linux.port.post.mk
