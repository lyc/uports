# Ports collection:	libtool
# Date created:		11/Feb/2025
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= libtool
DISTVERSION		= 2.5.4
CATEGORIES		= devel
MASTER_SITES		= $(MASTER_SITE_GNU)
MASTER_SITE_SUBDIR	= $(PORTNAME)

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= GNU Standard-compliant Makefile generator

LICENSE			= GPLv2+

USES			= tar:xz

GNU_CONFIGURE		= yes
CONFIGURE_ARGS		= --disable-ltdl-install

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
