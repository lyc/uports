#
# tools.mk
#

# $(call subdirectory,makefile)
subdirectory		= $(patsubst %/$1,%,				\
			    $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))

portdir			:= $(abspath $(call subdirectory,tools.mk)/..)

include $(portdir)/Mk/linux.debug.mk

# default target ...
all:

#
# global lists ...
#
#   ports_all_raw_lists:
#   categories_all_lists:
#   suffix_all_lists:
#

# find all port packages inside $(portdir) ...
ports_all_raw_lists	= $(shell find $(portdir)			\
			               -mindepth 2 -maxdepth 2	-type d	\
			               | sed -e 's|^$(portdir)/||'	\
			                     -e '/^Mk.*/d'		\
			                     -e '/^distfiles.*/d'	\
			                     -e '/^packages.*/d'	\
			                     -e '/^Templates.*/d'	\
			                     -e '/^Tools.*/d'		\
			                     -e '/^\.git.*/d')

categories_all_lists	=						\
	accessibility archivers astro audio benchmarks biology cad	\
	comms converters databases deskutils devel dns docs editors	\
	elisp emulators ftp games geography graphics hamradio haskell	\
	irc java lang linux lisp mail math mbone misc multimedia net	\
	net-im net-mgmt net-p2p net-vpn news parallel pear perl5 plan9	\
	ports-mgmt portuguese print python ruby rubygems scheme science	\
	security shells sysutils tcl textproc tk wayland windowmaker	\
	www x11 x11-clocks x11-drivers x11-fm x11-fonts x11-servers	\
	x11-themes x11-toolkits x11-wm xfce zope base

suffix_special_all	= package-source
suffix_all_lists	=						\
	fetch extract patch configure build stage package install	\
	clean distclean deinstall uninstall rebuild restage reinstall	\
	$(suffix_special_all)

#
# utilities ...
#

# $(call rm-slash, category/port ...)
SLASH			:= /
rm-slash		= $(subst $(SLASH), ,$1)

AT			:= @
rm-at			= $(subst $(AT), ,$1)

# $(call purify_port_raw, XXX@category/port@YYY)
purify_ports_raw	= $(strip					\
			    $(foreach p,$(call rm-at,$1),		\
			      $(if $(findstring $(SLASH),$p),$p,)))

# $(call get-XXX, port.suffix)
extract-port		= $(patsubst %$(suffix $1),%,$1)
extract-suffix		= $(patsubst .%,%,$(suffix $1))

# $(call get-category, port.suffix)
get-category		= $($(call extract-port,$1)_categories)

# $(call rm-port, [[group@]group@]category/port)
rm-port			= $(firstword $(call rm-slash,$1))

# $(call rm-category, [[group@]group@]category)
rm-category		= $(patsubst %$(lastword $(call rm-at,$1)),%,$1)

# $(call get-groups, [[group@]group@]category/port)
get-groups		= $(call rm-category,$(call rm-port,$1))

# $(call rm-groups, [[group@]group@]category/port)
rm-groups		= $(patsubst $(call get-groups,$1)%,%,$1)

# $(call complete-group-default, [group@[group@]]category/port, group)
complete-group-default	= $(strip					\
			    $(if $(call get-groups,$1),			\
			      $(foreach g,$(call rm-at,$(call get-groups,$1)),\
			        $(addprefix $g$(AT),$(call rm-groups,$1))),\
			      $(addprefix $2$(AT),$1)))

# $(call get-port, group@category/port)
get-port		= $(lastword $(call rm-slash,$1))

# $(call get-grroup, group@category/port)
get-group		= $(firstword $(call rm-at,$1))

# $(call filter-out-group-extra, group@category/port)
filter-out-group-extra	= $(if						\
			    $(filter-out $(call get-group,$1),		\
			    $($(call get-port,$1)_groups)),		\
			      $(if $(filter-out $(PORTS_GROUP_DEFAULT),	\
			        $(call get-group,$1)),,$1),$1)

