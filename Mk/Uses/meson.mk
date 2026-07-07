# Provide support for Meson based projects.
#
# Feature:	meson
# Usage:	USES=meson
#
# MAINTAINER:	yowching.lee@gmail.com

ifndef _INCLUDE_USES_MESON_MK
_INCLUDE_USES_MESON_MK	= yes

BUILD_DEPENDS		+= meson>=0.53:devel/meson			\
			   ninja>=1.8:devel/ninja

ifneq ($(DESTDIR),)
ifeq ($(filter $(DESTDIR)$(PREFIX)/bin,$(subst :, ,$(PATH))),)
export PATH		:= $(DESTDIR)$(PREFIX)/bin:$(PATH)
endif
endif

MESON_BIN		?= $(shell which meson)
NINJA_BIN		?= $(shell which ninja)

MESON_BUILD_DIR		?= $(WRKDIR)/.build
CONFIGURE_WRKSRC	= $(MESON_BUILD_DIR)
BUILD_WRKSRC		?= $(MESON_BUILD_DIR)
INSTALL_WRKSRC		?= $(MESON_BUILD_DIR)
TEST_WRKSRC		?= $(MESON_BUILD_DIR)

MESON_ARGS		+= --prefix=$(PREFIX)				\
			   --libdir=lib				\
			   --buildtype=release

ifneq ($(CC),)
CONFIGURE_ENV		+= CC="$(CC)"
endif
ifneq ($(CXX),)
CONFIGURE_ENV		+= CXX="$(CXX)"
endif
ifneq ($(CFLAGS),)
CONFIGURE_ENV		+= CFLAGS="$(CFLAGS)"
endif
ifneq ($(CPPFLAGS),)
CONFIGURE_ENV		+= CPPFLAGS="$(CPPFLAGS)"
endif
ifneq ($(CXXFLAGS),)
CONFIGURE_ENV		+= CXXFLAGS="$(CXXFLAGS)"
endif
ifneq ($(LDFLAGS),)
CONFIGURE_ENV		+= LDFLAGS="$(LDFLAGS)"
endif

quiet_cmd_run-meson	?= MESON   $(PKGNAME)
      cmd_run-meson	?= set -e;					\
	mkdir -p $(CONFIGURE_WRKSRC);					\
	cd $(CONFIGURE_WRKSRC);						\
	$(SETENV) $(CONFIGURE_ENV) $(MESON_BIN) setup $(MESON_ARGS) $(WRKSRC)

quiet_cmd_run-ninja-build	?= NINJA   $(PKGNAME)
      cmd_run-ninja-build	?= set -e;				\
	cd $(BUILD_WRKSRC);						\
	$(SETENV) $(MAKE_ENV) $(NINJA_BIN) $(NINJA_ARGS)

quiet_cmd_run-ninja-install	?= NINJA   $(PKGNAME)(install)
      cmd_run-ninja-install	?= set -e;				\
	cd $(INSTALL_WRKSRC);						\
	$(SETENV) $(MAKE_ENV) DESTDIR=$(STAGEDIR) $(NINJA_BIN) install

override_targets	+= do-configure do-build do-install

do-configure:
	$(call cmd,run-meson)

do-build:
	$(call cmd,run-ninja-build)

do-install:
	$(call cmd,run-ninja-install)

endif
