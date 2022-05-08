# Ports collection:     zlib-1.2.7
# Date created:         2011/6/24
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME 		= zlib
PORTVERSION 		= 1.2.11
CATEGORIES 		= archivers
MASTER_SITES		= http://www.gzip.org/%SUBDIR%/			\
			  http://www.zlib.net/
MASTER_SITE_SUBDIR	= zlib

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= A Massively Spiffy Yet Delicately Unobrtusive Compression Library.

LICENSE			= zlib

GNU_CONFIGURE		= yes
ifneq ($(CROSS_COMPILE),)
# TODO: We may need to add dynamic symbol for shared library build.
#   refer to version script in TLPI ch#41 & ch#42 for detail.
#   "libpng.sym & libpng.vers" two makefile targets can be fonud in png port.
# FIXED: zlib configure use $uname to set share library build options...
ifneq ($(filter Linux linux,$(subst -, ,$(CROSS_COMPILE))),)
CONFIGURE_ARGS		+= --uname=linux
endif
# zlib makefile use CHOST instead of --host=...
CONFIGURE_ENV		+= CHOST=$(CROSS_COMPILE)
DONT_USE_HOST_TRIPLET	= yes
endif

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