# $(call rm-group, group@port.suffix)
rm-group		= $(lastword $(call rm-at,$1))

# $(call transform-port-string, group@port.suffix)
transform-port-string	= $(subst ., ,					\
			    $(firstword $(call rm-at,			\
			      $1))$(AT)$(call get-category,		\
			        $(call rm-group,$1))$(SLASH)$(call rm-group,$1))

#
# port ...
#
#   PORTS_LISTS:
#   ports_all_raw:
#   ports_all:
#

ifneq ($(PORTS_LISTS),)
ports_all_raw		= $(foreach p,					\
			    $(PORTS_LISTS),$(call purify_ports_raw,$p))
endif

ports_all_raw_unknown	= $(filter-out $(ports_all_raw_lists),$(ports_all_raw))
ifneq ($(ports_all_raw_unknown),)
$(error assign unknown packages: $(ports_all_raw_unknown))
endif

ifeq ($(ports_all_raw),)
ports_all_raw		= $(ports_all_raw_lists)
endif

ports_all		= $(filter-out $(categories_all_lists),		\
			    $(call rm-slash,$(ports_all_raw)))

#
# category ...
#
#   categories_all:
#   categories_xxx:
#   xxx_categories:
#

categories_all		= $(sort					\
			    $(filter-out $(ports_all),			\
			      $(call rm-slash,$(ports_all_raw))))

# $(call generate-categories-list, category)
define generate-categories-lists
  categories_$1		= $(filter-out $(categories_all_lists),		\
			    $(call rm-slash,				\
			      $(filter $1/%,$(ports_all_raw))))
endef

$(foreach c,$(categories_all),						\
  $(eval								\
    $(call generate-categories-lists,$c)))

# $(call generate-port-categories-list, category)
define generate-port-categories-lists
  $1_categories		= $(patsubst %/$1,%,$(filter %/$1,$(ports_all_raw)))
endef

$(foreach c,$(ports_all),						\
  $(eval								\
    $(call generate-port-categories-lists,$c)))

#
# group ...
#
#   PORTS_GROUP_DEFAULT:
#   ports_all_group:
#   groups_all:
#   ports_all_group_extra:
#   groups_xxx:
#   xxx_groups:
#

PORTS_GROUP_DEFAULT	?= host

ports_all_group		= $(foreach p,					\
			    $(if $(PORTS_LISTS),$(PORTS_LISTS),		\
			     $(ports_all_raw)),$(call complete-group-default,\
			       $p,$(PORTS_GROUP_DEFAULT)))

groups_all		= $(sort					\
			    $(foreach p,$(ports_all_group),		\
			      $(call rm-at,$(call get-groups,$p))))

ports_all_group_extra	= $(sort					\
			    $(foreach g,$(ports_all_group),		\
			      $(call filter-out-group-extra,$g)))

# $(warning groups_all=$(groups_all))

# $(call generate-groups-list, group)
define generate-groups-lists
  groups_$1		= $(foreach p,$(filter $1$(AT)%,		\
			    $(ports_all_group)),$(lastword $(call rm-slash,$p)))
endef

$(foreach g,$(groups_all),						\
  $(eval								\
    $(call generate-groups-lists,$g)))

# $(call generate-port-groups-lists, port)
define generate-port-groups-lists
  $1_groups		= $(foreach g,$(filter %/$1,			\
			    $(ports_all_group)),$(subst $(AT),,$(call get-groups,$g)))
endef

$(foreach p,$(ports_all),						\
  $(eval								\
    $(call generate-port-groups-lists,$p)))

#
#   ggg_SUFFIX:
#

# $(call find-groups-suffix, checker, envs)
find-group-suffix 	= $(strip					\
			    $(if $(filter $1_SUFFIX=%,$2),		\
			      $(patsubst $1_SUFFIX=%,%,$(filter $1_SUFFIX=%,$2)),))

# FIXME!
#   Can't put $1_SFX1, $1_SFX2 and $1_SUFFIX into single define,
#   Just separate it now.

