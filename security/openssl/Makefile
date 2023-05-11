# Ports collection:     openssl
# Date created:         2012/3/28
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME 		= openssl
DISTVERSION 		= 1.1.1
DISTVERSIONSUFFIX	= s
PORTREVISION		= 2
PORTEPOCH		= 1
CATEGORIES 		= security
MASTER_SITES		= http://www.openssl.org/%SUBDIR%/		\
			  ftp://ftp.openssl.org/%SUBDIR%/		\
			  ftp://ftp.cert.dfn.de/pub/tools/net/openssl/%SUBDIR%/
MASTER_SITE_SUBDIR	= source
DIST_SUBDIR		= $(DISTNAME)

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= Secure Sockets Layer and cryptography libraries

LICENSE			= OpenSSL SSLeay

USES			= git:ownership

LIB_DEPENDS		= libz.so:archivers/zlib

ifneq ($(CROSS_COMPILE),)
  CONFIGURE_SCRIPT	:= Configure
    CONFIGURE_ENV	+= CROSS_COMPILE=
  CONFIGURE_ARGS	+= shared
  ifneq ($(filter arm,$(subst -, ,$(CROSS_COMPILE))),)
    CONFIGURE_ARGS	+= linux-armv4
  endif
  ifneq ($(filter mips,$(subst -, ,$(CROSS_COMPILE))),)
    CONFIGURE_ARGS	+= linux-mipsel
  endif
  # ignore CONFIGURE_HOST because Openssl has its own build system...
  DONT_USE_HOST_TRIPLET	= yes
else
  CONFIGURE_SCRIPT	:= config
  ifeq ($(shell uname -s),Darwin)
      CONFIGURE_SCRIPT	:= Configure
    ifeq ($(shell uname -m),x86_64)
      CONFIGURE_ARGS	+= darwin64-x86_64-cc
    endif
    ifeq ($(shell uname -m),arm64)
      CONFIGURE_ARGS	+= darwin64-arm64-cc
    endif
  endif
endif
GNU_CONFIGURE		= yes
CONFIGURE_ARGS		+= --openssldir=$(PREFIX)/lib/ssl		\
			   enable-rc5					\
			   no-asm					\
			   shared
CONFIGURE_ARGS		+= zlib
MAKE_ARGS		+= INSTALL_PREFIX="$(STAGEDIR)"

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
