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
GNU_CONFIGURE		= yes
CONFIGURE_ARGS		+= --enable-shared --enable-static
ADDITIONAL_HEADER	= jinclude.h jpegint.h

# define J_MAXMEM like "make J_MAXMEM=32" to limit max processing memory to 32Mb
ifneq ($(J_MAXMEM),)
CONFIGURE_ARGS		+= --enable-maxmem=$(J_MAXMEM)
endif

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+=						\
	post-extract post-patch post-build

post-extract:
	@cp $(DISTDIR)/$(DIST_SUBDIR)/jpegexiforient.c $(WRKSRC)
	@cp $(DISTDIR)/$(DIST_SUBDIR)/exifautotran.txt $(WRKSRC)/exifautotran

post-patch:
	@$(SED) -e 's|%PREFIX%|$(PREFIX)|g ; s|%VERSION%|$(DISTVERSION2)|g' \
		$(FILESDIR)/lib$(PORTNAME)-$(DISTVERSION2).pc.in >	\
		$(WRKDIR)/lib$(PORTNAME)-$(DISTVERSION2).pc

post-build:
	@cd $(WRKSRC) && $(CC) $(CFLAGS) -o jpegexiforient jpegexiforient.c

include $(PORTSDIR)/Mk/linux.port.post.mk
