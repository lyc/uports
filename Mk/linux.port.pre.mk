#
# linux.port.pre.mk
#

# $(call subdirectory,makefile)
subdirectory		= $(patsubst %/$1,%,				\
			    $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))

PORTSDIR		:= $(abspath $(call subdirectory,linux.port.pre.mk)/..)

ifneq ($(PORTS_PARTIAL_SPECIALIZATION),yes)
include $(PORTSDIR)/Mk/linux.debug.mk
endif

$(if $(_PREMKINCLUDED),							\
  $(error $(PKGNAME): You cannot inlcude linux.port[.pre].mk twice))
_PREMKINCLUDED		:= yes

TAR			?= tar
XZCAT			?= $(shell which xzcat)
XZ_CMD			?= $(shell which xz)
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
EGREP			?= egrep
GIT			?= git

# cpu-vendor-os
# cpu-vendor-kernel-system
#
# ex:                                   ARCH    /         / OPSYS  / OPSYS_SUFX
#                                       -------   -------   ------   ----------
#   following from config.guess running on Debian and macOS system
#
#   - x86_64-unknown-linux-gnu       => x86_64  / unknown / linux  / gnu
#   - x86_64-apple-darwin17.7.0      => x86_64  / apple   / darwin / Mach-O
#
#   and following from toolchains which we met in some projects ever
#
#   - x86_64-onie-linux-uclibc       => x86_64  / onie    / linux  / uclibc
#   - arm7-marvell-linux-gnueabi     => marvell / marvell / linux  / gnueabi
#   - mips-linux-uclibc              => mips    /         / linux  / uclibc
#   - arm-none-linux-gnueabe         => arm     / none    / linux  / gnueabi
#   - i386-elf (from coreboot, none of OS, and will not be processed in Ports)

triplet.cpu		= $(word 1,$(subst -, ,$1))
triplet.os		= $(strip					\
			    $(if $(findstring darwin,$1),		\
			      darwin Mach-O,				\
			      $(if $(findstring linux,$1),		\
			        $(subst -, ,				\
			          $(word 2,$(subst -linux, linux,$1))),	\
			        $(error Oops, can't identify system)))) #'

triplet.kernel		?= $(word 1,$(call triplet.os,$1))
triplet.system		?= $(word 2,$(call triplet.os,$1))

# $(warning CROSS_COMPILE=$(CROSS_COMPILE))

# Get the architecture
ifeq ($(ARCH),)
ifneq ($(CROSS_COMPILE),)
ARCH			?= $(call triplet.cpu,$(CROSS_COMPILE))
else
ARCH			?= $(shell uname -m)
endif
ARCH			?= $(shell $(UNAME) -m)
endif

# Get the operating system type
ifeq ($(OPSYS),)
ifneq ($(CROSS_COMPILE),)
OPSYS			?= $(call triplet.kernel,$(CROSS_COMPILE))
OPSYS_SUFX		?= $(call triplet.system,$(CROSS_COMPILE))
else
OPSYS			?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
endif
endif

# $(warning ARCH=$(ARCH))
# $(warning OPSYS=$(OPSYS))
# $(warning OPSYS_SUFX=$(OPSYS_SUFX))

# $(call generate-config-all, cfg_name)
define generate-config-all
$1_1st			= $(config_$1)/$1.$(OPSYS)-$(OPSYS_SUFX)-$(ARCH)
$1_2nd			= $(config_$1)/$1.$(OPSYS)-$(OPSYS_SUFX)
$1_3rd			= $(config_$1)/$1.$(OPSYS)-$(ARCH)
$1_4th			= $(config_$1)/$1.$(OPSYS)
$1_default		= $(config_$1)/$1
$1_all			= $(wildcard $(config_$1)/$1*)
endef

# $(call config.lookup, cfg_name)
#   proper config_name will be matched and return by following order:
#      1. cfg_name.$(OPSYS)-$(OPSYS_SUFX)-$(ARCH)
#      2. cfg_name.$(OPSYS)-$(OPSYS_SUFX)
#      3. cfg_name.$(OPSYS)-$(ARCH)
#      4. cfg_name.$(OPSYS)
#      5. cfg_name
#
define config.lookup
$(strip									\
  $(if $(filter $($1_1st),$($1_all)), $($1_1st),			\
     $(if $(filter $($1_2nd),$($1_all)), $($1_2nd),			\
       $(if $(filter $($1_3rd),$($1_all)), $($1_3rd),			\
         $(if $(filter $($1_4th),$($1_all)), $($1_4th), $($1_default))))))
endef

# Get the operating system revision
__OSREL_ARG		= -e 's/[-(].*//'
ifeq ($(OSREL),)
OSREL			?= $(shell $(UNAME) -r | $(SED) $(__OSREL_ARG))
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

LOCALBASE		?= /usr/local
DISTDIR			?= $(PORTSDIR)/distfiles
_DISTDIR		?= $(patsubst %/,%,$(DISTDIR)/$(DIST_SUBDIR))

ifeq ($(USE_XZ),yes)
EXTRACT_SUFX 		?= .tar.xz
else
ifeq ($(USE_BZIP2),yes)
EXTRACT_SUFX 		?= .tar.bz2
else
ifeq ($(USE_ZIP),yes)
EXTRACT_SUFX 		?= .zip
else
EXTRACT_SUFX 		?= .tar.gz
endif
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

PREFIX			?= $(LOCALBASE)

PKG_SUFX		?= .txz
ifneq ($(OPSYS_SUFX),)
PKGREPOSITORYSUBDIR	?= $(OPSYS)-$(OPSYS_SUFX)-$(ARCH)
else
PKGREPOSITORYSUBDIR	?= $(OPSYS)-$(ARCH)
endif
PKGREPOSITORY		?= $(PACKAGES)/$(PKGREPOSITORYSUBDIR)
ifneq ($(wildcard $(PACKAGES)),)
PKGFILE			?= $(PKGREPOSITORY)/$(PKGNAME)$(PKG_SUFX)
else
PKGFILE			?= $(CURDIR)/$(PKGNAME)$(PKG_SUFX)
endif

PATCHLIST_NAME		?= series
PLIST_NAME		?= pkg-plist

config_$(PATCHLIST_NAME)= $(PATCHDIR)
config_$(PLIST_NAME)	= $(PKGDIR)
config_all		= $(PATCHLIST_NAME) $(PLIST_NAME)
$(foreach t,$(config_all),$(eval $(call generate-config-all,$t)))

#
# default target
#
all: install
