# List:		https://sourceforge.net/p/forge/documentation/Mirrors/
# Updated:	2017-03-13
$(foreach p,https http,							\
  $(eval								\
    MASTER_SITE_SOURCEFORGE	+= $p://downloads.sourceforge.net/project/%SUBDIR%/))

$(foreach p,https http,							\
  $(foreach m,excellmedia freefr jaist nchc netcologne netix superb-dca2 superb-sea2 ufpr vorboss, \
  $(eval								\
      MASTER_SITE_SOURCEFORGE	+= $p://$m.dl.sourceforge.net/project/%SUBDIR%/)))

MASTER_SITE_SOURCEWARE		+=					\
	ftp://ftp.funet.fi/pub/mirrors/sources.redhat.com/pub/%SUBDIR%/	\
	ftp://ftp-stud.fht-esslingen.de/pub/Mirrors/sources.redhat.com/%SUBDIR%/

MASTER_SITE_GITHUB		+=					\
	https://github.com/%SUBDIR%/archive/refs/tags/

MASTER_SITE_GNU			+=					\
	http://ftp.gnu.org/gnu/%SUBDIR%/				\
	ftp://ftp.gnu.org/gnu/%SUBDIR%/					\
	http://www.gtlib.cc.gatech.edu/pub/gnu/gnu/%SUBDIR%/		\
	http://mirrors.usc.edu/pub/gnu/%SUBDIR%/			\
	http://ftp.funet.fi/pub/gnu/prep/%SUBDIR%/			\
	ftp://ftp.kddlabs.co.jp/GNU/%SUBDIR%/				\
	ftp://ftp.dti.ad.jp/pub/GNU/%SUBDIR%/				\
	ftp://ftp.mirrorservice.org/sites/ftp.gnu.org/gnu/%SUBDIR%/	\
	ftp://ftp.sunsite.org.uk/package/gnu/%SUBDIR%/			\
	ftp://ftp.informatik.hu-berlin.de/pub/gnu/%SUBDIR%/		\
	ftp://ftp.informatik.rwth-aachen.de/pub/mirror/ftp.gnu.org/pub/gnu/%SUBDIR%/ \
	ftp://ftp.rediris.es/sites/ftp.gnu.org/ftp/gnu/%SUBDIR%/	\
	ftp://ftp.chg.ru/pub/gnu/%SUBDIR%/

MASTER_SITE_GNOME		+=					\
	http://ftp.gnome.org/pub/GNOME/sources/%SUBDIR%/

#MASTER_SITES=	${MASTER_SITE_GNOME:S,%SUBDIR%,sources/glib/${PORTVERSION:C/^([0-9]+\.[0-9]+).*/\1/},} \
#		ftp://ftp.gtk.org/pub/glib/${PORTVERSION:C/^([0-9]+\.[0-9]+).*/\1/}/ \
#		ftp://ftp.gimp.org/pub/%SUBDIR%/ \
#		ftp://ftp.cs.umn.edu/pub/gimp/%SUBDIR%/ \
#		http://www.ameth.org/gimp/%SUBDIR%/ \
#		${MASTER_SITE_RINGSERVER:S,%SUBDIR%,graphics/gimp/%SUBDIR%,}
#MASTER_SITE_SUBDIR=	gtk/v${PORTVERSION:C/^([0-9]+\.[0-9]+).*/\1/}
#DIST_SUBDIR=	gnome2

MASTER_SITE_RINGSERVER		+=					\
	http://ring.nict.go.jp/archives/%SUBDIR%/			\
	http://ring.sakura.ad.jp/archives/%SUBDIR%/			\
	http://ring.riken.jp/archives/%SUBDIR%/

MASTER_SITE_MOZILLA		+=					\
	http://ftp.mozilla.org/pub/mozilla.org/%SUBDIR%/		\
	http://www.gtlib.cc.gatech.edu/pub/mozilla.org/%SUBDIR%/	\
	http://mozilla.gnusoft.net/%SUBDIR%/

#MASTER_SITE_MOZILLA		+=					\
#	ftp://ftp.mozilla.org/pub/mozilla.org/%SUBDIR%/			\
#	ftp://ftp.belnet.be/packages/mozilla/%SUBDIR%/			\
#	ftp://ftp.fh-wolfenbuettel.de/pub/www/mozilla/%SUBDIR%/		\
#	ftp://ftp.uni-bayreuth.de/pub/packages/netscape/mozilla/%SUBDIR%/ \
#	ftp://ftp.informatik.rwth-aachen.de/pub/mirror/ftp.mozilla.org/pub/%SUBDIR%/ \
#	$(MASTER_SITE_RINGSERVER:S,%SUBDIR%,net/www/mozilla/&,)
#	ftp://ftp.kaist.ac.kr/pub/mozilla/%SUBDIR%/			\
#	ftp://mozilla.mirror.pacific.net.au/mozilla/%SUBDIR%/		\
#	ftp://ftp.chg.ru/pub/WWW/mozilla/%SUBDIR%/

MASTER_SITE_MOZILLA_EXTENDED	+=					\
	http://releases.mozilla.org/pub/mozilla.org/%SUBDIR%/		\
	${MASTER_SITE_MOZILLA}
