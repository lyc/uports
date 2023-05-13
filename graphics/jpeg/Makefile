# Ports collection:    jpeg
# Date created:        2012/4/29
# Whom:                Max Lee <yowching.lee@gmail.com>

PORTNAME 		= jpeg
DISTVERSION		= 9e
CATEGORIES 		= graphics
MASTER_SITES 		= http://www.ijg.org/files/
DISTNAME		= $(PORTNAME)src.v$(DISTVERSIONFULL)

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= libjpeg is a free library with functions for handling the JPEG image data format

LICENSE			= BSD-like IJG

USES			= libtool

WRKSRC			= $(WRKDIR)/$(PORTNAME)-$(DISTVERSION)
GNU_CONFIGURE		= yes
CONFIGURE_ARGS		+= --enable-shared --enable-static

# define J_MAXMEM like "make J_MAXMEM=32" to limit max processing memory to 32Mb
ifneq ($(J_MAXMEM),)
CONFIGURE_ARGS		+= --enable-maxmem=$(J_MAXMEM)
endif

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
