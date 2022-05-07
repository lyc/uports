#
# linux.port.mk
#

# $(call subdirectory,makefile)
subdirectory		= $(patsubst %/$1,%,				\
			    $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
PORTSDIR		:= $(abspath $(call subdirectory,linux.port.mk)/..)

include $(PORTSDIR)/Mk/linux.debug.mk

LOCALBASE		?= /usr/local
DISTDIR			?= $(PORTSDIR)/distfiles
_DISTDIR		?= $(patsubst %/,%,$(DISTDIR)/$(DIST_SUBDIR))
SCRIPTSDIR		?= ${PORTSDIR}/Mk/Scripts
STAGEDIR		?= $(WRKDIR)/stage

include $(PORTSDIR)/Mk/linux.commands.mk

SLASH			:= /
COMMON			:= ,

#
# DESTDIR section to start a chrooted process if invoked with DESTDIR set
# +---------------------------------------------------------------------+
# |.if defined(DESTDIR) && !empty(DESTDIR) && !defined(CHROOTED) && \   |
# |	!defined(BEFOREPORTMK) && !defined(INOPTIONSMK)                 |
# +---------------------------------------------------------------------+
check-if-destdir	:= $(strip					\
			     $(if $(INOPTIONSMK),,			\
			       $(if $(BEFOREPORTMK),,yes)))
#ifneq ($(DESTDIR),)
#  ifeq ($(CHROOTED),)
#    ifeq ($(call check-if-destdir),yes)
#
# (NOTE: use our own way now.)
##include "$(PORTSDIR)/Mk/bsd.destdir.mk"
#
#    endif
#  endif
#
#else

# Start of options section
# +---------------------------------------------------------------------+
# |.  if defined(INOPTIONSMK) || \					|
# |       ( !defined(USEOPTIONSMK) && !defined(AFTERPORTMK) )           |
# +---------------------------------------------------------------------+
check-if-options	:= $(strip					\
			     $(if $(INOPTIONSMK),,			\
			       $(if $(USEOPTIONSMK),,			\
			         $(if $(AFTERPORTMK),,yes))))
  ifneq ($(findstring $(sort $(INOPTIONSMK) $(call check-if-options)),yes),)

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

# Get the operating system revision
__OSREL_ARG		= -e 's/[-(].*//'
ifeq ($(OSREL),)
OSREL			?= $(shell $(UNAME) -r | $(SED) $(__OSREL_ARG))
endif

MASTERDIR		?= $(CURDIR)

# (NOTE: no plan to support "options" yet)
#include $(PORTSDIR)/Mk/linux.options.mk

  endif
# End of options section.

# Start of pre-makefile section.
# +---------------------------------------------------------------------+
# |.  if !defined(AFTERPORTMK) && !defined(INOPTIONSMK)                 |
# +---------------------------------------------------------------------+
check-if-pre-makefile	:= $(strip					\
			     $(if $(sort $(BEFOREPORTMK) $(AFTERPORTMK)),\
			       $(if $(BEFOREPORTMK),			\
			         $(if $(AFTERPORTMK),,yes),)		\
			      ,yes))
  ifeq ($(INOPTIONSMK),)
    ifeq ($(call check-if-pre-makefile),yes)

      $(if $(_PREMKINCLUDED),						\
        $(error ERR, you cannot include linux.port[.pre].mk twice),)
_PREMKINCLUDED		= yes

# TODO: check $(PORTVERSON) at here ...
DISTVERSION		?= $(PORTVERSION)

PORTREVISION		?= 0
ifneq ($(PORTREVISION),0)
_SUF1			= _$(PORTREVISION)
endif

PORTEPOCH		?= 0
ifneq ($(PORTEPOCH),0)
_SUF2			= ,$(PORTEPOCH)
endif

PKGVERSION		?= $(PORTVERSION)$(_SUF1)$(_SUF2)
PKGNAME			?=						\
	$(PKGNAMEPREFIX)$(PORTNAME)$(PKGNAMESUFFIX)-$(PKGVERSION)
DISTNAME		?=						\
	$(PORTNAME)-$(DISTVERSIONPREFIX)$(DISTVERSION)$(DISTVERSIONSUFFIX)

INDEXFILE		?= INDEX

PACKAGES		?= $(PORTSDIR)/packages
TEMPLATES		?= $(PORTSDIR)/Templates

PATCHDIR		?= $(MASTERDIR)/files
FILESDIR		?= $(MASTERDIR)/files
SCRIPTDIR		?= $(MASTERDIR)/scripts
PKGDIR			?= $(MASTERDIR)

PREFIX			?= $(LOCALBASE)

# $(call set-global-link, dir_site, dir)
define set-global-link
  $(shell if [ ! -z $1 ]; then						\
	    if [ ! -d $1 ] && [ ! -h $1 ]; then mkdir -p $1; fi;	\
	    if [ ! -d $2 ] && [ ! -h $2 ]; then ln -s $1 $2; fi;	\
	  fi)
endef

# generate all glboal links ...
ifeq ($(USE_GLOBALBASE),yes)
distfiles_NAME		:= DISTDIR
packages_NAME		:= PACKAGES
ifneq ($(DISTDIR_SITE),)
global_link_all		+= distfiles
endif
ifneq ($(PACKAGES_SITE),)
global_link_all		+= packages
endif

$(foreach d, $(global_link_all),					\
  $(eval								\
    $(if $($($d_NAME)_SITE),						\
      $(if $(wildcard $(portdir)/$d),,					\
        $(call set-global-link,$($($d_NAME)_SITE),$($($d_NAME)))),	\
      $(error You are trying to use "USE_GLOBALBASE" but didn't set $($d_NAME)_SITE properly))))
endif #'

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

# generate all config files ...
PATCHLIST_NAME		?= series
PLIST_NAME		?= pkg-plist

config_$(PATCHLIST_NAME)= $(PATCHDIR)
config_$(PLIST_NAME)	= $(PKGDIR)
config_all		= $(PATCHLIST_NAME) $(PLIST_NAME)
$(foreach t,$(config_all),$(eval $(call generate-config-all,$t)))

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

    endif
  endif
# End of pre-makefile section.

# Start of post-makefile section.
# +---------------------------------------------------------------------+
# |.  if !defined(BEFOREPORTMK) && !defined(INOPTIONSMK)                |
# +---------------------------------------------------------------------+
check-if-post-makefile	:= $(strip					\
			     $(if $(sort $(BEFOREPORTMK) $(AFTERPORTMK)),\
			       $(if $(AFTERPORTMK),			\
			         $(if $(BEFOREPORTMK),,yes),)		\
			      ,yes))
  ifeq ($(INOPTIONSMK),)
    ifeq ($(call check-if-post-makefile),yes)

      $(if $(_POSTMKINCLUDED),						\
        $(error ERR, you cannot include linux.port[.post].mk twice),)
_POSTMKINCLUDED		= yes

WRKDIR			?= $(WRKDIRPREFIX)$(MASTERDIR)/work$(TYPE_SUFFIX)

ifneq ($(NO_WRKSUBDIR),yes)
WRKSRC			?= $(WRKDIR)/$(DISTNAME)
else
WRKSRC			?= $(WRKDIR)
endif

ifeq ($(USE_STICKY),yes)
override USE_ALTERNATIVE:= yes
endif

source			:= $(word $(words $(subst /, ,$(WRKSRC))),$(subst /, ,$(WRKSRC)))
ifeq ($(WRKDIR)/$(source),$(WRKSRC))
ALTERNATIVE_WRKSRC	= $(ALTERNATIVE_WRKDIR)/$(source)
else
ALTERNATIVE_PREFIX	= $(patsubst $(WRKDIR)/%/$(source),%,$(WRKSRC))
ALTERNATIVE_WRKSRC	= $(ALTERNATIVE_WRKDIR)/$(ALTERNATIVE_PREFIX)/$(source)
endif

ifeq ($(FORCE_ALTERNATIVE),yes)
USE_STICKY		:=
endif

PATCH_WRKSRC		?= $(WRKSRC)
CONFIGURE_WRKSRC	?= $(WRKSRC)/$(WRKSRC_SUBDIR)
BUILD_WRKSRC		?= $(WRKSRC)/$(WRKSRC_SUBDIR)
INSTALL_WRKSRC		?= $(WRKSRC)/$(WRKSRC_SUBDIR)

# Name of cookies used to skip already completed stages
EXTRACT_COOKIE		?= $(WRKDIR)/extract._done.$(PKGNAME)
PATCH_COOKIE		?= $(WRKDIR)/patch._done.$(PKGNAME)
CONFIGURE_COOKIE	?= $(WRKDIR)/configure._done.$(PKGNAME)
BUILD_COOKIE		?= $(WRKDIR)/build._done.$(PKGNAME)
STAGE_COOKIE		?= $(WRKDIR)/stage._done.$(PKGNAME)
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

ifeq ($(NO_CHECK_CERTIFICATE),yes)
FETCH_CMD		+= --no-check-certificate
endif

# stuff for extract ...

ifeq ($(USE_ZIP),yes)
EXTRACT_CMD		?= unzip
EXTRACT_BEFORE_ARGS	?= -q
EXTRACT_AFTER_ARGS	?= -d $(DISTNAME)
else
EXTRACT_BEFORE_ARGS	?= -dc
ifneq ($(EXTRACT_TRANSFORM),)
ifeq ($(OPSYS),linux)
EXTRACT_AFTER_ARGS	= | $(TAR) -x --xform s$(EXTRACT_TRANSFORM) -f -
else
ifeq ($(OPSYS),darwin)
EXTRACT_AFTER_ARGS	= | $(TAR) -x -s $(EXTRACT_TRANSFORM) -f -
endif
endif
else
EXTRACT_AFTER_ARGS	?= | $(TAR) -xf -
endif
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

#
# examples for git
#
# git clone https://chromium.googlesource.com/webm/libwebp (Google webp)
# git clone git@github.com:mbj4668/pyang.git               (Github pyang)
# git clone git@10.2.3.6:swc/swc.git                       (Gitlab swc)
# git clone git@apostles.idv.tw:/srv/git/lang.git          (Personal...)
#
# git clone https://       chromium.googlesource.com             / webm/lib webp
# git clone          git@  github.com                :  mbj4668  /          pyang   .git
# git clone          git@  10.2.3.6                  :  swc      /          swc     .git
# git clone          git@  apostles.idv.tw           :           / srv/git/ lang    .git
# ^^^^^^^^^ ^^^^^^^^ ^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^    ^^^^^^^^   ^^^^^^^^ ^^^^^^^ ^^^^^^^^^^^^^^^^^^
# |         #1       |  #2 |                         #3 |          |        |       |
# |         |        |     |                            |          |        |       $(SCM_REPO_SUFFIX)
# |         |        |     |                            |          |        $(PORTNAME)
# |         |        |     |                            |          $(SCM_REPO_PREFIX)
# |         |        |     |                            $(MASTER_SITE_SUBDIR)
# |         |        |     $(MASTER_SITES)
# |         |        $(SCM_USER)
# |         $(SCM_PROTOCOL)
# $(SCM_CMD)
#
# NOTE:
#  #1. $(SCM_PROTOCOL) default keep unset means SSH will be used as default
#  #2. '@' must be existed if $(SCM_USER) is set
#  #3. ":" must be existed if $(SCM_PROTOCOL) didn't set

SCM_BRANCH		?=
SCM_REPO_PREINIT_CMD	?= autogen.sh

ifeq ($(USE_SCM),git)
SCM_LS_CMD		?= git ls-remote
SCM_CMD			?= git clone
SCM_PROTOCOL		?=

ifeq ($(SCM_PROTOCOL),)
SCM_USER		?= git
endif
# MASTER_SITES
# MASTER_SITE_SUBDIR
SCM_REPO_PREFIX		?=
# DISTNAME
SCM_REPO_SUFFIX		?= .git

ifneq ($(words $(MASTER_SITES)),1)
$(error Oops, you set multiple MASTER_SITES while using USE_SCM is set)
endif

SCM_REPO_URL		?= $(SCM_PROTOCOL)$(if $(SCM_USER),$(SCM_USER)@)$(MASTER_SITES)$(if $(SCM_PROTOCOL),,:)$(MASTER_SITE_SUBDIR)/$(SCM_REPO_PREFIX)$(PORTNAME)$(SCM_REPO_SUFFIX)

# $(warning SCM_REPO_URL=$(SCM_REPO_URL))
endif

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
	DESTDIR=$(STAGEDIR)						\
	PREFIX=$(PREFIX) LOCALBASE=$(LOCALBASE) LIBDIR="$(LIBDIR)"	\
	CC="$(CC)" CFLAGS="$(CFLAGS)"					\
	CPP="$(CPP)" CPPFLAGS="$(CPPFLAGS)"				\
	CXX="$(CXX)" CXXFLAGS="$(CXXFLAGS)"				\
	LDFLAGS="$(LDFLAGS)"

# stuff for stage ...

QA_ENV			+=						\
	STAGEDIR=$(STAGEDIR) PREFIX=$(PREFIX)				\
	LOCALBASE=$(LOCALBASE) "STRIP=$(STRIP)" TMPPLIST=$(TMPPLIST)

# stuff for install/deinstall/uninstall ...

DESCR			?= $(PKGDIR)/pkg-descr
PLIST			?= $(call config.lookup,$(PLIST_NAME))
PKGINSTALL		?= $(PKGDIR)/pkg-install
PKGDEINSTALL		?= $(PKGDIR)/pkg-deinstall
PKGREQ			?= $(PKGDIR)/pkg-req
PKGMESSAGE		?= $(PKGDIR)/pkg-message

# $(warning PLIST=$(PLIST))

TMPPLIST		?= $(WRKDIR)/.PLIST.mktmp

# stuff for package ...

PLIST_EXT		= $(patsubst					\
			    $(patsubst					\
			      %/work,%,$(WRKDIR))/pkg-plist.%,%,$(PLIST))

ORIGIN			= $(shell echo $1 | sed -e 's/^.*\/\(.*\/.*$$\)/\1/g')

PKG_ENV			+=						\
	STAGEDIR=$(STAGEDIR)						\
	PKGNAME=$(PKGNAME)						\
	VERSION=$(PKGVERSION)						\
	ORIGIN=$(call ORIGIN,$(MASTERDIR))				\
	PREFIX=$(PREFIX)						\
	INDEX=$(CATEGORIES)						\
	COMPRESS=XZ							\
	EXT=$(PLIST_EXT)						\
	PLIST=$(PLIST)							\
	WRKDIR_PKGFILE=$(WRKDIR_PKGFILE)

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

PKG_SUFX		?= .pkg
PKG_COMPRESSION_FORMAT	?= $(patsubst .%,%,PKG_SUFX)
ifneq ($(OPSYS_SUFX),)
REPO_SUFX		?= -$(OPSYS)-$(OPSYS_SUFX)-$(ARCH)
else
REPO_SUFX		?= -$(OPSYS)-$(ARCH)
endif
PKGREPOSITORYSUBDIR	?= All$(REPO_SUFX)
PKGREPOSITORY		?= $(PACKAGES)/$(PKGREPOSITORYSUBDIR)
ifneq ($(wildcard $(PACKAGES)),)
_HAVE_PACKAGES		= yes
PKGFILE			?= $(PKGREPOSITORY)/$(PKGNAME)$(PKG_SUFX)
#PKGOLDFILE		?= $(PKGREPOSITORY)/$(PKGNAME).$(PKG_COMPRESSION_FORMAT)
else
PKGFILE			?= $(CURDIR)/$(PKGNAME)$(PKG_SUFX)
endif
WRKDIR_PKGFILE		= $(WRKDIR)/pkg/$(PKGNAME)$(PKG_SUFX)
#REPO_PKGFILE		?= $(PKGREPOSITORY)/$(PKGNAME)$(PKG_SUFX)

# $(warning _HAVE_PACKAGES=$(_HAVE_PACKAGES))

# The "latest version" link -- $(PKGNAME) minus everthing after the last '-'
PKGLATESTREPOSITORY	?= $(PACKAGES)/Latest$(REPO_SUFX)
PKGBASE			?= $(PKGNAMEPREFIX)$(PORTNAME)$(PKGNAMESUFFIX)
PKGLATESTFILE		= $(PKGLATESTREPOSITORY)/$(PKGBASE)$(PKG_SUFX)
#PKGOLDLATESTFILE	= $(PKGLATESTREPOSITORY)/$(PKGBASE).$(PKG_COMPRESSION_FORMAT)
# Temporary workaround to be deleted once every supported version of FreeBSD
# have a bootstrap which handles the pkg extension.
PKGOLDSIGFILE		= $(PKGLATESTREPOSITORY)/$(PKGBASE).$(PKG_COMPRESSION_FORMAT).sig

all: stage
.DEFAULT_GOAL		:= all

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
ifeq ($(USE_SCM),)
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
else
do-fetch:
endif
endif
endif

#
# Extract...
#

do-extract: wrkdir

extract_cmd_name	=						\
	$(shell basename `echo $(EXTRACT_CMD) | sed -e 's/-.*//g'`)
#$(warning =============> extract_cmd_name=$(extract_cmd_name))

quiet_cmd_wrkdir	?=
      cmd_wrkdir	?= set -e;					\
	[ -d $(WRKDIR) ] || mkdir -p $(WRKDIR);

quiet_cmd_chk-unzip	?=
      cmd_chk-unzip	?= set -e;					\
	case $(extract_cmd_name) in unzip) mkdir -p $(WRKSRC);; esac

ifeq ($(USE_ALTERNATIVE),yes)
quiet_cmd_wrkdir-alt	?=
      cmd_wrkdir-alt	?= set -e;					\
	[ -d $(ALTERNATIVE_WRKDIR) ] || mkdir -p $(ALTERNATIVE_WRKDIR)

quiet_cmd_chk-unzip-alt	?=
      cmd_chk-unzip-alt	?= set -e;					\
	case $(extract_cmd_name) in 					\
	    unzip) 							\
	        if [ ! -d $(ALTERNATIVE_WRKSRC) ]; then			\
	            mkdir -p $(ALTERNATIVE_WRKSRC);			\
	        fi;;							\
	esac
endif

.PHONY: wrkdir
wrkdir:
	$(call cmd,wrkdir)
ifeq ($(USE_ALTERNATIVE),yes)
	$(call cmd,wrkdir-alt)
ifeq ($(USE_STICKY),yes)
else
	@rm -fr $(ALTERNATIVE_WRKSRC)
	$(call cmd,chk-unzip-alt)
endif
else
	$(call cmd,chk-unzip)
endif

quiet_cmd_extract-only	?=
      cmd_extract-only	?= set -e;					\
	(cd $(WRKDIR) && if [ -f $(_DISTDIR)/$@ ]; then $(EXTRACT_CMD) $(EXTRACT_BEFORE_ARGS) $(_DISTDIR)/$@ $(EXTRACT_AFTER_ARGS); fi)

ifeq ($(USE_ALTERNATIVE),yes)
# FIXME: add extra handle if $(ALTERNATIVE_WRKSRC) is a symbolic link...
#        for example: sbl-elf-2.7.6
quiet_cmd_extract-only-alt	?=
      cmd_extract-only-alt	?= set -e;				\
	(cd $(ALTERNATIVE_WRKDIR) && if [ -f $(_DISTDIR)/$@ ]; then $(EXTRACT_CMD) $(EXTRACT_BEFORE_ARGS) $(_DISTDIR)/$@ $(EXTRACT_AFTER_ARGS); fi)
endif

ifeq ($(USE_STICKY),yes)
quiet_cmd_extract-only-sticky	?=
      cmd_extract-only-sticky	?= set -e;				\
	if [ ! -e $(ALTERNATIVE_WRKSRC) ]; then				\
	    case $(extract_cmd_name) in 				\
	        unzip) mkdir -p $(ALTERNATIVE_WRKSRC);; 		\
	    esac; 							\
	    (cd $(ALTERNATIVE_WRKDIR) && if [ -f $(_DISTDIR)/$@ ]; then $(EXTRACT_CMD) $(EXTRACT_BEFORE_ARGS) $(_DISTDIR)/$@ $(EXTRACT_AFTER_ARGS); fi); \
	fi
endif

$(EXTRACT_ONLY): wrkdir
ifeq ($(USE_ALTERNATIVE),yes)
ifeq ($(USE_STICKY),yes)
	$(call cmd,extract-only-sticky)
else
	$(call cmd,extract-only-alt)
endif
	@if [ ! -d $(WRKDIR)/$(ALTERNATIVE_PREFIX) ]; then		\
	    mkdir -p $(WRKDIR)/$(ALTERNATIVE_PREFIX);			\
	fi
else
	$(call cmd,extract-only)
endif

#(call lookup-branch branches(ls-remote),branch)
lookup-branch		= $(word 1,					\
			    $(filter %$(2) $(2)%,			\
			      $(patsubst refs/heads/%,%,$(1))))
branches		:= $(shell $(SCM_LS_CMD) $(SCM_REPO_URL)	\
			     2>/dev/null | grep "refs/heads")

ifeq ($(USE_SCM),git)
quiet_cmd_git-clone	?=
      cmd_git-clone	?= set -e;					\
	if [ -z "$(branches)" ]; then					\
	    $(kecho) "  ERR     Unable connect to $(SCM_REPO_URL)";	\
	    false;							\
	fi;								\
	if [ -z "$(SCM_BRANCH)" ]; then					\
	    branch=$(call lookup-branch,$(branches),$(PORTVERSION),heads); \
	else								\
	    branch=$(call lookup-branch,$(branches),$(SCM_BRANCH),heads); \
	fi;								\
	if [ -z "$$branch" ]; then					\
	    $(kecho) "  ERR     Can't find specific branch($$branch)";	\
	    false;							\
	fi;								\
	cd $(WRKDIR);							\
	$(kecho) "  GIT     $(DISTNAME)(clone:$$branch)";		\
	$(SCM_CMD) -b $$branch $(SCM_REPO_URL) $(DISTNAME)
endif

ifeq ($(filter $(override_targets),do-extract),)
ifeq ($(USE_SCM),)
do-extract: $(EXTRACT_ONLY)
else
do-extract:
ifeq ($(USE_SCM),git)
	$(call cmd,git-clone)
endif
endif
endif

ifeq ($(USE_ALTERNATIVE),yes)
quiet_cmd_post-extract-alt	?=
      cmd_post-extract-alt	?= set -e;				\
	if [ -d $(ALTERNATIVE_WRKDIR) ]; then				\
	    if [ -d $(WRKSRC) ]; then					\
	        rm -fr $(ALTERNATIVE_WRKSRC);				\
	        mkdir -p $(ALTERNATIVE_WRKDIR)/$(ALTERNATIVE_PREFIX);	\
	        mv $(WRKSRC) $(ALTERNATIVE_WRKSRC);			\
	    fi;								\
	    ln -s $(ALTERNATIVE_WRKSRC) $(WRKSRC);			\
	fi

post-extract-alternative:
	$(call cmd,post-extract-alt)

post-extract: post-extract-alternative
endif

ifeq ($(GNU_CONFIGURE),yes)
ifneq ($(WRKSRC_SUBDIR),)
quiet_cmd_post-extract-subdir	?=
      cmd_post-extract-subdir	?= set -e;				\
	mkdir -p $(WRKSRC)/$(WRKSRC_SUBDIR)

post-extract-subdir:
	$(call cmd,post-extract-subdir)

post-extract: post-extract-subdir
endif
endif

#
# Patch...
#

ask-license:

ifneq ($(USE_SCM),)
quiet_cmd_pre-init-repo	?=
      cmd_pre-init-repo	?= set -e;					\
	cd $(WRKSRC);							\
	if [ -x $(SCM_REPO_PREINIT_CMD) ]; then				\
	    ./$(SCM_REPO_PREINIT_CMD);					\
	fi

pre-init-repo:
	$(call cmd,pre-init-repo)
pre-patch: pre-init-repo
endif

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
ifeq ($(USE_SCM),)
do-patch: git-init
	$(call cmd,apply-git-patches)
else
ifeq ($(SCM_BRANCH),)
do-patch:
ifneq ($(NO_SCM_PATCH_APPLY),yes)
	$(call cmd,apply-git-patches)
endif
else
do-patch:
endif
endif
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
# Stage ...
#

quiet_cmd_stagedir	?=
      cmd_stagedir	?= set -e;					\
	[ -d $(STAGEDIR)$(PREFIX) ] || mkdir -p $(STAGEDIR)$(PREFIX);

ifeq ($(filter $(override_targets),stage-dir),)
stage-dir:
	$(call cmd,stagedir)
endif

quiet_cmd_stageqa	?= STAGE-QA $(PKGNAME)
      cmd_stageqa	?= set -e;					\
	$(SETENV) $(QA_ENV) $(SH) $(SCRIPTSDIR)/qa.sh

ifeq ($(filter $(override_targets),makeplist),)
makeplist: generate-plist
endif

ifeq ($(filter $(override_targets),check-plist),)
check-plist: generate-plist
endif

ifeq ($(filter $(override_targets),stage-qa),)
stage-qa:
	$(call cmd,stageqa)
endif

#
# Install...
#

install-license:

quiet_cmd_run-install	?=
      cmd_run-install	?= set -e;					\
	(cd $(INSTALL_WRKSRC) &&					\
	    $(SETENV) $(MAKE_ENV) $(MAKE) $(MAKE_FLAGS) $(MAKEFILE)	\
	    DESTDIR=$(STAGEDIR) $(MAKE_ARGS) $(INSTALL_TARGET))

ifeq ($(filter $(override_targets),do-install),)
do-install:
	$(call cmd,run-install)
endif

fixup-lib-pkgconfig:

#
# Package...
#

MKDIR			?= /bin/mkdir -p
LN			?= ln

#$(_PORTS_DIRECTORIES):
$(WRKDIR)/pkg:
	@$(MKDIR) $@

$(PKGREPOSITORY):
	@$(MKDIR) $@

_PORTS_DIRECTORIES	+= $(WRKDIR)/pkg

ifeq ($(_HAVE_PACKAGES),yes)
_EXTRA_PACKAGE_TARGET_DEP	+= $(PKGFILE)
_PORTS_DIRECTORIES	+= $(PKGREPOSITORY)

quiet_cmd_copy-package	?=
      cmd_copy-package	?= set -e;					\
	if [ -d $(PACKAGES) ]; then					\
	    $(kecho) "  COPY    $(PKGNAME)";				\
	    $(LN) -f $(WRKDIR_PKGFILE) $(PKGFILE) 2>/dev/null || cp -f $(WRKDIR_PKGFILE) $(PKGFILE); \
	fi

$(PKGFILE): $(WRKDIR_PKGFILE) $(PKGREPOSITORY)
	$(call cmd,copy-package)
endif

# from here this will become a loop for subpackages
quiet_cmd_wrkdir-package?=
      cmd_wrkdir-package?= set -e;					\
	$(SETENV) $(PKG_ENV) $(SH) $(SCRIPTSDIR)/pkg.sh create

$(WRKDIR_PKGFILE): $(WRKDIR)/pkg
	$(call cmd,wrkdir-package)

_EXTRA_PACKAGE_TARGET_DEP	+= $(WRKDIR_PKGFILE)
# This will be the end of the loop

ifeq ($(filter $(override_targets),do-package),)
do-package: $(_EXTRA_PACKAGE_TARGET_DEP) $(WRKDIR)/pkg
endif

quiet_cmd_delete-package?= DELETE  $(PKGNAME)
      cmd_delete-package?= set -e;					\
	rm -fr $(PACKAGE_COOKIE);					\
	rm -fr "$(PKGFILE)" "$(WRKDIR_PKGFILE)" 2>/dev/null || :

ifeq ($(filter $(override_targets),delete-package),)
delete-package:
	$(call cmd,delete-package)
endif

ifeq ($(filter $(override_targets),delete-package-list),)
delete-package-list:
	@echo "[ -f $(PKGFILE) ] && (echo deleting $(PKGFILE); rm $(PKGFILE))"
endif

ifeq ($(PORTS_VERBOSE),1)
_INSTALL_PKG_ARGS=
else
_INSTALL_PKG_ARGS= -q
endif

quiet_cmd_install-package?= PKG ADD $(PKGNAME)
      cmd_install-package?= set -e;					\
	if [ -f "$(WRKDIR)/pkg/$(PKGNAME)$(PKG_SUFX)" ]; then		\
	    _pkgfile="$(WRKDIR_PKGFILE)";				\
	else								\
	    _pkgfile="$(PKGFILE)";					\
	fi;								\
	$(SCRIPTSDIR)/pkg.sh add $(_INSTALL_PKG_ARGS) $${_pkgfile}

ifneq ($(DESTDIR),)
ifeq ($(filter $(override_targets),install-package),)
install-package:
	$(call cmd,install-package)
endif
endif


# Utility targets follow

cai_msg0="  You may wish to \`\`make deinstall'' and install this port again"
cai_msg1="  by \`\`make reinstall'' to upgrade it properly."
cai_msg2="  If you really wish to overwrite the old port of ${PKGBASE}"
cai_msg3="  without deleting it first, set the variable \"FORCE_PKG_REGISTER\""
cai_msg4="  in your environment or the \"make install\" command line."

quiet_cmd_check-already-installed?=
      cmd_check-already-installed?= set -e;				\
	pkgname=`$(SCRIPTSDIR)/pkg.sh info -q -O $(PKGBASE)`;		\
	if [ -n "$$pkgname" ]; then					\
	    v=`$(SCRIPTSDIR)/pkg.sh version -t $$pkgname $(PKGNAME)`;	\
	    if [ "$$v" = "<" ]; then					\
	        $(kecho) "  ===>    An older version of $(PKGBASE) is already installed ($${pkgname})"; \
	    else							\
	        $(kecho) "  ===>    $(PKGNAME) is already installed";	\
	    fi;								\
	    $(kecho) $(cai_msg0);					\
	    $(kecho) $(cai_msg1);					\
	    $(kecho) $(cai_msg2);					\
	    $(kecho) $(cai_msg3);					\
	    $(kecho) $(cai_msg4);					\
	fi

ifeq ($(filter $(override_targets),check-already-installed),)
check-already-installed:
ifneq ($(DESTDIR),)
	$(call cmd,check-already-installed)
endif
endif

#- install-mtree
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

_TARGET_STAGES		= SANITY PKG FETCH EXTRACT PATCH CONFIGURE	\
			  BUILD STAGE INSTALL PACKAGE

# Define the SEQ of actions to take when each target is ran, and which targets
# it depends on before running its SEQ.
#
# Main target has a priority of 500, pre-target 300, post-target 700,
# target-depends 150.  Other targets are spaced in between those
#
# If you change the pre-foo and post-foo values here, go and keep them in sync
# in _OPTIONS_TARGETS in bsd.options.mk

_SANITY_SEQ		= 100:pre-everything				\
			  250:check-categories 600:check-license
_PKG_DEP		= check-sanity
_PKG_SEQ		= 500:pkg-depends
_FETCH_DEP		= pkg
_FETCH_SEQ		= 100:fetch-depends				\
			  300:pre-fetch 450:pre-fetch-script		\
			  500:do-fetch					\
			  700:post-fetch 850:post-fetch-script
_EXTRACT_DEP		= fetch
_EXTRACT_SEQ		= 050:extract-message				\
			  100:checksum					\
			  150:extract-depends				\
			  300:pre-extract 450:pre-extract-script	\
			  500:do-extract				\
			  700:post-extract 850:post-extract-script
_PATCH_DEP		= extract
_PATCH_SEQ		= 050:ask-license				\
			  100:patch-message				\
			  150:patch-depends				\
			  300:pre-patch 450:pre-patch-script		\
			  500:do-patch					\
			  700:post-patch 850:post-patch-script
_CONFIGURE_DEP 		= patch
_CONFIGURE_SEQ		= 150:build-depends 151:lib-depends		\
			  200:configure-message				\
			  300:pre-configure 450:pre-configure-script	\
			  490:run-autotools-fixup			\
			  491:configure-autotools 492:run-autotools	\
			  500:do-configure				\
			  700:post-configure 850:post-configure-script
_BUILD_DEP		= configure
_BUILD_SEQ		= 100:build-message				\
			  300:pre-build 450:pre-build-script		\
			  500:do-build					\
			  700:post-build 850:post-build-script
_STAGE_DEP		= build
# STAGE is special in its numbering as it has install and stage, so install is
# the main, and stage goes after.
_STAGE_SEQ		= 50:stage-message 100:stage-dir 150:run-depends\
			  300:pre-install 450:pre-install-script	\
			  500:do-install				\
			  600:fixup-lib-pkgconfig			\
			  700:post-install 750:post-install-script	\
			  800:post-stage				\
			  870:install-ldconfig-file			\
			  880:install-license
ifdef DEVELOPER
_STAGE_SEQ		+= 995:stage-qa
else
stage-qa: stage
endif
_INSTALL_DEP		= stage
_INSTALL_SEQ		= 100:install-message				\
			  200:check-already-installed			\
			  500:security-check
_PACKAGE_DEP		= stage
_PACKAGE_SEQ		= 100:package-message				\
			  300:pre-package 450:pre-package-script	\
			  500:do-package				\
			  700:post-package 850:post-package-script

# Enforce order for -jN builds

# step 1.
#              +---------> TARGET_ORDER_OVERRIDES --------->+
#              | (replace directly if existed, didn't sort) |
#  _XXX_SEQ ----------------------------------------------------> _XXX_REAL_SEQ

# $(call rm-order, order:target)
rm-order		= $(lastword $(subst :, ,$1))
# $(call rm-seq-order, _XXX_SEQ)
rm-seq-order		= $(foreach t,$1,$(call rm-order,$t))

# $(call init-setup-depend, STAGE)
define init-setup-depend-1
_$1_REAL_SEQ		:=
endef

$(foreach s,$(_TARGET_STAGES),						\
  $(eval								\
    $(call init-setup-depend-1,$s)))

#(call filter-overrides, order:target, TARGET_ORDER_OVERRIDES)
filter-overrides	= $(if						\
			    $(filter					\
			      $(call rm-order,$1),			\
			      $(call rm-seq-order,$2)),			\
			    $(filter %:$(call rm-order,$1),$2),		\
			    $1)

# $(call regenerate-order-seq, STAGE, override-checked-order:target)
define regenerate-order-seq
_$1_REAL_SEQ		:= $(_$1_REAL_SEQ) $2
endef

$(foreach s,$(_TARGET_STAGES),						\
  $(foreach t,$(_$s_SEQ),						\
    $(eval								\
      $(call regenerate-order-seq,$s,					\
        $(call filter-overrides,$t,$(TARGET_ORDER_OVERRIDES))))))

# setp 2.
#
# sort(_XXX_REAL_SEQS) ===> seq[0..n]
#
#  *) _PHONY_TARGETS += seq[0..n]
#  *) make seq[0..n] dependence      seq[1]: seq[0]
#   )                        seq[2]: seq[1]
#   )                seq[3]: seq[2]
#   )          ...
#   )      seq[n]: seq[n-1]

# $(call get-real-seqs, STAGE)
get-real-seqs		= $(call rm-seq-order,$(sort $(_$1_REAL_SEQ)))
# $(call first-seq, STAGE)
first-seq		= $(firstword $(call get-real-seqs,$1))
# $(call other-seqs, STAGE)
other-seqs		= $(filter-out					\
			    $(call first-seq,$1),$(call get-real-seqs,$1))

# $(call init-setup-depend, STAGE, seq[0])
define init-setup-depend-2
_PHONY_TARGETS		+= $2
_$1_IDX			:= $2
endef

$(foreach s,$(_TARGET_STAGES),						\
  $(eval								\
    $(call init-setup-depend-2,$s,$(call first-seq,$s))))


# $(call setup-dependence, STAGE, seq[1..n])
define setup-dependence
_PHONY_TARGETS		+= $2
$2: | $($1_IDX)

_$1_IDX			:= $2
endef

$(foreach s,$(_TARGET_STAGES),						\
  $(foreach t,$(call other-seqs,$s),					\
    $(eval								\
      $(call setup-dependence,$s,$t))))

# Define all of the main targets which depend on a sequence of other targets.
# See above *_SEQ and *_DEP. The _DEP will run before this defined target is
# ran. The _SEQ will run as this target once _DEP is satisfied.

_TARGET_TARGETS		= extract patch configure build stage install package

# $(call uppercase-target, target)
define uppercase-target
$(strip									\
  $(if $(filter $1,extract),EXTRACT,					\
    $(if $(filter $1,patch),PATCH,					\
      $(if $(filter $1,configure),CONFIGURE,				\
        $(if $(filter $1,build),BUILD,					\
          $(if $(filter $1,stage),STAGE,				\
            $(if $(filter $1,install),INSTALL,				\
              $(if $(filter $1,package),PACKAGE))))))))
endef

#$(warning _EXTRACT_REAL_SEQ=$(call get-real-seqs,EXTRACT))
#$(warning _PATCH_REAL_SEQ=$(_PATCH_REAL_SEQ))
#$(warning _PATCH_REAL_SEQ=$(call get-real-seqs,PATCH))
#$(warning _CONFIGURE_REAL_SEQ=$(call get-real-seqs,CONFIGURE))
#$(warning _BUILD_REAL_SEQ=$(call get-real-seqs,BUILD))
#$(warning _INSTALL_REAL_SEQ=$(call get-real-seqs,INSTALL))
#$(warning _PACKAGE_REAL_SEQ=$(call get-real-seqs,PACKAGE))

# $(call generate-cookie-targets, target, TARGET)
define generate-cookie-targets
_PHONY_TARGETS	+= $1
ifeq ($(filter $(override_targets),$1),)
$1: $($2_COOKIE)
endif
ifeq ($(wildcard $($2_COOKIE)),)
#ifneq ($($(patsubst %,_%_NEXT,$2)),)
#$($(patsubst %,_%_NEXT,$2)): $($(patsubst %,_%_LINK,$2))
#endif
$($2_COOKIE): $(_$2_DEP) $(call get-real-seqs,$2)
	@touch $($2_COOKIE)
ifneq ($($2_LISTS),)
	@echo $($2_LISTS) >> $($2_COOKIE)
endif
else
$($2_COOKIE):
	@$(DO_NADA)
endif
endef

$(foreach t,$(_TARGET_TARGETS),						\
  $(eval 								\
    $(call generate-cookie-targets,$t,$(call uppercase-target,$t))))

#$(warning _SANITY_REAL_SEQ=$(SANITY_REAL_SEQ))
#$(warning _SANITY_REAL_SEQ=$(call get-real-seqs,SANITY))
#$(warning _PKG_REAL_SEQ=$(call get-real-seqs,PKG))
#$(warning _FETCH_REAL_SEQ=$(call get-real-seqs,FETCH))

.PHONY: $(_PHONY_TARGETS) check-sanity pkg fetch

ifeq ($(filter $(override_targets),check-sanity),)
check-sanity: $(call get-real-seqs,SANITY)
endif

ifeq ($(filter $(override_targets),pkg),)
pkg: $(_PKG_DEP) $(call get-real-seqs,PKG)
endif

ifeq ($(filter $(override_targets),fetch),)
fetch: $(_FETCH_DEP) $(call get-real-seqs,FETCH)
endif

#

ifeq ($(USE_ALTERNATIVE),yes)
ifeq ($(USE_STICKY),yes)
extract_suffix		= $(shell 					\
	if [ ! -e $(ALTERNATIVE_WRKSRC) ]; then 			\
	    echo "(NO STICKY)"; 					\
	else 								\
	    echo "(STICKY)"; 						\
	fi)
else
extract_suffix		= (ALTERNATIVE)
endif
endif

extract-message:
	@$(kecho) "  EXTRACT $(PKGNAME)$(extract_suffix)"
patch-message:
	@$(kecho) "  PATCH   $(PKGNAME)"
configure-message:
	@$(kecho) "  CONFIGURE $(PKGNAME)"
build-message:
	@$(kecho) "  BUILD   $(PKGNAME)"
stage-message:
	@$(kecho) "  STAGE   $(PKGNAME)"
install-message:
	@$(kecho) "  INSTALL $(PKGNAME)"
package-message:
	@$(kecho) "  PACKAGE $(PKGNAME)"

# Empty pre-* and post-* targets

embellish_targets	:=						\
	$(patsubst %,pre-%,fetch $(_TARGET_TARGETS))			\
	$(patsubst %,post-%,fetch $(_TARGET_TARGETS))

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

embellish_script_targets:=						\
	$(patsubst %,%-script,$(embellish_targets))

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
	@rm -f $(INSTALL_COOKIE)
	@cd $(CURDIR) && make install
endif

ifeq ($(filter $(override_targets),restage),)
restage:
	@rm -fr $(STAGEDIR) $(WRKDIR)/pkg
	@rm -f $(STAGE_COOKIE) $(INSTALL_COOKIE) $(PACKAGE_COOKIE)
	@cd $(CURDIR) && make stage
endif

# deinstall/uninstall

ifeq ($(filter $(override_targets),pre-deinstall),)
pre-deinstall:
	@$(DO_NADA)
endif

quiet_cmd_deinstall?= UNINSTALL $(PKGBASE)
      cmd_deinstall?= set -e;						\
	if $(SCRIPTSDIR)/pkg.sh info -e $(PKGBASE); then		\
	    p=`$(SCRIPTSDIR)/pkg.sh info -qO $(PKGBASE)`;		\
	    $(kecho) "  UNINSTALL $$p";					\
	    $(SCRIPTSDIR)/pkg.sh delete -fq $(PKGBASE);			\
	else								\
	    $(kecho) "  $(PKGBASE) not installed, skipping";		\
	fi

ifeq ($(filter $(override_targets),deinstall uninstall),)
deinstall uninstall: pre-deinstall
ifneq ($(DESTDIR),)
	$(call cmd,deinstall)
	@rm -f $(INSTALL_COOKIE)
#	@cd $(MASTERDIR) && $(MAKE) $(__softMAKEFLAGS) run-ldconfig
endif
endif

# clean

ifeq ($(filter $(override_targets),do-clean),)
do-clean:
	@if [ -d $(WRKSRC) ]; then					\
	    $(kecho) "  CLEAN     $(PKGNAME)";				\
	    (cd $(WRKSRC) && make clean$(trash));			\
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
ifeq ($(USE_ALTERNATIVE),yes)
ifneq ($(USE_STICKY),yes)
ifeq ($(FORCE_ALTERNATIVE_REMOVE),yes)
	@if [ -h $(ALTERNATIVE_WRKSRC) ]; then				\
	    rm $(ALTERNATIVE_WRKSRC);					\
	elif [ -d $(ALTERNATIVE_WRKSRC) ]; then				\
	    rm -fr $(ALTERNATIVE_WRKSRC);				\
	fi
endif
endif
endif
	@if [ -d $(WRKDIR) ]; then					\
	        $(kecho) "  DISTCLEAN $(PKGNAME)";			\
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
	    cd $(STAGEDIR)/$(PREFIX) &&					\
                find . | sort -r | $(SED) -e '/^\.$$/d' > $(TMPPLIST);	\
	fi

generate-plist: stage
	$(call cmd,generate-plist)

$(TMPPLIST): generate-plist

#- compress-man:
#- fake-pkg:
#- depend:
#- tags:

    endif
  endif
# End of post-makefile section.

#endif
# End of the DESTDIR if statement
