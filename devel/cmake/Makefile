# Ports collection:	cmake
# Date created:		2023/3/31
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= cmake
DISTVERSION		= 3.30.0
CATEGORIES		= devel
MASTER_SITES		= https://github.com/Kitware/Cmake/releases/download/v$(PORTVERSION)/

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= CMake is an open-source, cross-platform family of tools designed to build, test and package software.

LICENSE			= BSD3CLAUSE

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= pre-build pre-install post-install

pre-build:
	@cd $(WRKSRC) &&						\
	./bootstrap --prefix=$(DESTDIR)$(PREFIX) -- -DCMAKE_USE_OPENSSL=OFF

pre-install:
	@cd $(WRKSRC) &&						\
	mv cmake_install.cmake cmake_install.cmake.bak &&		\
	sed -e 's|$(DESTDIR)$(PREFIX)|$(PREFIX)|'			\
		< cmake_install.cmake.bak > cmake_install.cmake

post-install:
	@cd $(WRKSRC) && 						\
	if [ -f cmake_install.cmake.bak ]; then				\
	    mv cmake_install.cmake.bak cmake_install.cmake; 		\
	fi

include $(PORTSDIR)/Mk/linux.port.post.mk
