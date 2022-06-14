# Ports collection:	pkg-config
# Date created:		29/April/2008
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= pkg-config
DISTVERSION		= 0.29.2
PORTREVISION		= 0
CATEGORIES		= devel
MASTER_SITES		= http://pkgconfig.freedesktop.org/releases/
DIST_SUBDIR		= gnome2

MAINTAINER		= gnome@FreeBSD.org
COMMENT			= A utility to retrieve information about installed libraries

LICENSE			= GPLv2

ifeq ($(PC_PATH),)
PC_PATH			= $(LOCALBASE)/lib/pkgconfig
ifneq ($(LOCALBASE),$(PREFIX))
PC_PATH			:= $(PREFIX)/lib/pkgconfig
endif
endif
GNU_CONFIGURE		= yes
CONFIGURE_ARGS		= --disable-shared				\
			  --disable-threads				\
			  --disable-host-tool				\
			  --with-internal-glib				\
			  --with-pc-path="$(PC_PATH)"

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
