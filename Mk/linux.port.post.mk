#
# linux.port.post.mk
#

$(if $(_POSTMKINCLUDED),						\
  $(error $(PKGNAME): You cannot inlcude linux.port[.post].mk twice))
_POSTMKINCLUDED		:= yes

WRKDIR			?= $(WRKDIRPREFIX)$(MASTERDIR)/work

ifneq ($(NO_WRKSUBDIR),yes)
WRKSRC			?= $(WRKDIR)/$(DISTNAME)
else
WRKSRC			?= $(WRKDIR)
endif

PATCH_WRKSRC		?= $(WRKSRC)
CONFIGURE_WRKSRC	?= $(WRKSRC)
BUILD_WRKSRC		?= $(WRKSRC)
INSTALL_WRKSRC		?= $(WRKSRC)

# Name of cookies used to skip already completed stages
EXTRACT_COOKIE		?= $(WRKDIR)/extract._done.$(PKGNAME)
PATCH_COOKIE		?= $(WRKDIR)/patch._done.$(PKGNAME)
CONFIGURE_COOKIE	?= $(WRKDIR)/configure._done.$(PKGNAME)
BUILD_COOKIE		?= $(WRKDIR)/build._done.$(PKGNAME)
INSTALL_COOKIE		?= $(WRKDIR)/install._done.$(PKGNAME)
PACKAGE_COOKIE		?= $(WRKDIR)/package._done.$(PKGNAME)

# Special macro for doing in-place file editing using regexps
ifeq ($(USE_REINPLACE),yes)
REINPLACE_ARGS		?= -i.bak
REINPLACE_CMD		?= $(SED) $(REINPLACE_ARGS)
endif

# How to do nothing.  Override if you, for some strange reason, would rather
# do something.
DO_NADA			?= true


# stuff for fetch ...

# Popular master sites
include $(PORTSDIR)/Mk/linux.sites.mk

# The primary backup site.

#ifeq ($(USE_MYFTP),yes)
#$(if $(FTP_URL),,							\
#  $(error You did not set \"FTP_URL\" but already set \"USE_MYFTP\" to yes))
#MASTER_SITE_BACKUP	?= $(FTP_URL)/$(DIST_SUBDIR)/
#endif

MASTER_SITE_BACKUP	:=						\
	$(shell echo $(MASTER_SITE_BACKUP) | sed -e 's|\$(DIST_SUBDIR)/$$||')

# Set MASTER_SITE_OVERRIDE properly if the user want to fetch source
# from his/her own repository firstly, but don't search it twice
# by appending it to the end,
#ifeq ($(USE_MYFTP),yes)
#__master_site_override	:= $(MASTER_SITE_BACKUP)
#__master_site_backup	:=
#else
__master_site_override	:= $(MASTER_SITE_OVERRIDE)
__master_site_backup	:= $(MASTER_SITE_BACKUP)
#endif

# Organize DISTFILES, PATCHFILES, _MASTER_SITES_ALL, _PATCH_SITES_ALL
# according to grouping rules (:something)
DISTFILES		?= $(DISTNAME)$(EXTRACT_SUFX)

SLASH			:= /
COMMON			:= ,
SUBDIR			:= %SUBDIR%

remove-common		= $(subst $(COMMON), ,$1)
remove-terminator	= $(patsubst %/,%,$1)
add-terminator-DEFAULT	= $(call remove-terminator,$1)/:DEFAULT

# NOTE: Beware get-site-name will erase tail slash
get-file-name		= $(word 1,$(subst :, ,$1))
get-file-group		= $(word 2,$(subst :, ,$1))
get-site-name		= $(word 1,$(subst /:, ,$1))
get-site-group		= $(word 2,$(subst /:, ,$1))

# $(call get-all-files, lists)
define get-all-files
$(sort									\
  $(foreach x,$1,							\
    $(call get-file-name,$x)))
endef

_DISTFILES		= $(call get-all-files,$(DISTFILES))
_PATCHFILES		= $(call get-all-files,$(PATCHFILES))
ALLFILES		?= $(_DISTFILES) $(_PATCHFILES)

# $(call patch-sites-DEFAULT, lists)
define patch-sites-DEFAULT
$(foreach x,$1,								\
  $(if $(call get-site-group,$x),					\
    $x,$(call add-terminator-DEFAULT,$x)))
endef

master_sites		= $(call patch-sites-DEFAULT,$(MASTER_SITES))
master_site_subdir	= $(call patch-sites-DEFAULT,$(MASTER_SITE_SUBDIR))
patch_sites		= $(call patch-sites-DEFAULT,$(PATCH_SITES))
patch_site_subdir	= $(call patch-sites-DEFAULT,$(PATCH_SITE_SUBDIR))

# $(call patch-files-DEFAULT, lists)
define patch-files-DEFAULT
$(foreach x,$1,								\
  $(if $(call get-file-group,$x),					\
    $x,$x:DEFAULT))
endef

distfiles		= $(call patch-files-DEFAULT,$(DISTFILES))
patchfiles		= $(call patch-files-DEFAULT,$(PATCHFILES))

#
# NOTE:
# "all" "ALL" and "default" are not allow to be used as group name, check it!
#

# $(call get-all-site-groups, lists)
define get-all-site-groups
$(sort									\
  $(call remove-common,							\
    $(foreach x,$1,							\
      $(call get-site-group,$x))))
endef

$(if									\
  $(filter all ALL default,						\
    $(call get-all-site-groups,$(master_sites))),			\
      $(error The words all, ALL and default are reserved and cannot be used in group definition. Please fix your MASTER_SITES))

$(if									\
  $(filter all ALL default,						\
    $(call get-all-site-groups,$(patch_sites))),			\
      $(error The words all, ALL and default are reserved and cannot be used in group definition. Please fix your PATCH_SITES))

# $(call find-groups-by-file, lists, file)
define find-groups-by-file
$(strip									\
  $(call remove-common,							\
    $(foreach x,$1,							\
      $(if								\
        $(filter $2,							\
          $(call get-file-name,$x)),					\
            $(call get-file-group,$x)))))
