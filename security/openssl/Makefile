# Ports collection:     openssl-1.0.0
# Date created:         2012/3/28
# Whom:                 Max Lee <yowching.lee@gmail.com>

PORTNAME 		= openssl
PORTVERSION 		= 1.0.1
DISTVERSIONSUFFIX	= g
CATEGORIES 		= security
MASTER_SITES		= http://www.openssl.org/%SUBDIR%/		\
			  ftp://ftp.openssl.org/%SUBDIR%/		\
			  ftp://ftp.cert.dfn.de/pub/tools/net/openssl/%SUBDIR%/
MASTER_SITE_SUBDIR	= source
DIST_SUBDIR		= $(DISTNAME)
LICENSE			= OpenSSL SSLeay

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= Secure Sockets Layer and cryptography libraries

# just for test purpose
#
#PATCH_DIST_STRIP	= -p1
#PATCH_SITES		+= http://git.alpinelinux.org/cgit/aports/plain/main/openssl/:padlock
#PATCHFILES		+=						\
#	0001-crypto-hmac-support-EVP_MD_CTX_FLAG_ONESHOT-and-set-.patch:padlock \
#	0002-engines-e_padlock-backport-cvs-head-changes.patch:padlock \
#	0003-engines-e_padlock-implement-sha1-sha224-sha256-accel.patch:padlock \
#	0004-crypto-engine-autoload-padlock-dynamic-engine.patch:padlock

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.mk
