# Ports collection:	expat2
# Date created:		31/OCT/2012
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME		= expat
PORTVERSION		= 2.1.0
CATEGORIES		= textproc
MASTER_SITES		= $(MASTER_SITE_SOURCEFORGE)
MASTER_SITE_SUBDIR	= expat
LICENSE			= MIT

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= XML 1.0 parser written by C


#USE_LDCONFIG		= yes
#USE_AUTOTOOLS		= yes
GNU_CONFIGURE		= yes
CONFIGURE_ARGS		+= --enable-shared				\
			   --prefix=$(PREFIX)				\
			   --exec-prefix=$(PREFIX)

ifneq ($(DESTDIR),)
MAKE_ARGS		+= INSTALL_ROOT="$(DESTDIR)"
endif

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
