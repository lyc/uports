# Ports collection      ncurses
# Date created:         2017/09/03
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME		= ncurses
DISTVERSION 		= 6.5
CATEGORIES 		= devel
MASTER_SITES 		= $(MASTER_SITE_GNU)
MASTER_SITE_SUBDIR	= $(PORTNAME)

MAINTAINER 		= yowching.lee@gmail.com
COMMENT			= Library for terminal-independ, full screen output

LICENSE			= MIT

USES			= libtool pkgconfig

#AWK			= $(shell which gawk)
#$(if $(AWK),,$(error Oops, ncurses-6.0 need "gawk" ...))

CONFIGURE_ARGS		+= --with-shared
ifneq ($(WITH_TEST),yes)
CONFIGURE_ARGS		+= --without-develop				\
			   --without-debug				\
			   --without-tests
else
CONFIGURE_ARGS		+= --with-pthread				\
			   --enable-pthread-inter			\
			   --enable-reentrant				\
			   --with-valgrind				\
			   --disable-leaks
endif
#CONFIGURE_ARGS		+= --enable-widec
CONFIGURE_ARGS		+= --enable-overwrite				\
			   --without-ada				\
			   --enable-sigwinch				\
			   --disable-mixed-case				\
			   --disable-widec				\
			   --without-manpages				\
			   --with-install-prefix			\
			   --enable-pc-files				\
			   --with-pkg-config-libdir=$(PREFIX)/lib/pkgconfig
#CONFIGURE_ENV		+= AWK=$(AWK)
GNU_CONFIGURE 		= yes
USE_LDCONFIG 		= yes

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
