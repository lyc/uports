# Ports collection:     zlib
# Date created:         2011/6/24
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME 		= zlib
DISTVERSION 		= 1.2.13
CATEGORIES 		= archivers
MASTER_SITES		= http://www.gzip.org/%SUBDIR%/			\
			  http://www.zlib.net/
MASTER_SITE_SUBDIR	= zlib

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= A Massively Spiffy Yet Delicately Unobrtusive Compression Library.

LICENSE			= zlib

USES			+= cmake

GNU_CONFIGURE		= yes

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