# $(call generate-group-suffix, group)
define generate-suffix
  $1_SFX1		= $(if $(call find-group-suffix,$1,$(PORTS_$1_ENVS)),\
			    $(call find-group-suffix,$1,$(PORTS_$1_ENVS)),\
			    $(if $(filter-out $1,$(groups_all)),$1,))
  $1_SFX2		= $(call find-group-suffix,TYPE,$(PORTS_ENVS))
endef

$(foreach g,$(groups_all),						\
  $(eval								\
    $(call generate-suffix,$g)))

define generate-groups-suffix
  $1_SUFFIX		= $(if $($1_SFX2),-$($1_SFX2),)$(if $($1_SFX1),$(if $($1_SFX2),$(if $(filter-out $($1_SFX1),$($1_SFX2)),.$($1_SFX1),),.$($1_SFX1)),)
endef

$(foreach g,$(groups_all),						\
  $(eval								\
    $(call generate-groups-suffix,$g)))

#
# generate port_ggg_xxx_env variable...
#

define add-ports-env
PORTS_ENVS		+= $1=$($1)
endef

ENVS_OPTS		= USE_GLOBALBASE DISTDIR_SITE PACKAGES_SITE	\
			  USE_ALTERNATIVE FORCE_ALTERNATIVE_REMOVE

$(if $(PORTS_ENVS),,							\
  $(foreach v,$(ENVS_OPTS),						\
    $(eval								\
      $(if $($v),							\
        $(call add-ports-env,$v)))))

PORTS_$(PORTS_GROUP_DEFAULT)_ENVS	?=				\
			$(strip						\
			  PREFIX=$(PREFIX) DESTDIR=$(DESTDIR)		\
			  $(if $(USE_ALTERNATIVE),			\
			    ALTERNATIVE_WRKDIR=$(DESTDIR)$(PREFIX)/src))

# $(warning PORTS_ENVS=$(PORTS_ENVS))
# $(warning PORTS_$(PORTS_GROUP_DEFAULT)_ENVS=$(PORTS_$(PORTS_GROUP_DEFAULT)_ENVS))


#  Listing below are extra envs will be appended into "port_ggg_xxx_env",
#  1. $(PORTS_ENVS)
#     1.1. remove $(PORTS_ggg_xxx_EXCLUDE_ENVS if existed
#  2. $(PORTS_ggg_ENVS)
#     2.1. remove $(PORTS_ggg_xxx_EXCLUDE_ENVS if existed
#  3. $(PORTS_xxx_EXTRA_ENVS)
#  4. $(PORTS_ggg_xxx_EXTRA_ENVS)
#
#  Listing below are extra envs will be removed during envs generate
#
#  1. remove TYPE_SUFFIX=% if existed in $(PORTS_ENVS)
#  2. remove ggg_SUFFIX=% if existed in $(PORTS_ggg_ENVS)
#
#  And finally, $(ggg_SUFFIX) will be always added into "port_ggg_xxx_env"

# $(call generate-port-env, group, port)
define generate-port-env
  ifneq ($(PORTS_ENVS),)
    port_$1_$2_env	+=						\
      $(if $(PORTS_$1_$2_EXCLUDE_ENVS),					\
        $(filter-out $(PORTS_$1_$2_EXCLUDE_ENVS),			\
          $(filter-out TYPE_SUFFIX=%,$(PORTS_ENVS))),			\
        $(filter-out TYPE_SUFFIX=%,$(PORTS_ENVS)))
  endif
  ifneq ($(PORTS_$1_ENVS),)
    port_$1_$2_env	+= 						\
      $(if $(PORTS_$1_$2_EXCLUDE_ENVS),					\
        $(filter-out $(PORTS_$1_$2_EXCLUDE_ENVS),			\
          $(filter-out $1_SUFFIX=%,$(PORTS_$1_ENVS))),			\
        $(filter-out $1_SUFFIX=%,$(PORTS_$1_ENVS)))
  endif
  ifneq ($(PORTS_$2_EXTRA_ENVS),)
    port_$1_$2_env	+= $(PORTS_$2_EXTRA_ENVS)
  endif
  ifneq ($(PORTS_$1_$2_EXTRA_ENVS),)
    port_$1_$2_env	+= $(PORTS_$1_$2_EXTRA_ENVS)
  endif
  port_$1_$2_env	+= TYPE_SUFFIX=$($1_SUFFIX)
