# Ports collection:     openssl-1.0.0
# Date created:         2012/3/28
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME 		= openssl
PORTVERSION 		= 1.0.0
DISTVERSIONSUFFIX	= h
CATEGORIES 		= security
MASTER_SITES		= http://www.openssl.org/%SUBDIR%/		\
			  ftp://ftp.openssl.org/%SUBDIR%/		\
			  ftp://ftp.cert.dfn.de/pub/tools/net/openssl/%SUBDIR%/
MASTER_SITE_SUBDIR	= source
DIST_SUBDIR		= $(DISTNAME)
LICENSE			= OpenSSL SSLeay

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= SSL and crypto library

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
