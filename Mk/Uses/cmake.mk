# Provide support for CMake based projects
#
# Feature:		cmake
# Usage:		USES=cmake or USES=cmake:ARGS
# Valid ARGS:		insource, run, noninja, testing
# ARGS description:
# insource		do not perform an out-of-source build
# noninja		don't use ninja instead of make
#			Setting this should be an exception, and hints to an issue
#			inside the ports build system.
#			A few corner cases never use ninja, and are handled, to reduce
#			the usage of 'noninja'.:
#				1) fortran ports
#				2) ports that set BUILD_- or INSTALL_WRKSRC to
#				   something different than CONFIGURE_WRKSRC
# run			add a runtime dependency on cmake
# testing		add the test target based on ctest
#			Additionally, CMAKE_TESTING_ON, CMAKE_TESTING_OFF, CMAKE_TESTING_ARGS, CMAKE_TESTING_TARGET
#			can be defined to override the default values.
#
#
# Additional variables that affect cmake behaviour:
#
# User defined variables:
# CMAKE_NOCOLOR		- Disable colour build output
#			Default: not set, unless BATCH or PACKAGE_BUILDING is defined
#
# Variables for ports:
# CMAKE_ON		Appends -D<var>:bool=ON  to the CMAKE_ARGS,
# CMAKE_OFF		Appends -D<var>:bool=OFF to the CMAKE_ARGS.
# CMAKE_ARGS		- Arguments passed to cmake
#			Default: see below
# CMAKE_BUILD_TYPE	- Type of build (cmake predefined build types).
#			Projects may have their own build profiles.
#			CMake supports the following types: Debug,
#			Release, RelWithDebInfo and MinSizeRel.
#			Debug and Release profiles respect system
#			CFLAGS, RelWithDebInfo and MinSizeRel will set
#			CFLAGS to "-O2 -g" and "-Os -DNDEBUG".
#			Default: Release, if WITH_DEBUG is not set,
#			Debug otherwise
# CMAKE_SOURCE_PATH	- Path to the source directory
#			Default: ${WRKSRC}
#
# MAINTAINER: kde@FreeBSD.org
# MAINTAINER: yowching.lee@gmail.com

ifndef _INCLUDE_USES_CMAKE_MK
_INCLUDE_USES_CMAKE_MK	= yes

_valid_ARGS		= insource run noninja testing

# Sanity check
define check-if-valid
ifeq ($(findstring $1,$(_valid_ARGS)),)
IGNORE=	Incorrect 'USES+= cmake:${cmake_ARGS}' usage: argument [$1] is not recognized
endif
endef

$(foreach t,$(call remove-comma,$(cmake_ARGS)),				\
  $(eval								\
    $(call check-if-valid,$t)))

BUILD_DEPENDS		+= $(CMAKE_BIN):devel/cmake

ifneq ($(DESTDIR),)
ifeq ($(filter $(DESTDIR)$(PREFIX)/bin,$(subst :, ,$(PATH))),)
export PATH		:= $(DESTDIR)$(PREFIX)/bin:$(PATH)
endif
endif
CMAKE_BIN		= $(shell which cmake)

ifneq ($(call find-uses-arg,run,$(cmake_ARGS)),)
RUN_DEPENDS		+= ${CMAKE_BIN}:devel/cmake
endif

ifdef WITH_DEBUG
CMAKE_BUILD_TYPE?=	Debug
else
CMAKE_BUILD_TYPE?=	Release
endif

#PLIST_SUB+=		CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:tl}"

#.  if defined(STRIP) && ${STRIP} != "" && !defined(WITH_DEBUG)
#INSTALL_TARGET?=	install/strip
#.  endif

CMAKE_ARGS		+= -DCMAKE_C_COMPILER:STRING="${CC}"		\
			   -DCMAKE_C_FLAGS:STRING="${CFLAGS}"		\
			   -DCMAKE_C_FLAGS_DEBUG:STRING="${CFLAGS}"	\
			   -DCMAKE_C_FLAGS_RELEASE:STRING="${CFLAGS}"	\
			   -DCMAKE_CXX_COMPILER:STRING="${CXX}"		\
			   -DCMAKE_CXX_FLAGS:STRING="${CXXFLAGS}"	\
			   -DCMAKE_CXX_FLAGS_DEBUG:STRING="${CXXFLAGS}"	\
			   -DCMAKE_CXX_FLAGS_RELEASE:STRING="${CXXFLAGS}" \
			   -DCMAKE_EXE_LINKER_FLAGS:STRING="${LDFLAGS}"	\
			   -DCMAKE_MODULE_LINKER_FLAGS:STRING="${LDFLAGS}" \
			   -DCMAKE_SHARED_LINKER_FLAGS:STRING="${LDFLAGS}" \
			   -DCMAKE_INSTALL_PREFIX:PATH="${CMAKE_INSTALL_PREFIX}"\
			   -DCMAKE_BUILD_TYPE:STRING="${CMAKE_BUILD_TYPE}" \
			   -DTHREADS_HAVE_PTHREAD_ARG:BOOL=YES		\
			   -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=YES

