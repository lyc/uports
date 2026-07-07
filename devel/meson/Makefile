# Ports collection:	meson
# Date created:		2026/07/06
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= meson
DISTVERSION		= 1.9.0
CATEGORIES		= devel
MASTER_SITES		= https://github.com/mesonbuild/meson/releases/download/$(DISTVERSION)/
DISTFILES		= $(DISTNAME)$(EXTRACT_SUFX)

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= High performance build system

LICENSE			= APACHE20
LICENSE_FILE		= $(WRKSRC)/COPYING

BUILD_DEPENDS		+= python3>=0:lang/cpython
RUN_DEPENDS		+= python3>=0:lang/cpython			\
			   ninja>=1.8:devel/ninja

NO_ARCH			= yes

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= post-patch do-build do-install

post-patch:
	@$(SED) -i -e '1s|python$$|python3|' \
	    $(WRKSRC)/mesonbuild/scripts/python_info.py

do-build:
	@$(DO_NADA)

do-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/bin
	@mkdir -p $(STAGEDIR)$(PREFIX)/share/$(PORTNAME)
	@cp $(WRKSRC)/meson.py $(STAGEDIR)$(PREFIX)/share/$(PORTNAME)/meson.py
	@cp -R $(WRKSRC)/mesonbuild $(STAGEDIR)$(PREFIX)/share/$(PORTNAME)
	@printf '%s\n' \
	    '#!/bin/sh' \
	    'exec python3 "$$(dirname "$$0")/../share/$(PORTNAME)/meson.py" "$$@"' \
	    > $(STAGEDIR)$(PREFIX)/bin/meson
	@chmod 755 $(STAGEDIR)$(PREFIX)/bin/meson

include $(PORTSDIR)/Mk/linux.port.post.mk
