# Ports collection:    jpeg
# Date created:        2012/4/29
# Whom:                Max Lee <yowching.lee@gmail.com>

PORTNAME 		= jpeg
PORTVERSION 		= 8
PORTREVISION 		= 3
CATEGORIES 		= graphics
MASTER_SITES 		= http://www.ijg.org/files/			\
			  http://sylvana.net/jpegcrop/:exif
DISTNAME		= jpegsrc.v$(DISTVERSION2)
DISTFILES 		= $(DISTNAME)$(EXTRACT_SUFX)			\
			  jpegexiforient.c:exif exifautotran.txt:exif
DIST_SUBDIR		= $(PORTNAME)$(DISTVERSION2)2
EXTRACT_ONLY		= $(DISTNAME)$(EXTRACT_SUFX)

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= IJG's jpeg compression utilities #'

WRKSRC			= $(WRKDIR)/$(PORTNAME)-$(DISTVERSION2)
DISTVERSION2		= 8b

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+=						\
	post-extract post-patch

post-extract:
	@cp $(DISTDIR)/$(DIST_SUBDIR)/jpegexiforient.c $(WRKSRC)
	@cp $(DISTDIR)/$(DIST_SUBDIR)/exifautotran.txt $(WRKSRC)/exifautotran

post-patch:
	@$(SED) -e 's|%PREFIX%|$(PREFIX)|g ; s|%VERSION%|$(DISTVERSION2)|g' \
		$(FILESDIR)/lib$(PORTNAME)-$(DISTVERSION2).pc.in >	\
		$(WRKDIR)/lib$(PORTNAME)-$(DISTVERSION2).pc

include $(PORTSDIR)/Mk/linux.port.post.mk
