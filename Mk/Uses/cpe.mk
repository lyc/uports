# Include CPE information in package manifest as a CPE 2.3 formatted
# string.
# See https://csrc.nist.gov/projects/security-content-automation-protocol/specifications/cpe
# for details.
#
# CPE_PART		Defaults to "a" for "application".
# CPE_VENDOR		Defaults to same as ${CPE_PRODUCT} (below).
# CPE_PRODUCT		Defaults to ${PORTNAME}.
# CPE_VERSION		Defaults to ${PORTVERSION}.
# CPE_UPDATE		Defaults to empty.
# CPE_EDITION		Defaults to empty.
# CPE_LANG		Defaults to empty.
# CPE_SW_EDITION	Defaults to empty.
# CPE_TARGET_SW		Defaults to the operating system name and version
# CPE_TARGET_HW		Defaults to x86 for i386, x64 for amd64, and
#			otherwise ${ARCH}.
# CPE_OTHER		Defaults to ${PORTREVISION} if non-zero.
#
# MAINTAINER: ports-secteam@FreeBSD.org
# MAINTAINER: yowching.lee@gmail.com

ifndef _INCLUDE_USES_CPE_MK
_INCLUDE_USES_CPE_MK	= yes

__SW_ARG		= -e 's/\..*//'
__HW_ARG		= -e 's/i386/x86/' -e 's/amd64/x64/'
__CPE_ARG		= -e 's/:+$//'

CPE_PART		?= a
CPE_PRODUCT		?= $(call tolower,$(PORTNAME))
CPE_VENDOR		?= $(CPE_PRODUCT)
CPE_VERSION		?= $(call tolower,$(PORTVERSION))
CPE_UPDATE		?=
CPE_EDITION		?=
CPE_LANG		?=
CPE_SW_EDITION		?=
CPE_TARGET_SW		?= $(call tolower,$(OPSYS))$(shell echo $(OSREL) | $(SED) $(__SW_ARG))
CPE_TARGET_HW		?= $(echo $(ARCH) | $(SED) $(_HW_ARGS))
ifneq ($(PORTVERSION),0)
CPE_OTHER		?= $(PORTREVISION)
endif
_CPE_STR	 	= cpe:2.3:$(CPE_PART):$(CPE_VENDOR):$(CPE_PRODUCT):$(CPE_VERSION):$(CPE_UPDATE):$(CPE_EDITION):$(CPE_LANG):$(CPE_SW_EDITION):$(CPE_TARGET_SW):$(CPE_TARGET_HW):$(CPE_OTHER)
CPE_STR			?= $(shell echo $(_CPE_STR) | $(SED) $(__CPE_ARG))

PKG_NOTES		+= cpe
PKG_NOTE_cpe		= $(CPE_STR)

endif
