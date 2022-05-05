# handle tar archives
#
# Feature:	tar
# Usage:	USES=tar[:[xz|lz|lzma|txz|bz[ip]2|tgz|tbz|tbz2|Z]]
#
# MAINTAINER: ports@FreeBSD.org
# MAINTAINER: yowching.lee@gmail.com

ifndef _INCLUDE_USES_TAR_MK
_INCLUDE_USES_TAR_MK := yes

ifeq ($(tar_ARGS),xz)
EXTRACT_SUFX 		?= .tar.xz
else ifeq ($(tar_ARGS),lz)
EXTRACT_SUFX 		?= .tar.lz
else ifeq ($(tar_ARGS),lzma)
EXTRACT_SUFX 		?= .tar.lzma
else ifeq ($(tar_ARGS),txz)
EXTRACT_SUFX 		?= .txz
else ifeq ($(tar_ARGS),bz2)
EXTRACT_SUFX 		?= .tar.bz2
else ifeq ($(tar_ARGS),bzip2)
EXTRACT_SUFX 		?= .tar.bz2
else ifeq ($(tar_ARGS),tgz)
EXTRACT_SUFX 		?= .tgz
else ifeq ($(tar_ARGS),tbz)
EXTRACT_SUFX 		?= .tbz
else ifeq ($(tar_ARGS),tbz2)
EXTRACT_SUFX 		?= .tbz2
else ifeq ($(tar_ARGS),Z)
EXTRACT_SUFX 		?= .tar.Z
else ifeq ($(tar_ARGS),)
EXTRACT_SUFX 		?= .tar
else
IGNORE			= Incorrect 'USES+=tar:$(tar_ARGS)'
endif

endif
