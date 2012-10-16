#
# linux.port.pre.mk
#

ifneq ($(PORTS_PARTIAL_SPECIALIZATION),yes)
include $(PORTSDIR)/Mk/linux.debug.mk
endif

$(if $(_PREMKINCLUDED),							\
  $(error $(PKGNAME): You cannot inlcude linux.port[.pre].mk twice))
_PREMKINCLUDED		:= yes

TAR			?= tar
BZCAT			?= $(shell which bzcat)
BZIP2_CMD		?= $(shell which bzip2)
$(if $(BZIP2_CMD),,$(error Sorry, ports need "bzip2" package...))
#GNUZIP_CMD		?= $(shell which gnuzip) -f
_gzip			?= $(shell which gzip)
_gzcat			?= $(shell which gzcat)
ifeq ($(_gzcat),)
ifeq ($(_gzip),)
$(error Sorry, ports need "gzcat" utility that did not exist on your distribution.  You can create a symbolic to "gzip" to fix this problem)
else
GZCAT			?= $(_gzip) -dc
endif
else
GZCAT			?= $(_gzcat)
endif
ifneq ($(_gzip),)
GZIP			?= -9
GZIP_CMD		?= $(_gzip) -nf $(GZIP)
endif
SETENV			?= env
SH			?= /bin/sh
UNAME			?= uname
SED			?= sed
WHICH			?= which
GREP			?= grep

# Get the architecture
ifeq ($(ARCH),)
ARCH			?= $(shell $(UNAME) -m)
endif

# Get the operating system type
ifeq ($(OPSYS),)
OPSYS			?= $(shell $(UNAME) -s)
endif

PORTREVISION		?= 0
ifneq ($(PORTREVISION),0)
_SUF1			= _$(PORTREVISION)
endif

PORTEPOCH		?= 0
ifneq ($(PORTEPOCH),0)
_SUF2			= ,$(PORTEPOCH)
endif

MASTERDIR		?= $(CURDIR)

ifneq ($(findstring $(OPSYS),Linux Darwin),)
PORTSDIR		?= $(MASTERDIR)/../..
else
ifeq ($(OPSYS),NetBSD)
PORTSDIR		?= /usr/opt
else
PORTSDIR		?= /usr/ports
endif
endif

LOCALBASE		?= /usr/local
DISTDIR			?= $(PORTSDIR)/distfiles
_DISTDIR		?= $(patsubst %/,%,$(DISTDIR)/$(DIST_SUBDIR))

ifeq ($(USE_BZIP2),yes)
EXTRACT_SUFX 		?= .tar.bz2
else
ifeq ($(USE_ZIP),yes)
EXTRACT_SUFX 		?= .zip
else
EXTRACT_SUFX 		?= .tar.gz
endif
endif

DISTVERSION		?= $(PORTVERSION)

PKGVERSION		?= $(PORTVERSION)$(_SUF1)$(_SUF2)
PKGNAME			?=						\
	$(PKGNAMEPREFIX)$(PORTNAME)$(PKGNAMESUFFIX)-$(PKGVERSION)
DISTNAME		?=						\
	$(PORTNAME)-$(DISTVERSIONPREFIX)$(DISTVERSION)$(DISTVERSIONSUFFIX)

PACKAGES		?= $(PORTSDIR)/packages
TEMPLATES		?= $(PORTSDIR)/Templates

PATCHDIR		?= $(MASTERDIR)/files
FILESDIR		?= $(MASTERDIR)/files
SCRIPTDIR		?= $(MASTERDIR)/scripts
PKGDIR			?= $(MASTERDIR)

#
# default target
#
all: install
