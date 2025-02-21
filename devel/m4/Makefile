# Ports collection:	m4
# Date created:		5/Feb/2025
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= m4
DISTVERSION		= 1.4.19
CATEGORIES		= devel
MASTER_SITES		= $(MASTER_SITE_GNU)
MASTER_SITE_SUBDIR	= $(PORTNAME)

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= GNU M4

LICENSE			= GPLv3

USES			= tar:xz

GNU_CONFIGURE		= yes
CONFIGURE_ARGS		= --disable-nls					\
			  --without-libiconv-prefix

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