endef

$(foreach g,$(groups_all),						\
  $(foreach p,$(groups_$g),						\
    $(eval								\
      $(call generate-port-env,$g,$p))))

#
# generate group@port.suffix target...
#

ports_target_all	= $(foreach g,$(groups_all),			\
			    $(foreach s,$(suffix_all_lists),		\
			      $(foreach p,$(groups_$g),$g$(AT)$p.$s)))

get-envs		= $(port_$(firstword $(call rm-at,		\
			    $1))_$(call extract-port,$(call rm-group,$1))_env)

quiet_cmd_generate-port-target	?= PORT    $(call transform-port-string,$@)
      cmd_generate-port-target	?= set -e;				\
	category=$(call get-category,$(call rm-group,$@));		\
	port=$(call extract-port,$(call rm-group,$@));			\
	suffix=$(call extract-suffix,$(call rm-group,$@));		\
	envs="$(call get-envs,$@)";					\
	make -C $(portdir)/$$category/$$port --no-print-directory $$envs $$suffix$(trash)

.PHONY: $(ports_target_all)
depends_exclude_targets	+= $(ports_target_all)

$(filter-out $(addprefix %.,$(suffix_special_all)),$(ports_target_all)):
	$(call cmd,generate-port-target)

$(filter $(addprefix %.,$(suffix_special_all)),$(ports_target_all)):
	@category=$(call get-category,$(call rm-group,$@));		\
	port=$(call extract-port,$(call rm-group,$@));			\
	suffix=$(call extract-suffix,$(call rm-group,$@));		\
	envs="$(call get-envs,$@)";					\
	make -C $(portdir)/$$category/$$port _INNERMKINCLUDE=no --no-print-directory $$envs $$suffix

#
# generate port.suffix target...
#

# $(call generate-all-ports-default-target, group@category/port, suffix)
define generate-all-ports-default-target
.PHONY: $(call get-port,$1).$2
depends_exclude_targets	+= $(call get-port,$1).$2
$(call get-port,$1).$2: $(call get-group,$1)@$(call get-port,$1).$2
endef

$(foreach p,$(ports_all_group_extra),					\
  $(foreach s,$(suffix_all_lists),					\
    $(eval								\
      $(call generate-all-ports-default-target,$p,$s))))

#
# generate ports catagory.suffix targets...
#

transform_category	= $(foreach p,$(categories_$1),			\
			    $(foreach g,$($p_groups),$g$(AT)$p))

# $(call generate-all-category-target, category, suffix)
define generate-all-categories-target
.PHONY: $1.$2
depends_exclude_targets	+= $1.$2
$1.$2: $(addsuffix .$2,$(call transform_category,$1))
endef

$(foreach c,$(categories_all),						\
  $(foreach s,$(suffix_all_lists),					\
    $(eval								\
      $(call generate-all-categories-target,$c,$s))))

#
# generate ports group.suffix targets...
#

# $(call generate-all-groups-target, group, suffix)
define generate-all-groups-target
.PHONY: $1.$2
depends_exclude_targets	+= $1.$2
$1.$2: $(addprefix $1$(AT),$(addsuffix .$2,$(groups_$1)))
endef

$(foreach g,$(groups_all),						\
  $(foreach s,$(suffix_all_lists),					\
    $(eval								\
      $(call generate-all-groups-target,$g,$s))))

#
# generate ports.suffix targets...
#

transform_all_group	= $(foreach p,$1,				\
			    $(call get-group,$p)@$(call get-port,$p))

