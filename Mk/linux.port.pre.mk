#
# linux.port.pre.mk
#

ifneq ($(PORTS_PARTIAL_SPECIALIZATION),yes)
include $(PORTSDIR)/Mk/linux.debug.mk
endif

$(if $(_PREMKINCLUDED),							\
  $(error $(PKGNAME): You cannot inlcude linux.port[.pre].mk twice))
_PREMKINCLUDED		:= yes

SETENV			?= env
SH			?= /bin/sh
UNAME			?= uname

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

PKGNAME			=						\
	$(PKGNAMEPREFIX)$(PORTNAME)$(PKGNAMESUFFIX)-$(PORTVERSION)$(_SUF1)$(_SUF2)
DISTNAME		?= $(PORTNAME)-$(PORTVERSION)

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