endef

# $(call find-groups-by-site, lists, site)
define find-groups-by-site
$(strip									\
  $(call remove-common,							\
    $(foreach x,$1,							\
      $(if								\
        $(filter $2,							\
          $(call get-site-name,$x)/),					\
            $(call get-site-group,$x)))))
endef

# $(call filter-x-by-group, lists, group, tailer)
define filter-x-by-group
$(foreach x,$1,								\
  $(if									\
    $(filter $2,							\
      $(call remove-common,						\
        $(call get-site-group,$x))),					\
          $(call get-site-name,$x)$3))
endef

# $(call filter-sites-by-group, lists, group)
filter-sites-by-group	= $(strip $(call filter-x-by-group,$1,$2,$(SLASH)))

# $(call filter-subdirs-by-group, lists, group)
filter-subdirs-by-group	= $(strip $(call filter-x-by-group,$1,$2))

# $(call transform-subdirs, pattern, group, subdir)
define transform-subdirs
$(if									\
  $(filter $1,$(subst $(SUBDIR),,$1)),					\
      $1,								\
      $(foreach x,							\
        $(call filter-subdirs-by-group,$3,$2),				\
          $(subst $(SUBDIR),$x,$1)))
endef

# $(call generate-sites-by-group, group, sites, subdir)
define generate-sites-by-group
$(strip									\
$(__master_site_override)						\
  $(sort								\
    $(foreach s,							\
      $(call filter-sites-by-group,$2,$1),				\
        $(foreach g,							\
          $(call find-groups-by-site,$2,$s),				\
            $(call transform-subdirs,$s,$g,$3))))			\
$(__master_site_backup))
endef

# $(call generate-master-sites-by-group, group)
generate-master-sites-by-group =					\
	$(call generate-sites-by-group,$1,$(master_sites),$(master_site_subdir))

# $(call generate-patch-sites-by-group, group)
generate-patch-sites-by-group =						\
	$(call generate-sites-by-group,$1,$(patch_sites),$(patch_site_subdir))

# $(call export-variable, group, sites, subdir)
define export-variable
$(eval export $1_$2 = $(call generate-sites-by-group,$2,$3,$4))
endef

# generate "__group_$f" and __patch_$f shell env for late rule use
$(if $(master_sites),							\
  $(foreach g,								\
    $(call get-all-site-groups,$(master_sites)),			\
      $(call export-variable,__group,$g,$(master_sites),$(master_site_subdir))), \
        $(call export-variable,__group,DEFAULT,$(master_sites),$(master_site_subdir)))

$(if $(patch_sites),							\
  $(foreach g,								\
    $(call get-all-site-groups,$(patch_sites)),				\
      $(call export-variable,__patch,$g,$(patch_sites),$(patch_site_subdir))), \
        $(call export-variable,__patch,DEFAULT,$(patch_sites),$(patch_site_subdir)))