# $(call generate-all-ports-target, suffix)
define generate-all-ports-target
.PHONY: ports.$1
depends_exclude_targets	+= ports.$1
ports.$1: $(addsuffix .$1,$(call transform_all_group,$(ports_all_group)))
endef

$(foreach s,$(suffix_all_lists),					\
  $(eval								\
    $(call generate-all-ports-target,$s)))

#
# finally, ports target...
#

.PHONY: ports
depends_exclude_targets	+= ports
ports: $(addsuffix .install,$(ports_all))

#
# Host utilities check...
#

USE_HOSTTOOLS		?= $(PORTS_GROUP_DEFAULT)
$(USE_HOSTTOOLS)_PREFIX	?= $(PREFIX)

# extract every group's PREFIX and DESTDIR

get-group-envs		= $(if $(PORTS_$1_ENVS),$(PORTS_$1_ENVS),$(PORTS_ENVS))
find-path 		= $(strip					\
			    $(if $(filter $2=%,$1),			\
			      $(patsubst $2=%,%,$(filter $2=%,$1)),))
define setup-path
$1_$2			:= $(call find-path,$(call get-group-envs,$1),$2)
endef

$(foreach g,$(groups_all),						\
  $(foreach t,PREFIX DESTDIR,						\
    $(eval $(call setup-path,$g,$t))))

