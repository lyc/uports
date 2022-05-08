# Ports collection:     gmp
# Date created:         3/March/2013
# Whom:                 Max Lee

PORTNAME		= gmp
PORTVERSION		= 5.0.2
PORTREVISION		= 0
CATEGORIES		= devel
MASTER_SITES		= ftp://ftp.gmplib.org/pub/gmp/

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= The GNU Multiple Precision Arithmetic Library


# FIXME: should put this setting into project template makefile.
# Assume we are trying to build a toolchain which config as $(CONFIGURE_TARGET),
# it's a good idea to install gpm/mpfr/mpc ... outside the folder $(PREFIX)
# toolchain will be installed.
ifneq ($(CONFIGURE_TARGET),)
ifneq ($(PREFIX),)
override PREFIX		:= $(PREFIX)/tools
endif
endif

USES			+= tar:bzip2 libtool:keepla

GNU_CONFIGURE		= yes
ifneq ($(CONFIGURE_TARGET),)
WRKSRC_SUBDIR		:= build-$(word 1,$(subst -, ,$(CONFIGURE_TARGET)))
CONFIGURE_SCRIPT	= ../configure
else
CONFIGURE_SCRIPT	= configure
endif
CONFIGURE_ENV		+= CPPFLAGS=-fexceptions
CONFIGURE_ARGS		+= --enable-cxx					\
			   --with-gnu-ld
ALL_TARGET		= all check

# NOTE: there is no need to set --target=... during configure because
# gmp/mpfr/mpc ... was only built as host tool to support "binutils"
# and "gcc" building, so we need to unset $(CONFIGURE_TARGET) if it's set.
ifneq ($(CONFIGURE_TARGET),)
override CONFIGURE_TARGET	:=
endif

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
