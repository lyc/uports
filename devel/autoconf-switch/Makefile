# Ports collection:	autoconf-switch	
# Date created:		7/Feb/2025
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= autoconf
DISTVERSION		= 20250207
CATEGORIES		= devel
MASTER_SITES		=
PKGNAMESUFFIX		= -switch
DISTFILES		=

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= Wrapper script to switch bwtween autoconf versions

LICENSE			= BSD2CLAUS

FILES			= autoheader autom4te autoreconf autoscan autoupdate ifnames

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk
override_targets	= do-patch do-build do-install

do-patch:
do-build:
do-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/bin;				\
	cp $(FILESDIR)/$(PORTNAME) $(STAGEDIR)$(PREFIX)/bin/;		\
	chmod +x $(STAGEDIR)$(PREFIX)/bin/$(PORTNAME);			\
	for l in $(FILES); do						\
	    ln $(STAGEDIR)$(PREFIX)/bin/$(PORTNAME)			\
	       $(STAGEDIR)$(PREFIX)/bin/$${l};				\
	done

include $(PORTSDIR)/Mk/linux.port.post.mk

