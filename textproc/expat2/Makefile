# Ports collection:	expat2
# Date created:		31/OCT/2012
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME		= expat
DISTVERSION		= 2.1.0
CATEGORIES		= textproc
MASTER_SITES		= $(MASTER_SITE_SOURCEFORGE)
MASTER_SITE_SUBDIR	= expat

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= XML 1.0 parser written by C

LICENSE			= MIT

USES			= libtool:keepla

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
