# Bring libtool scripts up to date.
#
# Feature:	libtool
# Usage:	USES=libtool or USES=libtool:args
# Valid args:	keepla	Don't remove libtool libraries (*.la) from the stage
#			directory.  Some ports need them at runtime (e.g. ports
#			that call lt_dlopen from libltdl).
#		build	Add a build dependency on devel/libtool.  This can
#			be used when a port does not generate its own libtool
#			script and relies on the system to provide one.
#
# MAINTAINER:	tijl@FreeBSD.org
# MAINTAINER:	yowching.lee@gmail.com

ifndef _INCLUDE_USES_LIBTOOL_MK
_INCLUDE_USES_LIBTOOL_MK:= yes
_USES_POST		+= libtool

ifneq ($(call find-uses-arg,build,$(libtool_ARGS)),)
#BUILD_DEPENDS+=	libtool:devel/libtool
endif
endif

ifdef _POSTMKINCLUDED
ifndef _INCLUDE_USES_LIBTOOL_POST_MK
_INCLUDE_USES_LIBTOOL_POST_MK= yes

_USES_configure		+= 480:patch-libtool
patch-libtool:
	@echo $@

ifneq ($(call find-uses-arg,keepla,$(libtool_ARGS)),)
quiet_cmd_patch-lafiles?= PATCH   $(PKGNAME) lafiles
      cmd_patch-lafiles?= set -e;					\
	${FIND} ${STAGEDIR} -type f -name '*.la' |			\
		${XARGS} ${SED} -i -e "/dependency_libs=/s/=.*/=''/"
else
quiet_cmd_patch-lafiles?= RM      $(PKGNAME) lafiles
      cmd_patch-lafiles?= set -e;					\
	${FIND} ${STAGEDIR} -type l -exec ${SH} -c			\
		'case `${REALPATH} -q "{}"` in				\
			*.la) ${ECHO_CMD} "{}" ;; esac' \; |		\
		${XARGS} ${GREP} -l 'libtool library' | ${XARGS} ${RM};	\
	${FIND} ${STAGEDIR} -type f -name '*.la' |			\
		${XARGS} ${GREP} -l 'libtool library' | ${XARGS} ${RM}
endif

_USES_stage		+= 790:patch-lafiles
patch-lafiles:
	$(call cmd,patch-lafiles)

endif
endif
