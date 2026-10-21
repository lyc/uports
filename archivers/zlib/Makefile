# Ports collection:     zlib
# Date created:         2011/6/24
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME 		= zlib
DISTVERSION 		= 1.3.2
CATEGORIES 		= archivers
MASTER_SITES		= https://www.zlib.net/				\
			  https://www.zlib.net/fossils/

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