FETCH_CMD		?= $(shell $(WHICH) wget 2>/dev/null)
$(if $(FETCH_CMD),,							\
  $(error Ports need \"wget\" utility to get distfiles))

# TODO: get the wget arguments to show progress without any verbose...
       fetch_opts	=
 quiet_fetch_opts	= -q --progress=bar:force
silent_fetch_opts	= -q

FETCH_REGET		?= 1
FETCH_CMD		+=						\
	-nd -N --connect-timeout=3 --tries=$(FETCH_REGET) $($(quiet)fetch_opts)

# stuff for extract ...

ifeq ($(USE_ZIP),yes)
EXTRACT_CMD		?= unzip
EXTRACT_BEFORE_ARGS	?= -g
EXTRACT_AFTER_ARGS	?= -d $(WRKDIR)
else
EXTRACT_BEFORE_ARGS	?= -dc
EXTRACT_AFTER_ARGS	?= | $(TAR) -xf -
ifeq ($(USE_XZ),yes)
EXTRACT_CMD		?= $(XZ_CMD)
else
ifeq ($(USE_BZIP2),yes)
EXTRACT_CMD		?= $(BZIP2_CMD)
else
EXTRACT_CMD		?= $(GZIP_CMD)
endif
endif
endif

# This is what is actually going to be extracted, and is overridable
#  by user.
EXTRACT_ONLY		?= $(_DISTFILES)
EXTRACT_LISTS		+= $(EXTRACT_ONLY)

# stuff for patch ...

DISTORIG		?= .bak.orig
PATCH			?= /usr/bin/patch
PATCH_STRIP		?= -p0
PATCH_DIST_STRIP	?= -p0
ifeq ($(PATCH_DEBUG),yes)
PATCH_DEBUG_TMP		= yes
PATCH_ARGS		?= -d $(PATCH_WRKSRC) -E $(PATCH_STRIP)
PATCH_DIST_ARGS		?=					\
	-b $(DISTORIG) -d $(PATCH_WRKSRC) -E $(PATCH_DIST_STRIP)
else
PATCH_DEBUG_TMP		= no
PATCH_ARGS		?=					\
	-d $(PATCH_WRKSRC) --forward --quiet -E $(PATCH_STRIP)
PATCH_DIST_ARGS		?=					\
	-d $(PATCH_WRKSRC) --forward --quiet -E $(PATCH_DIST_STRIP)
endif
ifeq ($(BATCH),yes)
PATCH_ARGS		+= --batch
PATCH_DIST_ARGS		+= --batch
endif

ifeq ($(PATCH_CHECK_ONLY),yes)
PATCH_ARGS		+= -C
PATCH_DIST_ARGS		+= -C
endif

#ifeq ($(PATCH),/usr/bin/patch)
#PATCH_ARGS		+= -b .orig
#PATCH_DIST_ARGS	+= -b .orig
#endif

# NOTE:
#
#   The most pain we use FreeBSD Ports is the patch file management,
#   to make life more easier, we introduce new patch method to manage
#   all patches.
#
#   Patch method can be selected by add following new make varable
#
#   USE_PATCH = [V1|V2]
#
#   Two supported patch methods are:
#
#   V1: traditional patch method (by 'patch') just as FreeBSD Ports did
#   V2: new patch method that use 'git' tool to manage all patches (default)
#
#   To use new patch method, just put all patches which produced by
#   "git format-patch" command into $(PATCHDIR) and add one additional "series"
#   file to specify the patch sequence.
#
#   Please be noted that user must declare USE_PATCH=V1 explicitly if they
#   want to use traditional patch method

GIT_ADD_EXTRA_LISTS	+= .gitignore
GIT_AM_OPTS		+= --ignore-whitespace
PATCHLIST		?= $(call config.lookup,$(PATCHLIST_NAME))

USE_PATCH		?= V2
PATCH_METHOD		= $(USE_PATCH)

# stuff for configure ...

CONFIGURE_SHELL		?= $(SH)
CONFIGURE_ENV		+= SHELL=$(SH) CONFIG_SHELL=$(SH)
CONFIGURE_SCRIPT	?= configure
CONFIGURE_LOG		?= configure.log

# NOTE:
#   Ports may use under following special situation:
#   1. Ports will be used for embedded system develop if CROSS_COMPILE defined
#   2. If CONFIGURE_TARGET defined, ports will be used for toolchain build

triplet			:=
ifneq ($(CROSS_COMPILE),)
CONFIGURE_BUILD		?= $(shell $(PORTSDIR)/Tools/config.guess)
CONFIGURE_HOST		?= $(CROSS_COMPILE)
ifneq ($(DONT_USE_HOST_TRIPLET),yes)
triplet			+= --build=$(CONFIGURE_BUILD) --host=$(CONFIGURE_HOST)
endif
TOOLS_PREFIX		:= $(CROSS_COMPILE)-
ifneq ($(CONFIGURE_BUILD),$(CONFIGURE_HOST))
CC			= $(TOOLS_PREFIX)gcc
C++			= $(TOOLS_PREFIX)g++
CXX			= $(TOOLS_PREFIX)g++
LD			= $(TOOLS_PREFIX)ld
AS			= $(TOOLS_PREFIX)as
AR			= $(TOOLS_PREFIX)ar
NM			= $(TOOLS_PREFIX)nm
OBJDUMP			= $(TOOLS_PREFIX)objdump
RANLIB			= $(TOOLS_PREFIX)ranlib
STRIP			= $(TOOLS_PREFIX)strip
endif
endif
ifneq ($(CONFIGURE_TARGET),)
ifneq ($(CROSS_COMPILE),)
$(error Oops, CROSS_COMPILE __WAS NOT__ necessary if CONFIGURE_TARGET defined)
endif
triplet			+= --target=$(CONFIGURE_TARGET)
endif

# $(warning triplet=$(triplet))

ifeq ($(GNU_CONFIGURE),yes)
GUN_CONFIGURE_PREFIX	?= $(PREFIX)
CONFIGURE_ARGS		+=						\
	--prefix=$(GUN_CONFIGURE_PREFIX) $$_late_configure_args
CONFIGURE_ENV		+=
HAS_CONFIGURE		= yes

# FIXME...
ifneq ($(CC),)
CONFIGURE_ENV		+= CC="$(CC)"
endif
ifneq ($(CPP),)
CONFIGURE_ENV		+= CPP="$(CPP)"
endif
ifneq ($(CXX),)
CONFIGURE_ENV		+= CXX="$(CXX)"
endif
ifneq ($(LD),)
CONFIGURE_ENV		+= LD="$(LD)"
endif
ifneq ($(AR),)
CONFIGURE_ENV		+= AR="$(AR)"
endif
ifneq ($(AS),)
CONFIGURE_ENV		+= AS="$(AS)"
endif
ifneq ($(NM),)
CONFIGURE_ENV		+= NM="$(NM)"
endif
ifneq ($(OBJDUMP),)
CONFIGURE_ENV		+= OBJDUMP="$(OBJDUMP)"
endif
ifneq ($(RANLIB),)
CONFIGURE_ENV		+= RANLIB="$(RANLIB)"
endif
ifneq ($(STRIP),)
CONFIGURE_ENV		+= STRIP="$(STRIP)"
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

# FIXME: want to use "--build=$(CONFIGURE_TARGET)" in script
SET_LATE_CONFIGURE_ARGS	=						\
	_late_configure_args="";					\
	if [ -z "`./$(CONFIGURE_SCRIPT) --version 2>&1 | $(EGREP) -i '(autoconf.*\.13|unrecognized option)'`" ]; then \
	    _late_configure_args="$$_late_configure_args $(triplet)";	\
	else								\
	    _late_configure_args="$$_late_configure_args $(triplet)";	\
	fi;
endif

# Passed to most of script invocations
SCRIPTS_ENV		+=						\
	CURDIR=$(MASTERDIR) DISTDIR=$(DISTDIR)				\
	WRKDIR=$(WRKDIR) WRKSRC=$(WRKSRC) PATCHDIR=$(PATCHDIR)		\
	SCRIPTDIR=$(SCRIPTDIR) FILESDIR=$(FILESDIR)			\
	PORTSDIR=$(PORTSDIR) PREFIX=$(PREFIX) LOCALBASE=$(LOCALBASE)

# stuff for build ...

ALL_TARGET		?= all
INSTALL_TARGET		?= install

MAKE_SHELL		?= $(SH)
MAKE_ENV		+= SHELL=$(SH) NO_LINT=YES

MAKE_FLAGS		?= -f
MAKEFILE		?= Makefile
MAKE_ENV		+= 						\
	PREFIX=$(PREFIX) LOCALBASE=$(LOCALBASE) LIBDIR="$(LIBDIR)"	\
	CC="$(CC)" CFLAGS="$(CFLAGS)"					\
	CPP="$(CPP)" CPPFLAGS="$(CPPFLAGS)"				\
	CXX="$(CXX)" CXXFLAGS="$(CXXFLAGS)"				\
	LDFLAGS="$(LDFLAGS)"

# stuff for install/deinstall/uninstall ...

COMMENTFILE		?= $(PKGDIR)/pkg-comment
DESCR			?= $(PKGDIR)/pkg-descr
PKGINSTALL		?= $(PKGDIR)/pkg-install
PKGDEINSTALL		?= $(PKGDIR)/pkg-deinstall
PKGREQ			?= $(PKGDIR)/pkg-req
PKGMESSAGE		?= $(PKGDIR)/pkg-message
PLIST			?= $(call config.lookup,$(PLIST_NAME))

# $(warning PLIST=$(PLIST))

TMPPLIST		?= $(WRKDIR)/.PLIST.mktmp

# stuff for package ...

#
#
#

# Documentation
MAINTAINER		?= yowching.lee@gmail.com

ifeq ($(filter $(override_targets),maintainer),)
maintainer:
	@$(kecho) $(MAINTAINER)
endif

ifeq ($(origin CATEGORIES), undefined)
check-categories:
	@$(kecho) " ERR     $(PKGNAME): CATEGORIES is mandatory."
	@false
else
VALID_CATEGORIES	+=						\
	archivers converters devel graphics lang net net-mgmt bsp	\
	print security textproc www x11 x11-fonts x11-toolkits linux

check-categories:
	@for cat in $(CATEGORIES); do					\
	    if echo $(VALID_CATEGORIES) | $(GREP) -wq $$cat; then	\
	        true;							\
	    else							\
	        $(kecho) "  ERR     $(PKGNAME): category $$cat not in list of valid categories."; \
	        false;							\
	    fi;								\
	done
endif

################################################################
# The following are used to create easy dummy target for
# disabling some bit of default target behavior you don't want.
# They still check to see if the target exists, and if so don't
# do anything, since you might want to set this globally for a
# group of ports in a Makefile.inc, but still be able to
# override from an individual Makefile
################################################################



################################################################
# More standard target start here
#
# These are the body of the build/install framework.  If you are
# not happy with the default actions, and you can't solve it by
# adding pre-* or post-* target/scripts, override these.
################################################################

#
# PKG...
#

check-license:

ifeq ($(filter $(override_targets),pre-everything),)
pre-everything::
	@$(DO_NADA)
endif

#
# Fetch...
#

ifeq ($(USE_GLOBALBASE),yes)
$(if $(DISTDIR_SITE),,							\
  $(error You did not set "DISTDIR_SITE" but already set "USE_GLOBALBASE" to yes))

quiet_cmd_set-global-link	?=
      cmd_set-global-link	?= set -e;				\
	if [ ! -z $(DISTDIR_SITE) ]; then				\
	    if [ ! -d $(DISTDIR_SITE) ] && [ ! -h $(DISTDIR_SITE) ]; then \
	        mkdir -p $(DISTDIR_SITE);				\
	    fi;								\
	    if [ ! -d $(DISTDIR) ] && [ ! -h $(DISTDIR) ]; then		\
	        ln -s $(DISTDIR_SITE) $(DISTDIR);			\
	    fi;								\
	fi;
endif

quiet_cmd_fetch-sanity-check	?=
      cmd_fetch-sanity-check	?= set -e;				\
	if [ ! -d $(_DISTDIR) ] && [ ! -h $(_DISTDIR) ]; then		\
	    mkdir -p $(_DISTDIR);					\
	fi

.PHONY: do-fetch-sanity-check
do-fetch-sanity-check:
ifeq ($(USE_GLOBALBASE),yes)
	@$(call cmd,set-global-link)
endif
	@$(call cmd,fetch-sanity-check)

fetch_msg1 = "  ERR     $(DISTDIR) is not writable by you; cannot fetch."
fetch_msg2 = "  ERR     Couldn't fetch it - please try to retrieve this port manually into $(_DISTDIR) and try again"

ifeq ($(filter $(override_targets),do-fetch),)
do-fetch: do-fetch-sanity-check
	@(cd $(_DISTDIR);						\
	for f in $(distfiles); do					\
	    file=`echo $$f | sed -e 's/:[^:].*$$//'`;			\
	    groups=`echo $$f | sed -e 's/^[^:].*://' -e 's/,/ /g'`;	\
	    force_fetch=false;						\
	    filebasename=`basename $$file`;				\
	    for afile in $(FORCE_FETCH); do				\
	        afile=`basename $$afile`;				\
	        if [ x$$afile = x$$filebasename ]; then			\
	            force_fetch=true;					\
	        fi;							\
	    done;							\
	    $(kecho) "  CHK     $$file";				\
	    if [ ! -f $$file ] && [ ! -f $$filebasename ] || [ $$force_fetch = true ]; then \
	        if [ ! -w $(DISTDIR) ]; then				\
	            $(kecho) $(fetch_msg1);				\
	            exit 1;						\
	        fi;							\
	        __master_sites_tmp= ;					\
	        for g in $$groups; do					\
	            eval __TMP=\$${__group_$${g}};			\
	            __master_sites_tmp="$${__master_sites_tmp} $${__TMP}"; \
	        done;							\
	        __TMP= ;						\
	        for s in $$__master_sites_tmp; do			\
	            $(kecho) "  WGET    $$file from $$s";		\
	            case $$file in					\
	            */*) $(MKDIR) $${file%/*};				\
	                args=--directory-prefix=$${file%/*} $$s$$file;;	\
	            *)  args=$$s$$file;;				\
	            esac;						\
	            if $(SETENV) $(FETCH_ENV) $(FETCH_CMD) $(FETCH_BEFORE_ARGS) $$args $(FETCH_AFTER_ARGS); then \
	               continue 2;					\
	            fi;							\
	        done;							\
	        $(kecho) $(fetch_msg2);					\
	        exit 1; \
	    fi; \
	done)
ifneq ($(PATCHFILES),)
	@(cd $(_DISTDIR);						\
	for f in $(patchfiles); do					\
	    file=`echo $$f | sed -e 's/:[^:].*$$//'`;			\
	    groups=`echo $$f | sed -e 's/^[^:].*://' -e 's/,/ /g'`;	\
	    force_fetch=false;						\
	    filebasename=`basename $$file`;				\
	    for afile in $(FORCE_FETCH); do				\
	        afile=`basename $$afile`;				\
	        if [ x$$afile = x$$filebasename ]; then			\
	            force_fetch=true;					\
	        fi;							\
	    done;							\
	    $(kecho) "  CHK     $$file";				\
	    if [ ! -f $$file ] && [ ! -f $$filebasename ] || [ $$force_fetch = true ]; then \
	        if [ ! -w $(DISTDIR) ]; then				\
	            $(kecho) $(fetch_msg1);				\
	            exit 1;						\
	        fi;							\
	        __patch_sites_tmp= ;					\
	        for g in $$groups; do					\
	            eval __TMP=\$${__patch_$${g}};			\
	            __patch_sites_tmp="$${__patch_sites_tmp} $${__TMP}"; \
	        done;							\
	        __TMP= ;						\
	        for s in $$__patch_sites_tmp; do			\
	            $(kecho) "  WGET    $$file from $$s";		\
	            case $$file in					\
	            */*) $(MKDIR) $${file%/*};				\
	                args=--directory-prefix=$${file%/*} $$s$$file;;	\
	            *)  args=$$s$$file;;				\
	            esac;						\
	            if $(SETENV) $(FETCH_ENV) $(FETCH_CMD) $(FETCH_BEFORE_ARGS) $$args $(FETCH_AFTER_ARGS); then \
	               continue 2;					\
	            fi;							\
	        done;							\
	        $(kecho) $(fetch_msg2);					\
	        exit 1;							\
	    fi;								\
	done)
endif
endif

#
# Extract...
#

quiet_cmd_wrkdir	?=
      cmd_wrkdir	?= set -e; [ -d $(WRKDIR) ] || mkdir -p $(WRKDIR)

.PHONY: wrkdir
wrkdir:
	$(call cmd,wrkdir)

quiet_cmd_extract-only	?=
      cmd_extract-only	?= set -e;					\
	(cd $(WRKDIR) && if [ -f $(_DISTDIR)/$@ ]; then $(EXTRACT_CMD) $(EXTRACT_BEFORE_ARGS) $(_DISTDIR)/$@ $(EXTRACT_AFTER_ARGS); fi)

$(EXTRACT_ONLY): wrkdir
	$(call cmd,extract-only)

ifeq ($(filter $(override_targets),do-extract),)
do-extract: wrkdir $(EXTRACT_ONLY)
endif

#
# Patch...
#

ask-license:

patch_msg1=Applying distribution patches for $(PKGNAME)
patch_msg2=Applying $(OPSYS) patches for $(PKGNAME)

quiet_cmd_apply-dist-patch	?= PATCH   $(patch_msg1)
      cmd_apply-dist-patch	?= set -e;				\
	(cd $(_DISTDIR);						\
	for i in $(_PATCHFILES); do					\
	    case $$i in							\
	        *.Z|*.gz)						\
	            $(GZCAT) $$i | $(PATCH) $(PATCH_DIST_ARGS);		\
	            ;;							\
	        *.bz2)							\
	            $(BZCAT) $$i | $(PATCH) $(PATCH_DIST_ARGS);		\
	            ;;							\
	        *.zip)							\
	            $(ZCAT) $$i | $(PATCH) $(PATCH_DIST_ARGS);		\
	            ;;							\
	        *)							\
	            $(PATCH) $(PATCH_DIST_ARGS) < $$i;			\
	            ;;							\
	    esac;							\
	done)

quiet_cmd_apply-extra-patch	?=
      cmd_apply-extra-patch	?= set -e;				\
	for i in $(EXTRA_PATCHES); do					\
	    $(kecho) "  PATCH   applying extra patch $$i";		\
	    $(PATCH) $(PATCH_ARGS) < $$i;				\
	done

quiet_cmd_apply-patches	?=
      cmd_apply-patches	?= set -e;					\
	if [ -d $(PATCHDIR) ]; then					\
	    if [ "`echo $(PATCHDIR)/patch-*`" != "$(PATCHDIR)/patch-*" ]; then \
	        $(kecho) "  PATCH   $(patch_msg2)";			\
	        patches_applied="";					\
	        for i in $(PATCHDIR)/patch-*; do			\
	            case $$i in						\
	            *.orig|*.rej|*~|*,v)				\
	                $(kecho) "  WRN     Ignoring patchfile $$i" ;	\
	                ;;						\
	            *)							\
	                if $(PATCH) $(PATCH_ARGS) < $$i; then		\
	                    patches_applied="$(patches_applied) $$i";	\
	                else						\
	                    _pf=`echo $$i | $(SED) 's|$(PATCHDIR)/||'`; \
	                    $(kecho) "  ERR     Patch $$_pf failed to apply cleanly."; \
	                    if [ x"$$patches_applied" != x"" ]; then	\
	                        _pfs=`echo $$patches_applied | $(SED) 's|$(PATCHDIR)/||'`; \
	                        $(kecho) "  ERR     Patch(es) $$_pfs applied cleanly."; \
	                    fi;						\
	                    false;					\
	                fi;						\
	                ;;						\
	            esac;						\
	        done;							\
	    fi;								\
	fi

# NOTE:
#
#   don't set "set -e" in cmd_init-git-repo because "git add *" command
#   will return error if some files are listed in .gitignore

quiet_cmd_init-git-repo		?=
      cmd_init-git-repo		?= 					\
	(cd $(PATCH_WRKSRC);						\
	if [ ! -d .git ]; then						\
	    $(kecho) "  GIT     $(DISTNAME)(init)";			\
	    $(GIT) init $(trash);					\
	    $(GIT) add $(GIT_ADD_OPTS) * $(trash) 2>&1;			\
	    if [ ! -z "$(GIT_ADD_EXTRA_LISTS)" ]; then			\
	        for f in $(GIT_ADD_EXTRA_LIST); do			\
	            find . -type f -name \"$$f\" -exec git add -f '{}' \;; \
	        done;							\
	    fi;								\
	    $(GIT) commit -m "init" $(trash);				\
	fi)

git-init:
	$(call cmd,init-git-repo)

quiet_cmd_apply-git-patches	?=
      cmd_apply-git-patches	?= set -e;				\
	(cd $(PATCH_WRKSRC);						\
	if [ -f "$(PATCHLIST)" ]; then					\
	    $(kecho) "  GIT     $(DISTNAME)(am)";			\
	    for p in `cat $(PATCHLIST)`; do				\
	        $(GIT) am $(GIT_AM_OPTS) $(PATCHDIR)/$$p;		\
	    done;							\
	fi)

ifeq ($(filter $(override_targets),do-patch),)
ifeq ($(PATCH_METHOD),V1)
do-patch:
ifneq ($(PATCHFILES),)
	$(call cmd,apply-dist-patch)
endif
ifneq ($(EXTRA_PATCHES),)
	$(call cmd,apply-extra-patch)
endif
	$(call cmd,apply-patches)
else
do-patch: git-init
	$(call cmd,apply-git-patches)
endif
endif

#
# Configure...
#

run-autotools-fixup:
configure-autotools:
run-autotools:

configure_msg1=Script \"${CONFIGURE_SCRIPT}\" failed unexpectedly.

quiet_cmd_run-config	?=
      cmd_run-config	?= set -e;					\
	(cd $(CONFIGURE_WRKSRC) && $(SET_LATE_CONFIGURE_ARGS)		\
	if ! $(SETENV) CC="$(CC)" CPP="$(CPP)" CXX="$(CXX)"		\
	    CFLAGS="$(CFLAGS)" CPPFLAGS="$(CPPFLAGS)"			\
	    CXXFLAGS="$(CXXFLAGS)" LDFLAGS="$(LDFLAGS)"			\
	    $(CONFIGURE_ENV) ./$(CONFIGURE_SCRIPT) $(CONFIGURE_ARGS); then \
	    $(kecho) "  ERR     $(configure_msg1)";			\
	    false;							\
	fi)

ifeq ($(filter $(override_targets),do-configure),)
do-configure:
	@if [ -f $(SCRIPTDIR)/configure ]; then				\
	    cd $(MASTERDIR) && $(SETENV) $(SCRIPTS_ENV) $(SH) $(SCRIPTDIR)/configure; \
	fi
ifeq ($(GNU_CONFIGURE),yes)
# copy config.guess and config.sub form Templates...
endif
ifeq ($(HAS_CONFIGURE),yes)
	$(call cmd,run-config)
endif
endif

#
# Build...
#

build_msg1=Compilation failed unexpectedly.

quiet_cmd_run-make-build	?=
      cmd_run-make-build	?= set -e;				\
	(cd $(BUILD_WRKSRC);						\
	if ! $(SETENV) $(MAKE_ENV) $(MAKE) $(MAKE_FLAGS) $(MAKEFILE)	\
	    $(MAKE_ARGS) $(ALL_TARGET); then				\
	    $(kecho) "  ERR     $(build_msg1)";				\
	    false;							\
	fi)

ifeq ($(filter $(override_targets),do-build),)
do-build:
	$(call cmd,run-make-build)
endif

#- check-conflicts:

#
# Install...
#

install-license:

quiet_cmd_run-install	?=
      cmd_run-install	?= set -e;					\
	(cd $(INSTALL_WRKSRC) &&					\
	    $(SETENV) $(MAKE_ENV) $(MAKE) $(MAKE_FLAGS) $(MAKEFILE)	\
	    $(MAKE_ARGS) $(INSTALL_TARGET))

ifeq ($(filter $(override_targets),do-install),)
do-install:
	$(call cmd,run-install)
endif

#
# Package...
#

quiet_cmd_run-package	?=
      cmd_run-package	?= set -e;					\
	if [ -d $(PACKAGES) ]; then					\
	    [ -d $(PKGREPOSITORY) ] || mkdir -p $(PKGREPOSITORY);	\
	fi;								\
	os=`uname -s`;							\
	if [ "$$os" = "Darwin" ]; then					\
	    temp=`mktemp -d /tmp/tmp-$(PORTNAME).XXXXXX`;		\
	else								\
	    temp=`mktemp -d --suffix=$(PORTNAME)`;			\
	fi;								\
	$(PORTSDIR)/Tools/install-if-change				\
	    -b $(DESTDIR)$(PREFIX) -p $(PLIST) $$temp;			\
	(cd $$temp && tar Jcf $(PKGFILE) *);				\
	$(kecho) "  PACKAGE $(PKGNAME)";				\
	rm -fr $$temp

ifeq ($(filter $(override_targets),do-package),)
do-package:
	$(call cmd,run-package)
endif

#- package-links: delete-package-links
#- delete-package-links:
#- delete-package: delete-package-links
#- delete-package-link-list:
#- delete-package-list: delete-package-links-list

# Utility targets follow

#- install-mtree
check-already-installed:
install-ldconfig-file:
security-check:

################################################################
# Skeleton targets start here
#
# You shouldn't have to change these.  Either add the pre-* or
# post-* targets/scripts or redefine the do-* targets.  These
# targets don't do anything other than checking for cookies and
# call the necessary targets/scripts.
################################################################

# Please note that the order of the following targets is important, and
# should not be modified.

_SANITY_SEQ		= pre-everything				\
			  check-categories check-license

_PKG_DEP		= check-sanity
_PKG_SEQ		= pkg-depends

_FETCH_DEP		= pkg
_FETCH_SEQ		= fetch-depends					\
			  pre-fetch pre-fetch-script			\
			  do-fetch					\
			  post-fetch post-fetch-script

_EXTRACT_DEP		= fetch
_EXTRACT_SEQ		= extract-message				\
			  checksum					\
			  extract-depends				\
			  pre-extract pre-extract-script		\
			  do-extract					\
			  post-extract post-extract-script
_EXTRACT_LINK		= post-extract-script
_EXTRACT_NEXT		= ask-license

_PATCH_DEP		= extract
_PATCH_SEQ		= ask-license					\
			  patch-message					\
			  patch-depends					\
			  pre-patch pre-patch-script			\
			  do-patch					\
			  post-patch post-patch-script
_PATCH_LINK		= post-patch-script
_PATCH_NEXT		= build-depends

_CONFIGURE_DEP 		= patch
_CONFIGURE_SEQ		= build-depends lib-depends			\
			  configure-message				\
			  run-autotools-fixup configure-autotools	\
			  pre-configure pre-configure-script		\
			  run-autotools					\
			  do-configure					\
			  post-configure post-configure-script
_CONFIGURE_LINK		= post-configure-script
_CONFIGURE_NEXT		= build-message

_BUILD_DEP		= configure
_BUILD_SEQ		= build-message					\
			  pre-build pre-build-script			\
			  do-build					\
			  post-build post-build-script
_BUILD_LINK		= post-build-script
_BUILD_NEXT		= install-message

_INSTALL_DEP		= build
_INSTALL_SEQ		= install-message				\
			  run-depends lib-depends			\
			  pre-install pre-install-script		\
			  check-already-installed			\
			  do-install					\
			  install-license				\
			  post-install post-install-script		\
			  install-ldconfig-file				\
			  security-check
_INSTALL_LINK		= security-check
_INSTALL_NEXT		= package-message

_PACKAGE_DEP		= install
_PACKAGE_SEQ		= package-message				\
			  pre-package pre-package-script		\
			  do-package					\
			  post-package post-package-script
_PACKAGE_LINK		= post-package-script
_PACKAGE_NEXT		=

cookie_targets		:=						\
	extract patch configure build install package

embellish_targets	:=						\
	$(patsubst %,pre-%,fetch $(cookie_targets))			\
	$(patsubst %,post-%,fetch $(cookie_targets))

embellish_script_targets:=						\
	$(patsubst %,%-script,$(embellish_targets))

ifeq ($(filter $(override_targets),check-sanity),)
check-sanity: $(_SANITY_SEQ)
endif

ifeq ($(filter $(override_targets),pkg),)
pkg: $(_PKG_DEP) $(_PKG_SEQ)
endif

ifeq ($(filter $(override_targets),fetch),)
fetch: $(_FETCH_DEP) $(_FETCH_SEQ)
endif

# Main logick. The loop gererates 6 main targets and using cookies
# ensures that those already completed are skipped.

# $(call uppercase-target target)
define uppercase-target
$(strip									\
  $(if $(filter $1,extract),EXTRACT,					\
    $(if $(filter $1,patch),PATCH,					\
      $(if $(filter $1,configure),CONFIGURE,				\
        $(if $(filter $1,build),BUILD,					\
          $(if $(filter $1,install),INSTALL,				\
            $(if $(filter $1,package),PACKAGE)))))))
endef

# $(call generate-cookie-targets, target, uppercase_target)
define generate-cookie-targets
ifeq ($(filter $(override_targets),$1),)
$1: $($2_COOKIE)
endif
ifeq ($(wildcard $($2_COOKIE)),)
ifneq ($($(patsubst %,_%_NEXT,$2)),)
$($(patsubst %,_%_NEXT,$2)): $($(patsubst %,_%_LINK,$2))
endif
$($2_COOKIE): $($(patsubst %,_%_DEP,$2)) $($(patsubst %,_%_SEQ,$2))
	@touch $($2_COOKIE)
ifneq ($($2_LISTS),)
	@echo $($2_LISTS) >> $($2_COOKIE)
endif
else
$($2_COOKIE):
	@$(DO_NADA)
endif
endef

$(foreach t,$(cookie_targets),						\
  $(eval 								\
    $(call generate-cookie-targets,$t,$(call uppercase-target,$t))))


# Enforce order for -jN builds

check-categories : pre-everything
check-license : check-categories
pkg-depends: check-license
fetch-depends: pkg-depends
pre-fetch: fetch-depends
extract-message: post-fetch-script
checksum: extract-message
extract-depends: checksum
pre-extract: extract-depends
patch-message: ask-license
patch-depends: patch-message
pre-patch: patch-depends
lib-depends: build-depends
configure-message: lib-depends
run-autotools-fixup: configure-message
configure-autotools: run-autotools-fixup
pre-configure: configure-autotools
run-autotools: pre-configure-script
do-configure: run-autotools
pre-build: build-message
run-depends: install-message
pre-install: run-depends
check-already-installed: pre-install-script
do-install: check-already-installed
install-license: do-install
post-install: install-license
install-ldconfig-file: post-install-script
security-check: install-ldconfig-file
pre-package: package-message

# $(call generate-cookie-targets-depends, target)
define generate-cookie-targets-depends
pre-$1-script: pre-$1
do-$1: pre-$1-script
post-$1: do-$1
post-$1-script: post-$1
endef

$(foreach t, fetch $(cookie_targets),					\
  $(eval 								\
    $(call generate-cookie-targets-depends,$t)))


extract-message:
	@$(kecho) "  EXTRACT $(PKGNAME)"
patch-message:
	@$(kecho) "  PATCH   $(PKGNAME)"
configure-message:
	@$(kecho) "  CONFIGURE $(PKGNAME)"
build-message:
	@$(kecho) "  BUILD   $(PKGNAME)"
install-message:
	@$(kecho) "  INSTALL $(PKGNAME)"
package-message:
	@$(kecho) "  PACKAGE $(PKGNAME)"

# Empty pre-* and post-* targets

# $(call generate-embellish-targets target)
define generate-embellish-targets
ifeq ($(filter $(override_targets),$1),)
$1:
	@$(DO_NADA)
endif
endef

$(foreach t,$(embellish_targets),					\
  $(eval								\
    $(call generate-embellish-targets,$t)))

# $(call generate-embellish-script-targets target)
define generate-embellish-script-targets
ifeq ($(filter $(override_targets),$1),)
$1:
	@if [ -f $(SCRIPTDIR)/$2 ]; then				\
	    cd $(SCRIPTDIR) && $(SETENV) $(SCRIPTS_ENV) $(SH) $(SCRIPTDIR)/$2; \
	fi
endif
endef

$(foreach t,$(embellish_script_targets),				\
  $(eval								\
    $(call generate-embellish-script-targets,$t,$(patsubst %-script,%,$t))))

################################################################
# Some more target supplied for users' convenience
################################################################

#- checkpatch:

# reinstall:

ifeq ($(filter $(override_targets),reinstall),)
reinstall:
	@rm -f $(INSTALL_COOKIE) $(PACKAGE_COOKIE)
	@cd $(CURDIR) && make install
endif

# deinstall/uninstall

ifeq ($(filter $(override_targets),pre-deinstall),)
pre-deinstall:
	@$(DO_NADA)
endif

ifeq ($(filter $(override_targets),deinstall uninstall),)
deinstall uninstall: pre-deinstall
	@if [ -f $(PLIST) ]; then					\
	    $(kecho) "  UNINSTALL $(PKGNAME)";				\
	    for f in `cat $(PLIST)`; do					\
	        case $$f in						\
		.*)							\
		    prefix=$(DESTDIR)$(PREFIX);				\
		    realname=$$f;;					\
	        @rmdir*)						\
	            ;;							\
		esac;							\
	        if [ -f $$prefix/$$realname ]; then			\
	            rm -fr $$prefix/$$realname;				\
		elif [ -h $$prefix/$$realname ]; then			\
	            rm -fr $$prefix/$$realname;				\
		elif [ -c $$prefix/$$realname ]; then			\
	            rm -fr $$prefix/$$realname;				\
	        fi;							\
	    done;							\
	fi
	@rm -f $(INSTALL_COOKIE) $(PACKAGE_COOKIE)
#	@cd $(MASTERDIR) && $(MAKE) $(__softMAKEFLAGS) run-ldconfig
endif

# clean

ifeq ($(filter $(override_targets),do-clean),)
do-clean:
	@$(kecho) "  CLEAN     $(PKGNAME)";				\
	if [ -d $(WRKSRC) ]; then					\
	    (cd $(WRKSRC) && make clean);				\
	    rm -fr $(BUILD_COOKIE);					\
	    rm -fr $(INSTALL_COOKIE);					\
	fi
endif

ifeq ($(filter $(override_targets),clean),)
clean:
	@cd $(MASTERDIR) && $(MAKE) --no-print-directory $(__softMAKEFLAGS) do-clean
endif

# distclean

ifeq ($(filter $(override_targets),pre-distclean),)
pre-distclean:
	@$(DO_NADA)
endif

ifeq ($(filter $(override_target),do-distclean),)
do-distclean:
	@$(kecho) "  DISTCLEAN $(PKGNAME)";				\
	if [ -d $(WRKDIR) ]; then					\
		if [ -w $(WRKDIR) ]; then				\
			rm -fr $(WRKDIR);				\
		else							\
			$(kecho) "  ERR     $(WRKDIR) not writable, skipping"; \
		fi;							\
	fi
endif

ifeq ($(filter $(override_targets),distclean),)
distclean: pre-distclean
ifneq ($(NOCLEANDEPENDS),yes)
	@cd $(MASTERDIR) && $(MAKE) --no-print-directory $(__softMAKEFLAGS) distclean-depends
endif
	@cd $(MASTERDIR) && $(MAKE) --no-print-directory $(__softMAKEFLAGS) do-distclean
endif

#--- really-distclean:
#- delete-distfiles:
#- delete-distfiles-list:
#- fetch-list:
#- update-patches:
#- makesum:

checksum:

################################################################
# The special package-building targets:
# You probably won't need to touch these
################################################################

#- package-name:
#- repackage:
#- pre-repackage:
#- package-noinstall:

################################################################
# Dependency checking
################################################################

pkg-depends:
extract-depends:
patch-depends:
fetch-depends:
build-depends:
run-depends:
lib-depends:
# -misc-depends:

# Dependency lists: both build and runtime, recursive.
# Print out directory names.
#- all-depends-list:

ifeq ($(filter $(override_depends),clean-depends),)
clean-depends:
	@$(DO_NADA)
endif

ifeq ($(filter $(override_depends),distclean-depends),)
distclean-depends:
	@$(DO_NADA)
endif


#- fetch-recursive:
#- fetch-recursive-list: fetch
#- fetch-required-list: fetch-list
#- checksum-recursive:

# Dependency lists: build and runtime.  Print out directory names.

#- build-depends-list:
#- run-depends-list:

# Package (recursive runtime) dependency list.  Print out both directory names
# and package names.

#- package-depends-list:
#- package-depends:

################################################################
# Everything after here are internal targets and really
# shouldn't be touched by anybody but the release engineers.
################################################################

#- describe:
#- www-site:
#- readmes:
#- readme:
#- $(CURDIR)/README.html:
#- pretty-print-depends-list:
#- pretty-print-run-depends-list:

quiet_cmd_generate-plist?= GEN     $(TMPPLIST)
      cmd_generate-plist?= set -e;					\
	if [ -f $(BUILD_COOKIE) ]; then					\
	    tmpdir=/tmp/$(PKGNAME);					\
	    if [ -d $$tmpdir ]; then rm -fr $$tmpdir; fi; 		\
	    cd $(CURDIR) &&						\
                $(MAKE) DESTDIR=$$tmpdir PREFIX=$(PREFIX) post-install >/dev/null; \
	    cd $$tmpdir$(PREFIX) &&					\
                find . | sort -r | $(SED) -e '/^\.$$/d' > $(TMPPLIST);	\
	fi

generate-plist:
	$(call cmd,generate-plist)

$(TMPPLIST): generate-plist

#- compress-man:
#- fake-pkg:
#- depend:
#- tags:
