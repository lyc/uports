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

SCRIPTS_ENV		+=

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

quiet_cmd_fetch-sanity-check	?=
      cmd_fetch-sanity-check	?= set -e;				\
	if [ ! -d $(_DISTDIR) ] && [ ! -h $(_DISTDIR) ]; then		\
	    mkdir -p $(_DISTDIR);					\
	fi

.PHONY: do-fetch-sanity-check
do-fetch-sanity-check:
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

ifeq ($(filter $(override_targets),do-patch),)
do-patch:
ifneq ($(PATCHFILES),)
	$(call cmd,apply-dist-patch)
endif
ifneq ($(EXTRA_PATCHES),)
	$(call cmd,apply-extra-patch)
endif
	$(call cmd,apply-patches)
endif

#
# Configure...
#

run-autotools-fixup:
configure-autotools:
run-autotools:

ifeq ($(filter $(override_targets),do-configure),)
do-configure:
endif

#
# Build...
#

ifeq ($(filter $(override_targets),do-build),)
do-build:
endif

#- check-conflicts:

#
# Install...
#

install-license:

ifeq ($(filter $(override_targets),do-install),)
do-install:
endif

#
# Package...
#

ifeq ($(filter $(override_targets),do-package),)
do-package:
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
#- reinstall:
#- uninstall:


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
#- generate-plist:
#- $(TMPPLIST):
#- compress-man:
#- fake-pkg:
#- depend:
#- tags:
