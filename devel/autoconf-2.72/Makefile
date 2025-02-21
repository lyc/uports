# Ports collection:	autoconf
# Date created:		6/Feb/2025
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= autoconf
DISTVERSION		= 2.72
CATEGORIES		= devel
MASTER_SITES		= $(MASTER_SITE_GNU)
MASTER_SITE_SUBDIR	= $(PORTNAME)

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= Generate configure scripts and related files

LICENSE			= GPLv3

USES			= tar:xz

VERSION			= $(DISTVERSION)

GNU_CONFIGURE		= yes
CONFIGURE_ARGS		= --program-suffix=$(VERSION)			\
			  --without-lispdir
CONFIGURE_ENV		= EMACS=no
ifneq ($(wildcard $(DESTDIR)$(PREFIX)/bin/m4),)
CONFIGURE_ENV		+= M4=$(DESTDIR)$(PREFIX)/bin/m4
endif

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
