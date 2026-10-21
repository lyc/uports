# Ports collection      readline
# Date created:         2013/11/18
# Whom:                 Max Lee <max_lee@pegatroncorp.com>

PORTNAME		= readline
DISTVERSION 		= 8.2
CATEGORIES 		= devel
MASTER_SITES		= GNU/readline					\
			  ftp://ftp.cwru.edu/pub/bash/

MAINTAINER 		= max_lee@pegatroncorp.com
COMMENT			= Library for editing command lines as they are typed

LICENSE			= GPL-3+

LIB_DEPENDS		= libncurses.so.6:devel/ncurses

USES			= libtool pkgconfig

#USE_LDCONFIG 		= yes
#USE_AUTOTOOLS 		= yes
GNU_CONFIGURE 		= yes
CONFIGURE_ARGS		+= --enable-shared				\
			   --with-shared-termcap-library		\
			   --with-curses


#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= post-patch post-install


post-patch:
	@for f in readline history; do 					\
	    $(SED) -e 's|%PREFIX%|$(PREFIX)|g ; s|%VERSION%|$(PORTVERSION)|g' \
	        $(FILESDIR)/$$f.pc.in > $(WRKDIR)/$$f.pc;		\
	done

post-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/lib/pkgconfig;			\
	for f in readline history; do 					\
	    cp $(WRKDIR)/$$f.pc $(STAGEDIR)$(PREFIX)/lib/pkgconfig;	\
	done

include $(PORTSDIR)/Mk/linux.port.post.mk
