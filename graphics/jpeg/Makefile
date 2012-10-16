# Ports collection:    jpeg
# Date created:        2012/4/29
# Whom:                Max Lee <yowching.lee@gmail.com>

PORTNAME 		= jpeg
PORTVERSION 		= 8
PORTREVISION 		= 3
CATEGORIES 		= graphics
MASTER_SITES 		= http://www.ijg.org/files/ \
			  http://sylvana.net/jpegcrop/:exif
DISTNAME		= jpegsrc.v$(DISTVERSION2)
DISTFILES 		= $(DISTNAME)$(EXTRACT_SUFX) \
			  jpegexiforient.c:exif exifautotran.txt:exif
EXTRACT_ONLY		= $(DISTNAME)$(EXTRACT_SUFX)

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= IJG's jpeg compression utilities

WRKSRC			= $(WRKDIR)/$(PORTNAME)-$(DISTVERSION2)
DISTVERSION2		= 8d

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= \
	post-extract

post-extract:
	@cp $(DISTDIR)/jpegexiforient.c $(WRKSRC)
	@cp $(DISTDIR)/exifautotran.txt $(WRKSRC)/exifautotran

include $(PORTSDIR)/Mk/linux.port.post.mk
