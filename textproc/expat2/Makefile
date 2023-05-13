# Ports collection:	expat2
# Date created:		31/OCT/2012
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME		= expat
DISTVERSION		= 2.5.0
CATEGORIES		= textproc
MASTER_SITES		= https://github.com/lib$(PORTNAME)/lib$(PORTNAME)/releases/download/R_$(subst .,_,$(PORTVERSION))/

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= XML 1.0 parser written by C

LICENSE			= MIT
LICENSE_FILE		= $(WRKSRC)/COPYING

USES			= tar:xz libtool

GNU_CONFIGURE		= yes
CONFIGURE_ARGS		+= --enable-shared				\
			   --prefix=$(PREFIX)				\
			   --exec-prefix=$(PREFIX)
MAKE_ARGS		+= INSTALL_ROOT="$(STAGEDIR)"

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
