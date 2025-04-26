# Ports collection:	libtool
# Date created:		11/Feb/2025
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= libtool
PORTREVISION		= 0

COMMENT			= Generic shared library support script

include                 $(CURDIR)/../libtool/Makefile.common

LICENSE			= GPLv2+
LICENSE_FILE		= $(WRKSRC)/COPYING

GNU_CONFIGURE		= yes
CONFIGURE_ARGS		= --disable-ltdl-install

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
