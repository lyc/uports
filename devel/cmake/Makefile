# Ports collection:	cmake
# Date created:		2023/3/31
# Whom:			Max Lee <yowching.lee@gmail.com>

PORTNAME		= cmake
DISTVERSION		= 3.30.0
CATEGORIES		= devel
# Keep the release asset rather than a GitHub-generated source snapshot.
MASTER_SITES		= https://github.com/Kitware/CMake/releases/download/v$(DISTVERSION)/

MAINTAINER		= yowching.lee@gmail.com
COMMENT			= CMake is an open-source, cross-platform family of tools designed to build, test and package software.

LICENSE			= BSD3CLAUSE

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= pre-build

pre-build:
	@cd $(WRKSRC) &&						\
	./bootstrap --prefix=$(PREFIX) --			\
		-DCMAKE_USE_OPENSSL=OFF				\
		-DBUILD_CursesDialog=OFF

include $(PORTSDIR)/Mk/linux.port.post.mk
