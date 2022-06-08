# handle dependency on the pkgconf port
#
# Feature:	pkgconfig
# Usage:	USES=pkgconfig or USES=pkgconfig:ARGS
# Valid ARGS:	build (default, implicit), run, both
#
# MAINTAINER: ports@FreeBSD.org
# MAINTAINER:	yowching.lee@gmail.com

ifndef _INCLUDE_USES_PKGCONFIG_MK
_INCLUDE_USES_PKGCONFIG_MK = yes

_PKGCONFIG_DEPENDS	= pkgconf>=1.3.0_1:devel/pkgconf

ifeq ($(pkgconfig_ARGS),)
pkgconfig_ARGS		= build
endif

__dest_pkgconfig	= $(wildcard $(DESTDIR)$(PREFIX)/bin/pkg-config)
__host_pkgconfig	= $(shell which pkg-config)
__pkgconfig		= $(strip 					\
			    $(if $(DESTDIR),				\
			      $(if $(__dest_pkgconfig),			\
			        $(__dest_pkgconfig),			\
			        $(__host_pkgconfig)),			\
			      $(__host_pkgconfig)))

#$(warning DESTDIR=$(DESTDIR))
#$(warning __dest_pkgconfig=$(__dest_pkgconfig))
#$(warning __host_pkgconfig=$(__host_pkgconfig))
#$(warning __pkgconfig=$(__pkgconfig))
#$(warning PKG_CONFIG=$(PKG_CONFIG))

ifeq ($(pkgconfig_ARGS),build)
BUILD_DEPENDS		+= ${_PKGCONFIG_DEPENDS}
CONFIGURE_ENV		+= PKG_CONFIG=$(__pkgconfig)
else ifeq ($(pkgconfig_ARGS),run)
RUN_DEPENDS		+= ${_PKGCONFIG_DEPENDS}
else ifeq ($(pkgconfig_ARGS),both)
CONFIGURE_ENV		+= PKG_CONFIG=$(__pkgconfig)
BUILD_DEPENDS		+= ${_PKGCONFIG_DEPENDS}
RUN_DEPENDS		+= ${_PKGCONFIG_DEPENDS}
else
IGNORE			= USES=pkgconfig - invalid args: [${pkgconfig_ARGS}] specified
endif

check_if_pcdir		= $(if $(wildcard $1/pkgconfig/*.pc),$1/pkgconfig)

ifneq ($(DESTDIR),)
ifneq ($(__dest_pkgconfig),)
__pc_libdirs		+= $(call check_if_pcdir,$(DESTDIR)$(PREFIX)/lib)
__pc_libdirs		+= $(call check_if_pcdir,$(DESTDIR)$(PREFIX)/lib64)
_pc_libdirs		= $(call merge_dirs,$(__pc_libdirs))

ifeq ($(find-string PKG_CONFIG_LIBDIR,$(CONFIGURE_ENV)),)
CONFIGURE_ENV		+= PKG_CONFIG_LIBDIR=$(_pc_libdirs)		\
			   PKG_CONFIG_SYSROOT_DIR=$(DESTDIR)
endif

ifeq ($(find-string PKG_CONFIG_EXECUTABLE,$(CMAKE_ARGS)),)
CMAKE_ARGS		+= -DPKG_CONFIG_EXECUTABLE=$(__dest_pkgconfig)
endif

ifeq ($(filter $(DESTDIR)$(PREFIX)/bin,$(subst :, ,$(PATH))),)
export PATH		:= $(DESTDIR)$(PREFIX)/bin:$(PATH)
endif
endif
endif

#$(warning CONFIGURE_ENV=$(CONFIGURE_ENV))
#$(warning PATH=$(PATH))

endif
