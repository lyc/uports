# Ports collection:	cli-parser
# Date created:		04/OCT/2017
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME		= cliparser
PORTVERSION		= 0.5
CATEGORIES		= textproc
MASTER_SITES		= $(MASTER_SITE_SOURCEFORGE)
MASTER_SITE_SUBDIR	= cliparser
DISTNAME		= cli_parser-$(PKGVERSION)

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= CLI Parser provides a framework for quickly development of Cisco-like CLI commands.

LICENSE			= BSD

USE_REINPLACE		= yes

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= post-patch do-configure pre-install post-install
ALL_TARGET		= unix
MAKE_ENV		+= OPSYS=$(OPSYS) VERSION=$(PORTVERSION) REVISION=1

post-patch:
	@$(SED) -e 's|%PREFIX%|$(PREFIX)|g ; s|%VERSION%|$(PORTVERSION)|g' \
		$(FILESDIR)/$(PORTNAME).pc.in > $(WRKDIR)/$(PORTNAME).pc

do-configure:

pre-install:
	@mkdir -p $(addprefix $(STAGEDIR)$(PREFIX)/,lib/pkgconfig)

post-install:
	@cp $(WRKDIR)/$(PORTNAME).pc $(STAGEDIR)$(PREFIX)/lib/pkgconfig

include $(PORTSDIR)/Mk/linux.port.post.mk