ifeq ($(PORTS_VERBOSE),0)
CMAKE_BIN_ARGS		?= --no-warn-unused-cli
else
CMAKE_ARGS		+= -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON
endif

# Handle the option-like CMAKE_ON and CMAKE_OFF lists.
define add-on-off
CMAKE_ARGS		+= $(addprefix -D,$(addsuffix :BOOL=$1,$(CMAKE_$1)))
endef
$(foreach t,ON OFF,$(eval $(call add-on-off,$t)))

CMAKE_INSTALL_PREFIX	?= $(PREFIX)

ifdef BATCH
CMAKE_NOCOLOR		= yes
endif
ifdef PACKAGE_BUILDING
CMAKE_NOCOLOR		= yes
endif

ifdef CMAKE_NOCOLOR
CMAKE_ARGS		+= -DCMAKE_COLOR_MAKEFILE:BOOL=OFF
endif

_CMAKE_MSG=		"===>  Performing in-source build"
CMAKE_SOURCE_PATH	?= $(WRKSRC)

ifeq ($(call find-uses-arg,insource,$(cmake_ARGS)),)
_CMAKE_MSG		= "===>  Performing out-of-source build"
CONFIGURE_WRKSRC	= $(WRKDIR)/.build
BUILD_WRKSRC		?= $(CONFIGURE_WRKSRC)
INSTALL_WRKSRC		?= $(CONFIGURE_WRKSRC)
TEST_WRKSRC		?= $(CONFIGURE_WRKSRC)
endif

## By default we use the ninja generator.
##  Except, if cmake:run is set (cmake not wanted as generator)
##             fortran is used, as the ninja-generator does not handle it.
##             or if CONFIGURE_WRKSRC does not match  BUILD_WRKSRC or INSTALL_WRKSRC
##             as the build.ninja file won't be where ninja expects it.
#.  if empty(cmake_ARGS:Mnoninja) && empty(cmake_ARGS:Mrun) && empty(USES:Mfortran)
#.    if "${CONFIGURE_WRKSRC}" == "${BUILD_WRKSRC}" && "${CONFIGURE_WRKSRC}" == "${INSTALL_WRKSRC}"
#.      if ! empty(USES:Mgmake)
#BROKEN=		USES=gmake is incompatible with cmake's ninja-generator
#.      endif
#.      include "${USESDIR}/ninja.mk"
#.    endif
#.  endif

quiet_cmd_run-cmake	?= $(_CMAKE_MSG)
      cmd_run-cmake	?= set -e;					\
	mkdir -p $(CONFIGURE_WRKSRC);				\
	cd $(CONFIGURE_WRKSRC); $(SETENV) $(CONFIGURE_ENV) $(CMAKE_BIN) $(CMAKE_BIN_ARGS) $(CMAKE_ARGS) $(CMAKE_SOURCE_PATH)

override_targets 	+= do-configure

do-configure:
	$(call cmd,run-cmake)

#.  if !target(do-test) && ${cmake_ARGS:Mtesting}
#CMAKE_TESTING_ON?=		BUILD_TESTING
#CMAKE_TESTING_TARGET?=		test
#
## Handle the option-like CMAKE_TESTING_ON and CMAKE_TESTING_OFF lists.
#.    for _bool_kind in ON OFF
#.      if defined(CMAKE_TESTING_${_bool_kind})
#CMAKE_TESTING_ARGS+=		${CMAKE_TESTING_${_bool_kind}:C/.*/-D&:BOOL=${_bool_kind}/}
#.      endif
#.    endfor
#
#do-test:
#	@cd ${BUILD_WRKSRC} && \
#		${SETENV} ${CONFIGURE_ENV} ${CMAKE_BIN} ${CMAKE_ARGS} ${CMAKE_TESTING_ARGS} ${CMAKE_SOURCE_PATH} && \
#		${SETENV} ${MAKE_ENV} ${MAKE_CMD} ${_MAKE_JOBS} ${MAKE_ARGS} ${ALL_TARGET} && \
#		${SETENV} ${MAKE_ENV} ${MAKE_CMD} ${MAKE_ARGS} ${CMAKE_TESTING_TARGET}
#.  endif

endif