# make sure every group has its own PREFIX and DESTDIR
env-name		= $(if $(PORTS_$1_ENVS),PORTS_$1_ENVS,PORTS_ENVS)
$(foreach g,$(groups_all),						\
  $(foreach t,PREFIX DESTDIR,						\
    $(if $($g_$t),,							\
      $(error Oops, there's no $t defined in your $(call env-name,$g))))) #'


ifneq ($(USE_HOSTTOOLS),)
  $(USE_HOSTTOOLS)_BASE	:= $($(USE_HOSTTOOLS)_DESTDIR)$($(USE_HOSTTOOLS)_PREFIX)

  ifneq ($(groups_$(USE_HOSTTOOLS)),)
    export PATH		:= $($(USE_HOSTTOOLS)_BASE)/bin:$(PATH)
  endif

# check pkg-config
  ifneq ($(filter pkg-config,$(groups_$(USE_HOSTTOOLS))),)
    export PKG_CONFIG	:= $($(USE_HOSTTOOLS)_BASE)/bin/pkg-config
  endif

# check cmake
  ifneq ($(filter cmake,$(groups_$(USE_HOSTTOOLS))),)
    export CMAKE_BIN	:= $($(USE_HOSTTOOLS)_BASE)/bin/cmake
  endif

# check others
# ...

endif # USE_HOSTTOOLS

#
#
#

tmpname			= tmp
tmpdir			= $(portdir)/Tools/$(tmpname)

echo			= $(shell which echo)
pecho			= $(tmpdir)/pecho.$(shell uname -s)

$(pecho): $(portdir)/Tools/pecho.c
	@mkdir -p $(@D)
	@cc -o $@ $^

distclean-tools:
	@rm -fr $(tmpdir)
distclean: distclean-tools

#
# info targets...
#

info_lists		+= ports debug pc

info:
	@$(echo) "Available info targets: info.($(info_lists))..."

#
# info.ports
#

info.ports.groups-header:
	@$(echo) -n "available PORTS_GROUP(PG): ";			\
	for g in $(groups_all); do 					\
	    if [ $$g = $(PORTS_GROUP_DEFAULT) ]; then			\
	        $(echo) -n "[*]$$g "; 					\
	    else							\
	        $(echo) -n "$$g "; 					\
	    fi; 							\
	done; $(echo);							\
	$(echo) "                   ------  ---------------"

# $(show-group-lists, group)
define show-group-lists
show_groups_$1:
	@flag=`if [ $(PORTS_GROUP_DEFAULT) = $1 ]; then			\
	  $(echo) '[*]$1: '; else $(echo) '$1: '; fi`;			\
	$(pecho) -n -o 27 -r "$$$$flag";				\
	$(echo) $(groups_$1)

info.ports.groups-lists: show_groups_$1
endef

$(foreach g,$(groups_all), 						\
  $(eval								\
    $(call show-group-lists,$g)))

info.ports.sep:
	@$(echo) "                     ----  -----------------------------------------------"

define show-port-lists
  show-port-list-$(subst @,-,$(subst /,-,$1)):
	@g=$(call get-group,$1);					\
	p=$(call rm-groups,$1);						\
	flag=`if [ "$$$$g" = "$(PORTS_GROUP_DEFAULT)" ]; then		\
	  $(echo) '*'; else $(echo) ' '; fi`;				\
	work=$(portdir)/$$$$p/work$($(call get-group,$1)_SUFFIX);	\
	status=`if [ ! -d $$$$work ]; then $(echo) ' ';			\
	  elif [ -f $$$$work/install._done.* ]; then $(echo) I;		\
	  elif [ -f $$$$work/package._done.* ]; then $(echo) K;		\
	  elif [ -f $$$$work/stage._done.* ]; then $(echo) S;		\
	  elif [ -f $$$$work/build._done.* ]; then $(echo) B;		\
	  elif [ -f $$$$work/configure._done.* ]; then $(echo) C;	\
	  elif [ -f $$$$work/patch._done.* ]; then $(echo) P;		\
	  elif [ -f $$$$work/extract._done.* ]; then $(echo) E;		\
	fi`;								\
	extra=$(filter $1,$(ports_all_group_extra));			\
	suffix=`if [ -z "$$$$extra" ]; then				\
	  $(echo) " [$$$$g$(AT)]"; fi`;					\
	args="--no-print-directory BEFOREPORTMK=yes";			\
	info=$$$$(make -C $(portdir)/$$$$p $$$$args package-info);	\
	printf "                     [%s%s]: %s%s \t\t %s\n" "$$$$flag" "$$$$status" "$$$$p" "$$$$suffix" "$$$$info"

  info.ports.ports: show-port-list-$(subst @,-,$(subst /,-,$1))
endef

$(foreach p,$(ports_all_group),						\
  $(eval								\
    $(call show-port-lists,$p)))

depends_exclude_targets	+= $(addsuffix .ports,i info)
$(addsuffix .ports,i info): $(pecho) $(addprefix info.ports.,groups-header groups-lists sep ports)

#
# info.pc ...
#

pkgs			= lib lib64
merge			= $(shell echo					\
			    $(addprefix $1,$(addsuffix $2,$3))		\
			      | sed -e 's/ /:/g')

PC_BASE			:= $($(PORTS_GROUP_DEFAULT)_DESTDIR)$($(PORTS_GROUP_DEFAULT)_PREFIX)

PKGCONFIG_ENVS			+=					\
	PKG_CONFIG_LIBDIR=$(call merge,$(PC_BASE)/,/pkgconfig,$(pkgs))	\
	PKG_CONFIG_SYSROOT_DIR=$($(PORTS_GROUP_DEFAULT)_DESTDIR)	\
	PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=yes				\
	PKG_CONFIG_ALLOW_SYSTEM_LIBS=yes

PKGCONFIG_ARGS			+= --silence-errors

ifneq ($(PKG_CONFIG),)
export PKGCONFIG_CMD	= $(PKGCONFIG_ENVS) $(PKG_CONFIG) $(PKGCONFIG_ARGS)
#export PKGCONFIG_LIST	= $(shell $(PKGCONFIG_CMD) --list-all |		\
#			    awk '{ print $$1; }')
endif

PA			?= --list-all | sort

depends_exclude_targets	+= $(addsuffix .pc,i info)
$(addsuffix .pc,i info):
ifneq ($(PKG_CONFIG),)
ifneq ($(PKGCONFIG_CMD),)
ifneq ($(wildcard $(PKG_CONFIG)),)
	@$(PKGCONFIG_CMD) $(PA)
else
	@echo "pkg-config was not built yet..."
endif
else
	@echo "pkg-config was not added in host tools yet..."
endif
else
	@echo "you didn't set USE_HOSTTOOLS yet..."
endif

#
# info.debug
#

info.debug.port:
	@$(echo) "PORTS_LISTS = $(PORTS_LISTS)"
	@$(echo) "ports_all_raw = $(ports_all_raw)"
	@$(echo) "ports_all = $(ports_all)"

info.debug.category:
	@$(echo) "categories_all = $(categories_all)"

define show-categories-all
show-categories-$1:
	@echo "categories_$1 = $(categories_$1)"
info.debug.category-all: show-categories-$1
endef
$(foreach c,$(categories_all),$(eval $(call show-categories-all,$c)))

define show-port-categories
show-$1-categories:
	@echo "$1_categories = $($1_categories)"
info.debug.port-categories: show-$1-categories
endef
$(foreach p,$(ports_all),$(eval $(call show-port-categories,$p)))

info.debug.group:
	@$(echo) "PORTS_GROUP_DEFAULT = $(PORTS_GROUP_DEFAULT)"
	@$(echo) "groups_all = $(groups_all)"
	@$(echo) "ports_all_group = $(ports_all_group)"
	@$(echo) "ports_all_group_extra = $(ports_all_group_extra)"

define show-groups-all
show-groups-$1:
	@echo "groups_$1 = $(groups_$1)"
info.debug.group-all: show-groups-$1
endef
$(foreach g,$(groups_all),$(eval $(call show-groups-all,$g)))

define show-groups-suffix
show-groups-suffix-$1:
	@echo "$1_SUFFIX = $($1_SUFFIX)"
info.debug.group-suffix: show-groups-suffix-$1
endef
$(foreach g,$(groups_all),$(eval $(call show-groups-suffix,$g)))

define show-port-groups
show-$1-groups:
	@echo "$1_groups = $($1_groups)"
info.debug.port-groups: show-$1-groups
endef
$(foreach p,$(ports_all),$(eval $(call show-port-groups,$p)))

info.debug.targets:
	@$(echo) "depends_exclude_targets = $(depends_exclude_targets)"
ifneq ($(USE_HOSTTOOLS),)
	@$(echo) "-------------------------------------------------"
	@$(echo) "USE_HOSTTOOLS = $(USE_HOSTTOOLS)"
	@$(echo) "$(PORTS_GROUP_DEFAULT)_PREFIX = $($(PORTS_GROUP_DEFAULT)_PREFIX)"
	@$(echo) "$(PORTS_GROUP_DEFAULT)_DESTDIR = $($(PORTS_GROUP_DEFAULT)_DESTDIR)"
	@$(echo) "$(USE_HOSTTOOLS)_PREFIX = $($(USE_HOSTTOOLS)_PREFIX)"
	@$(echo) "$(USE_HOSTTOOLS)_DESTDIR = $($(USE_HOSTTOOLS)_DESTDIR)"
	@$(echo) "PATH = $(PATH)"
	@$(echo) "PC_BASE = $(call merge,$(PC_BASE)/,/pkgconfig,$(pkgs))"
	@$(echo) "PKG_CONFIG = $(PKG_CONFIG)"
	@$(echo) "pkg-config = $(shell which pkg-config)"
endif

debug_targets		= sep1 port					\
			  sep2 category sep3 category-all sep4 port-categories \
			  sep5 group sep6 group-all sep7		\
			       group-suffix sep8 port-groups		\
			  sep9 targets					\
			  sep-end
double_line		= sep1 sep2 sep5 sep9 sep-end

$(addprefix info.debug.,$(filter sep%,$(debug_targets))):
	@sep=$(findstring $(patsubst info.debug.%,%,$@),$(double_line));\
	if [ ! -z "$$sep" ]; then					\
	    $(echo) "=================================================";\
	else								\
	    $(echo) "-------------------------------------------------";\
	fi

depends_exclude_targets	+= $(addsuffix .debug,i info)
$(addsuffix .debug,i info): $(addprefix info.debug.,$(debug_targets))
