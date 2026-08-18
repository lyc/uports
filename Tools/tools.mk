#
# tools.mk
#

# $(call subdirectory,makefile)
subdirectory		= $(patsubst %/$1,%,				\
			    $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))

portdir			:= $(abspath $(call subdirectory,tools.mk)/..)
feeds			:= $(abspath $(FEEDS))

include $(portdir)/Mk/linux.debug.mk
include $(portdir)/Tools/group.mk
ifneq ($(wildcard $(feeds)/group.mk),)
include $(feeds)/group.mk
endif

# default target ...
all:

#
# global lists ...
#
#   feeds_lists:
#   ports_lists:
#
#   ports_all_raw_lists:
#   categories_all_lists:
#   suffix_all_lists:
#

# Discover built-in and feed definitions in one make shell expansion. Keep
# each find traversal separate so existing filesystem order remains unchanged.
generate-ports-command	= find . -mindepth 2 -maxdepth 2 -type d	\
			    | sed -e '/^\.\/Mk.*/d'			\
			          -e '/^\.\/distfiles.*/d'		\
			          -e '/^\.\/packages.*/d'		\
			          -e '/^\.\/Templates.*/d'		\
			          -e '/^\.\/Tools.*/d'			\
			          -e '/^\.\/\.git.*/d'

ports_discovery_raw	:= $(shell					\
			     (cd "$(portdir)" 2>/dev/null &&		\
			       $(generate-ports-command)			\
			         | sed -e 's|^\./|uports@|');		\
			     $(if $(feeds),				\
			       (cd "$(feeds)" 2>/dev/null &&		\
			         $(generate-ports-command)		\
			           | sed -e 's|^\./|feeds@|')))

ports_discovered_raw	:= $(patsubst uports@%,%,			\
			     $(filter uports@%,$(ports_discovery_raw)))
feeds_discovered_raw	:= $(patsubst feeds@%,%,			\
			     $(filter feeds@%,$(ports_discovery_raw)))

#$(call check-if-empty-folder, folder, list)
check-if-empty-folder	= $(foreach p,$2,				\
			    $(if $(wildcard $1/$p/Makefile),$p))

# find all port package inside $(feeds) folder, if provided...
feeds_lists		:= $(strip					\
			     $(if $(feeds),				\
			       $(call check-if-empty-folder,$(feeds),	\
			         $(filter-out $(ignore_lists),		\
			           $(feeds_discovered_raw)))))

# find all built-in port packages, then apply feed override precedence...
ports_discovered_lists	:= $(call check-if-empty-folder,$(portdir),	\
			     $(filter-out $(default_ignore_lists),	\
			       $(ports_discovered_raw)))

ports_lists		:= $(filter-out $(feeds_lists),$(ports_discovered_lists))

ports_all_raw_lists	:= $(ports_lists) $(feeds_lists)

categories_all_lists	:=						\
	accessibility archivers astro audio benchmarks biology cad	\
	comms converters databases deskutils devel dns docs editors	\
	elisp emulators ftp games geography graphics hamradio haskell	\
	irc java lang linux lisp mail math mbone misc multimedia net	\
	net-im net-mgmt net-p2p net-vpn news parallel pear perl5 plan9	\
	ports-mgmt portuguese print python ruby rubygems scheme science	\
	security shells sysutils tcl textproc tk wayland windowmaker	\
	www x11 x11-clocks x11-drivers x11-fm x11-fonts x11-servers	\
	x11-themes x11-toolkits x11-wm xfce zope base

suffix_special_all	:= package-source makesum
suffix_all_lists	:=						\
	fetch extract patch configure build stage package install	\
	clean distclean deinstall uninstall rebuild restage reinstall	\
	generate-plist $(suffix_special_all)

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
get-category		= $(port_$(call extract-port,$1)_category)

# $(call rm-port, [[group@]group@]category/port)
rm-port			= $(firstword $(call rm-slash,$1))

# $(call rm-category, [[group@]group@]category)
rm-category		= $(patsubst %$(lastword $(call rm-at,$1)),%,$1)

# $(call get-groups, [[group@]group@]category/port)
get-groups		= $(call rm-category,$(call rm-port,$1))

# $(call rm-groups, [[group@]group@]category/port)
rm-groups		= $(patsubst $(call get-groups,$1)%,%,$1)

# $(call set-special-groups, group_lists, ports_list)
set-special-groups	= $(strip					\
			    $(foreach g,$1,				\
			      $(foreach p,$($(g)_lists),		\
			        $(if $(filter $p,$2),$(g)@$(p))))	\
			    $(filter-out				\
			      $(sort $(foreach g,$1,$($(g)_lists))),$2))

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

# $(call transform-port, port.suffix)
transform-port		= $(call get-category,$1)$(SLASH)$(call extract-port,$1)

# $(call get-dir, category/port)
get-dir			= $(port_$(call get-port,$1)_root)

#
# port ...
#
#   PORTS_LISTS:
#   ports_all_raw:
#   ports_all:
#

ifneq ($(PORTS_LISTS),)
ports_all_raw		:= $(foreach p,					\
			    $(PORTS_LISTS),$(call purify_ports_raw,$p))
endif

ports_all_raw_unknown	:= $(filter-out $(ports_all_raw_lists),$(ports_all_raw))
ifneq ($(ports_all_raw_unknown),)
$(error assign unknown packages: $(ports_all_raw_unknown))
endif

ifeq ($(ports_all_raw),)
ports_all_raw		:= $(ports_all_raw_lists)
endif

ports_all		:= $(filter-out $(categories_all_lists),		\
			    $(call rm-slash,$(ports_all_raw)))

ports_all_ambiguous	:= $(strip					\
			    $(foreach p,$(sort $(ports_all)),		\
			      $(if $(word 2,$(filter $p,$(ports_all))),$p)))
ifneq ($(ports_all_ambiguous),)
$(error ambiguous short port names: $(ports_all_ambiguous))
endif

#
# category ...
#
#   categories_all:
#   categories_xxx:
#   xxx_categories:
#

categories_all		:= $(sort					\
			    $(filter-out $(ports_all),			\
			      $(call rm-slash,$(ports_all_raw))))

# $(call generate-categories-list, category)
define generate-categories-lists
  categories_$1		:= $(filter-out $(categories_all_lists),		\
			    $(call rm-slash,				\
			      $(filter $1/%,$(ports_all_raw))))
endef

$(foreach c,$(categories_all),						\
  $(eval								\
    $(call generate-categories-lists,$c)))

# $(call generate-port-categories-list, category)
define generate-port-categories-lists
  $1_categories		:= $(patsubst %/$1,%,$(filter %/$1,$(ports_all_raw)))
endef

$(foreach c,$(ports_all),						\
  $(eval								\
    $(call generate-port-categories-lists,$c)))

# $(call generate-port-record, category/port)
define generate-port-record
  port_$(call get-port,$1)_category := $(firstword $(call rm-slash,$1))
  port_$(call get-port,$1)_origin := $1
  port_$(call get-port,$1)_root := $(if $(filter $(feeds_lists),$1),$(feeds),$(portdir))
endef

$(foreach p,$(ports_all_raw_lists),					\
  $(eval								\
    $(call generate-port-record,$p)))

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

ports_all_group		:= $(strip					\
			    $(foreach p,				\
			      $(if $(PORTS_LISTS),$(PORTS_LISTS),	\
			        $(call set-special-groups,		\
			          $(special_groups_all),$(ports_all_raw))),\
			      $(call complete-group-default,		\
			        $p,$(PORTS_GROUP_DEFAULT))))

groups_all		:= $(sort					\
			    $(foreach p,$(ports_all_group),		\
			      $(call rm-at,$(call get-groups,$p))))

# $(warning groups_all=$(groups_all))

# $(call generate-groups-list, group)
define generate-groups-lists
  groups_$1		:= $(foreach p,$(filter $1$(AT)%,		\
			    $(ports_all_group)),$(lastword $(call rm-slash,$p)))
endef

$(foreach g,$(groups_all),						\
  $(eval								\
    $(call generate-groups-lists,$g)))

# $(call generate-port-groups-lists, port)
define generate-port-groups-lists
  $1_groups		:= $(foreach g,$(filter %/$1,			\
			    $(ports_all_group)),$(subst $(AT),,$(call get-groups,$g)))
endef

$(foreach p,$(ports_all),						\
  $(eval								\
    $(call generate-port-groups-lists,$p)))

ports_all_group_extra	:= $(sort					\
			    $(foreach g,$(ports_all_group),		\
			      $(call filter-out-group-extra,$g)))

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

ENVS_OPTS		= USE_GLOBALBASE DISTDIR_SITE PACKAGES_SITE SCMDIR_SITE

$(if $(PORTS_ENVS),,							\
  $(foreach v,$(ENVS_OPTS),						\
    $(eval								\
      $(if $($v),							\
        $(call add-ports-env,$v)))))

PORTS_host_ENVS		:= $(strip					\
			     PORTSDIR=$(portdir)			\
			     PREFIX=$(PREFIX) DESTDIR=$(DESTDIR))
PORTS_bs_ENVS		:= $(PORTS_host_ENVS) FORCE_REBUILD=yes

ifneq ($(PORTS_GROUP_DEFAULT),host)
PORTS_$(PORTS_GROUP_DEFAULT)_ENVS	+=				\
			   $(strip					\
			     PORTSDIR=$(portdir)			\
			     PREFIX=$(PREFIX)				\
			     DESTDIR=$(DESTDIR)/$(PORTS_GROUP_DEFAULT)	\
			     $(if $(USE_ALTERNATIVE),			\
			       USE_ALTERNATIVE=$(USE_ALTERNATIVE),	\
			       USE_ALTERNATIVE=yes)			\
			     $(if $(ALTERNATIVE_WRKDIR),		\
			       ALTERNATIVE_WRKDIR=$(ALTERNATIVE_WRKDIR),\
			       ALTERNATIVE_WRKDIR=$(DESTDIR)/$(PORTS_GROUP_DEFAULT)/src))
else
PORTS_host_ENVS		+= ALTERNATIVE=yes				\
			   ALTERNATIVE_WRKDIR=$(DESTDIR)/src
endif

# $(warning PORTS_ENVS=$(PORTS_ENVS))
# $(warning PORTS_host_ENVS=$(PORTS_host_ENVS))
# $(warning PORTS_bs_ENVS=$(PORTS_bs_ENVS))
# ifneq ($(PORTS_GROUP_DEFAULT),host)
# $(warning PORTS_$(PORTS_GROUP_DEFAULT)_ENVS=$(PORTS_$(PORTS_GROUP_DEFAULT)_ENVS))
# endif

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

# $(call compose-port-env, group, port)
compose-port-env	= $(strip					\
			    $(filter-out $(PORTS_$1_$2_EXCLUDE_ENVS),	\
			      $(filter-out TYPE_SUFFIX=%,$(PORTS_ENVS)))	\
			    $(filter-out $(PORTS_$1_$2_EXCLUDE_ENVS),	\
			      $(filter-out $1_SUFFIX=%,$(PORTS_$1_ENVS)))	\
			    $(PORTS_$2_EXTRA_ENVS)			\
			    $(PORTS_$1_$2_EXTRA_ENVS)			\
			    TYPE_SUFFIX=$($1_SUFFIX))

# Keep the compatibility variable while avoiding generated conditional
# makefile fragments for every build instance.
define generate-port-env
  port_$1_$2_env	:= $(call compose-port-env,$1,$2)
endef

$(foreach g,$(groups_all),						\
  $(foreach p,$(groups_$g),						\
    $(eval								\
      $(call generate-port-env,$g,$p))))

#
# normalized build-instance lookup records...
#

instance-default-variant := default

# $(call normalize-instance-variant, [variant])
normalize-instance-variant = $(or $(strip $1),$(instance-default-variant))

# $(call instance-key, group, port, [variant])
# Preserve the historical default key while reserving a collision-free suffix
# for future explicitly selected variants.
instance-key		= $(strip $1)_$(strip $2)$(if $(filter-out $(instance-default-variant),$(call normalize-instance-variant,$3)),_$(call normalize-instance-variant,$3))

# $(call generate-instance-record, group@category/port)
define generate-instance-record
  instance_$(call instance-key,$(call get-group,$1),$(call get-port,$1),$(instance-default-variant))_group := $(call get-group,$1)
  instance_$(call instance-key,$(call get-group,$1),$(call get-port,$1),$(instance-default-variant))_port := $(call get-port,$1)
  instance_$(call instance-key,$(call get-group,$1),$(call get-port,$1),$(instance-default-variant))_variant := $(instance-default-variant)
  instance_$(call instance-key,$(call get-group,$1),$(call get-port,$1),$(instance-default-variant))_category := $(port_$(call get-port,$1)_category)
  instance_$(call instance-key,$(call get-group,$1),$(call get-port,$1),$(instance-default-variant))_origin := $(port_$(call get-port,$1)_origin)
  instance_$(call instance-key,$(call get-group,$1),$(call get-port,$1),$(instance-default-variant))_root := $(port_$(call get-port,$1)_root)
  instance_$(call instance-key,$(call get-group,$1),$(call get-port,$1),$(instance-default-variant))_env := $(port_$(call get-group,$1)_$(call get-port,$1)_env)
endef

$(foreach p,$(ports_all_group),					\
  $(eval								\
    $(call generate-instance-record,$p)))

# $(call target-instance-key, group@port.suffix)
target-instance-key	= $(call instance-key,				\
			    $(strip $(firstword $(call rm-at,$1))),	\
			    $(strip $(call extract-port,		\
			      $(call rm-group,$1))))

# $(call instance-field, instance-key, field)
instance-field		= $(instance_$(strip $1)_$(strip $2))

# $(call target-instance-field, group@port.suffix, field)
target-instance-field	= $(call instance-field,			\
			    $(strip $(call target-instance-key,$1)),	\
			    $(strip $2))

# $(call target-alias-port, port.suffix)
target-alias-port	= $(call extract-port,$(call rm-group,$1))

# $(call target-alias-instance, port.suffix)
target-alias-instance	= $(firstword $(filter				\
			    %/$(call target-alias-port,$1),		\
			    $(ports_all_group_extra)))

#
# generate group@port.suffix target...
#

ports_target_all	:= $(foreach g,$(groups_all),			\
			    $(foreach s,$(suffix_all_lists),		\
			      $(foreach p,$(groups_$g),$g$(AT)$p.$s)))
ports_alias_target_all	:= $(foreach p,$(ports_all_group_extra),		\
			    $(foreach s,$(suffix_all_lists),		\
			      $(call get-port,$p).$s))
ports_category_target_all := $(foreach c,$(categories_all),		\
			    $(foreach s,$(suffix_all_lists),$c.$s))
ports_group_target_all	:= $(foreach g,$(groups_all),			\
			    $(foreach s,$(suffix_all_lists),$g.$s))
ports_global_target_all	:= $(addprefix ports.,$(suffix_all_lists))
ports_aggregate_target_all := $(ports_category_target_all)		\
			      $(ports_group_target_all)			\
			      $(ports_global_target_all)
ports_aggregate_target_unique := $(sort $(ports_aggregate_target_all))

# $(call resolve-port-target, [group@]port.suffix)
resolve-port-target	= $(strip					\
			    $(if $(filter $1,$(ports_target_all)),$1,	\
			      $(if $(filter $1,$(ports_alias_target_all)),	\
			        $(call get-group,				\
			          $(call target-alias-instance,$1))$(AT)	\
			        $(call target-alias-port,$1)$(suffix $1))))
resolved-port-target	= $(call resolve-port-target,$@)

# $(call aggregate-target-name, aggregate.suffix)
aggregate-target-name	= $(call extract-port,$1)

# $(call aggregate-target-suffix, aggregate.suffix)
aggregate-target-suffix	= $(call extract-suffix,$1)

# $(call aggregate-category-prerequisites, category.suffix)
aggregate-category-prerequisites = $(foreach c,			\
			    $(filter $(call aggregate-target-name,$1),	\
			      $(categories_all)),				\
			    $(addsuffix					\
			      .$(call aggregate-target-suffix,$1),	\
			      $(call transform_category,$c)))

# $(call aggregate-group-prerequisites, group.suffix)
aggregate-group-prerequisites = $(if				\
			    $(filter $(call aggregate-target-name,$1),	\
			      $(groups_all)),				\
			    $(addprefix					\
			      $(call aggregate-target-name,$1)$(AT),	\
			      $(addsuffix					\
			        .$(call aggregate-target-suffix,$1),	\
			        $(groups_$(call aggregate-target-name,$1)))))

# $(call aggregate-global-prerequisites, ports.suffix)
aggregate-global-prerequisites = $(if				\
			    $(filter ports,				\
			      $(call aggregate-target-name,$1)),		\
			    $(addsuffix					\
			      .$(call aggregate-target-suffix,$1),	\
			      $(call transform_all_group,		\
			        $(ports_all_group))))

# $(call aggregate-prerequisites, aggregate.suffix)
aggregate-prerequisites = $(strip					\
			    $(call aggregate-category-prerequisites,$1)	\
			    $(call aggregate-group-prerequisites,$1)	\
			    $(call aggregate-global-prerequisites,$1))

get-envs		= $(call target-instance-field,$1,env)

quiet_cmd_generate-port-target	?= PORT    $(call target-instance-field,$(resolved-port-target),group)$(AT)$(call target-instance-field,$(resolved-port-target),origin) $(call extract-suffix,$(call rm-group,$(resolved-port-target)))
      cmd_generate-port-target	?= set -e;				\
	dir=$(call target-instance-field,$(resolved-port-target),root);	\
	category=$(call target-instance-field,				\
	  $(resolved-port-target),category);				\
	port=$(call target-instance-field,$(resolved-port-target),port);	\
	suffix=$(call extract-suffix,				\
	  $(call rm-group,$(resolved-port-target)));			\
	envs="$(call get-envs,$(resolved-port-target))";			\
	make -C $$dir/$$category/$$port --no-print-directory $$envs $$suffix$(trash)

depends_exclude_targets	+= $(ports_target_all) $(ports_alias_target_all) \
			    $(ports_aggregate_target_all)

.PHONY: uports-force
uports-force:

# Validate pattern-matched lifecycle targets before dispatch. Shared patterns
# must not turn unknown canonical or short aliases into accepted targets.
validate-port-target	= $(if $(resolved-port-target),,		\
			    $(error Unknown uports lifecycle target: $@))

.SECONDEXPANSION:

# Aggregate targets are explicit so their canonical prerequisites can resolve
# through the shared lifecycle patterns without implicit-rule recursion.
$(ports_aggregate_target_unique): %: $$(call aggregate-prerequisites,$$@) uports-force ;

# $(call generate-port-lifecycle-pattern, suffix)
define generate-port-lifecycle-pattern
%.$1: uports-force
	$$(validate-port-target)
	$$(call cmd,generate-port-target)
endef

$(foreach s,$(filter-out $(suffix_special_all),$(suffix_all_lists)),	\
  $(eval								\
    $(call generate-port-lifecycle-pattern,$s)))

# $(call generate-port-special-pattern, suffix)
define generate-port-special-pattern
%.$1: uports-force
	$$(validate-port-target)
	@dir=$$(call target-instance-field,$$(resolved-port-target),root); \
	category=$$(call target-instance-field,			\
	  $$(resolved-port-target),category);				\
	port=$$(call target-instance-field,$$(resolved-port-target),port); \
	suffix=$$(call extract-suffix,				\
	  $$(call rm-group,$$(resolved-port-target)));			\
	envs="$$(call get-envs,$$(resolved-port-target))";		\
	make -C $$$$dir/$$$$category/$$$$port _INNERMKINCLUDE=no	\
	  --no-print-directory $$$$envs $$$$suffix
endef

$(foreach s,$(suffix_special_all),					\
  $(eval								\
    $(call generate-port-special-pattern,$s)))

transform_category	= $(foreach p,$(categories_$1),			\
			    $(foreach g,$($p_groups),$g$(AT)$p))

transform_all_group	= $(foreach p,$1,				\
			    $(call get-group,$p)@$(call get-port,$p))

#
# finally, ports target...
#

.PHONY: ports
depends_exclude_targets	+= ports
ports: $(addsuffix .install,$(ports_all))

#
# planner statistics...
#

planner_collections	:= $(sort $(portdir) $(if $(feeds),$(feeds)))
planner_discovered_definitions := $(ports_discovered_lists) $(feeds_lists)
planner_alias_targets	:= $(ports_alias_target_all)
planner_category_targets:= $(ports_category_target_all)
planner_group_targets	:= $(ports_group_target_all)
planner_global_targets	:= $(ports_global_target_all) ports
planner_override_origins:= $(sort $(filter $(ports_lists),$(feeds_lists)))
planner_diagnostic_targets :=						\
	info i.ports info.ports i.pc info.pc i.debug info.debug planner-stats

.PHONY: planner-stats
depends_exclude_targets	+= planner-stats
planner-stats:
	@printf '%s\n'							\
	  'collections=$(words $(planner_collections))'			\
	  'discovered_definitions=$(words $(planner_discovered_definitions))' \
	  'resolved_logical_ports=$(words $(ports_all_raw_lists))'	\
	  'selected_ports=$(words $(ports_all_raw))'			\
	  'groups=$(words $(groups_all))'				\
	  'categories=$(words $(categories_all))'			\
	  'build_instances=$(words $(ports_all_group))'			\
	  'selected_variants=0'					\
	  'lifecycle_suffixes=$(words $(suffix_all_lists))'		\
	  'canonical_targets=$(words $(ports_target_all))'		\
	  'alias_targets=$(words $(planner_alias_targets))'		\
	  'aggregate_targets=$(words $(planner_category_targets)		\
	    $(planner_group_targets) $(planner_global_targets))'		\
	  'diagnostic_targets=$(words $(planner_diagnostic_targets))'

#
# Host utilities check...
#

USE_HOSTTOOLS		?= host
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

# check ninja
  ifneq ($(filter ninja,$(groups_$(USE_HOSTTOOLS))),)
    export NINJA_BIN	:= $($(USE_HOSTTOOLS)_BASE)/bin/ninja
  endif

# check meson
  ifneq ($(filter meson,$(groups_$(USE_HOSTTOOLS))),)
    export MESON_BIN	:= $($(USE_HOSTTOOLS)_BASE)/bin/meson
  endif

# check others
# ...

endif # USE_HOSTTOOLS

#
#
#

tmpname			= tmp
tmpdir			= $(portdir)/Tools/$(tmpname)

echo			:= echo
pecho			:= $(tmpdir)/pecho
port_info_awk		:= $(portdir)/Tools/port-info.awk
info_ports_opsys	= $(shell uname -s | tr '[:upper:]' '[:lower:]')
info_ports_arch		= $(shell uname -m)
info_ports_cols		= $(or $(COLUMNS),$(shell (stty size < /dev/tty)	\
			    2>/dev/null | awk '{print $$2}'),		\
			    $(shell tput cols 2>/dev/null || echo 80))

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
	@cols=$(info_ports_cols);					\
	[ "$$cols" -gt 32 ] 2>/dev/null || cols=80;			\
	header_cols=$$((cols - 15));					\
	[ "$$header_cols" -gt 32 ] 2>/dev/null || header_cols=$$cols;	\
	{								\
	  for g in $(groups_all); do 					\
	    if [ $$g = $(PORTS_GROUP_DEFAULT) ]; then			\
	      printf '%s\n' "[*]$$g";					\
	    else							\
	      printf '%s\n' "$$g";					\
	    fi;								\
	  done;								\
	} | awk -v cols="$$header_cols" -v label="available PORTS_GROUP(PG): " ' \
	  BEGIN {							\
	    prefix = label;						\
	    cont = sprintf("%*s", length(label), "");			\
	    line = prefix;						\
	  }								\
	  {								\
	    sep = (line == prefix || line == cont) ? "" : " ";		\
	    if (length(line sep $$0) > cols && line != prefix && line != cont) { \
	      print line;						\
	      line = cont $$0;						\
	    } else {							\
	      line = line sep $$0;					\
	    }								\
	  }								\
	  END { print line }';						\
	cols=$(info_ports_cols);					\
	[ "$$cols" -gt 21 ] 2>/dev/null || cols=80;			\
	cols=$$((cols - 15));						\
	[ "$$cols" -gt 21 ] 2>/dev/null || cols=80;			\
	printf "%21s" "";						\
	printf "%*s\n" "$$((cols - 21))" "" | tr ' ' '-'

# $(show-group-lists, group)
define show-group-lists
show_groups_$1:
	@flag=`if [ $(PORTS_GROUP_DEFAULT) = $1 ]; then			\
	  $(echo) '[*]$1: '; else $(echo) '$1: '; fi`;			\
	cols=$(info_ports_cols);					\
	[ "$$$$cols" -gt 32 ] 2>/dev/null || cols=80;			\
	group_cols=$$$$((cols - 15));					\
	[ "$$$$group_cols" -gt 32 ] 2>/dev/null || group_cols=$$$$cols;	\
	printf '%s\n' "$(groups_$1)" | awk -v cols="$$$$group_cols"	\
	  -v label="$$$$flag" '					\
	    BEGIN {							\
	      label_width = (cols < 60) ? length(label) : 27;		\
	      prefix = sprintf("%*s", label_width, label);		\
	      cont = sprintf("%*s", label_width, "");			\
	      line = prefix;						\
	    }								\
	    {								\
	      for (i = 1; i <= NF; i++) {				\
	        sep = (line == prefix || line == cont) ? "" : " ";	\
	        if (length(line sep $$$$i) > cols && line != prefix && line != cont) { \
	          print line;						\
	          line = cont $$$$i;					\
	        } else {						\
	          line = line sep $$$$i;				\
	        }							\
	      }								\
	    }								\
	    END { print line }'

info.ports.groups-lists: show_groups_$1
endef

$(foreach g,$(groups_all), 						\
  $(eval								\
    $(call show-group-lists,$g)))

info.ports.sep:
	@cols=$(info_ports_cols);					\
	[ "$$cols" -gt 21 ] 2>/dev/null || cols=80;			\
	cols=$$((cols - 15));						\
	[ "$$cols" -gt 21 ] 2>/dev/null || cols=80;			\
	printf "%21s" "";						\
	printf "%*s\n" "$$((cols - 21))" "" | tr ' ' '-'

info_ports_status = $(strip						\
  $(if $(wildcard $1/install._done.*),I,				\
    $(if $(wildcard $1/package._done.*),K,			\
      $(if $(wildcard $1/stage._done.*),S,			\
        $(if $(wildcard $1/build._done.*),B,			\
          $(if $(wildcard $1/configure._done.*),C,		\
            $(if $(wildcard $1/patch._done.*),P,		\
              $(if $(wildcard $1/extract._done.*),E,))))))))

info_ports_instance_key = $(call instance-key,$(call get-group,$1),	\
			    $(call get-port,$1))
info_ports_work = $(call instance-field,$(call info_ports_instance_key,$1),root)/$(call instance-field,$(call info_ports_instance_key,$1),origin)/work$($(call get-group,$1)_SUFFIX)

info_ports_record = printf '%s\t%s\t%s\t%s\t%s\t%s\n'		\
  '$(call instance-field,$(call instance-key,$(call get-group,$1),$(call get-port,$1)),group)' \
  '$(call instance-field,$(call instance-key,$(call get-group,$1),$(call get-port,$1)),origin)' \
  '$(call instance-field,$(call instance-key,$(call get-group,$1),$(call get-port,$1)),root)' \
  '$(call info_ports_status,$(call info_ports_work,$1))'		\
  '$(if $(filter $(call get-group,$1),$(PORTS_GROUP_DEFAULT)),*, )' \
  '$(if $(filter $1,$(ports_all_group_extra)),, [$(call get-group,$1)$(AT)])';

info.ports.ports:
	@{ $(foreach p,$(ports_all_group),$(call info_ports_record,$p)) } | \
	  awk -F '	' -v mode=info-ports -v portdir="$(portdir)"	\
	    -v opsys="$(info_ports_opsys)" -v arch="$(info_ports_arch)"	\
	    -f "$(port_info_awk)"

depends_exclude_targets	+= $(addsuffix .ports,i info)
$(addsuffix .ports,i info): $(pecho) $(addprefix info.ports.,groups-header groups-lists sep ports)

#
# info.pc ...
#

pkgs			= lib lib64
empty			:=
space			:= $(empty) $(empty)
merge			= $(subst $(space),:,$(strip			\
			    $(addprefix $1,$(addsuffix $2,$3))))

PC_BASE			:= $($(PORTS_GROUP_DEFAULT)_DESTDIR)$($(PORTS_GROUP_DEFAULT)_PREFIX)

export PKG_CONFIG_LIBDIR:= $(call merge,$(PC_BASE)/,/pkgconfig,$(pkgs))

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

info.debug.plan:
	@printf '%s\n'							\
	  "collections = $(words $(planner_collections))"		\
	  "discovered_definitions = $(words $(planner_discovered_definitions))" \
	  "resolved_logical_ports = $(words $(ports_all_raw_lists))"	\
	  "selected_ports = $(words $(ports_all_raw))"			\
	  "groups = $(words $(groups_all))"				\
	  "categories = $(words $(categories_all))"			\
	  "build_instances = $(words $(ports_all_group))"		\
	  "implicit_default_variants = $(words $(ports_all_group))"	\
	  "selected_nondefault_variants = 0"

info.debug.origins:
	@$(echo) "collection.builtin = $(portdir)"
	@$(echo) "collection.feed = $(if $(feeds),$(feeds),none)"
	@$(echo) "feed_overrides = $(if $(planner_override_origins),$(planner_override_origins),none)"
	@$(foreach p,$(ports_all_raw),					\
	  echo "origin.$(call get-port,$p) = $(call get-dir,$p)/$p";)

info.debug.instances:
	@$(foreach p,$(ports_all_group),				\
	  echo "instance.$(call instance-key,$(call get-group,$p),$(call get-port,$p)) = group=$(call get-group,$p) origin=$(call instance-field,$(call instance-key,$(call get-group,$p),$(call get-port,$p)),origin) variant=$(call instance-field,$(call instance-key,$(call get-group,$p),$(call get-port,$p)),variant) root=$(call instance-field,$(call instance-key,$(call get-group,$p),$(call get-port,$p)),root)";)

info.debug.instance-envs:
	@$(foreach p,$(ports_all_group),				\
	  echo "instance.$(call instance-key,$(call get-group,$p),$(call get-port,$p)).env = $(call instance-field,$(call instance-key,$(call get-group,$p),$(call get-port,$p)),env)";)

info.debug.variants:
	@$(echo) "default_variant = $(instance-default-variant)"
	@$(echo) "implicit_default_instances = $(words $(ports_all_group))"
	@$(echo) "selected_nondefault_variants = 0"
	@$(echo) "unselected_variants_generate_state = no"

info.debug.port:
	@$(echo) "feeds_lists = $(feeds_lists)"
	@$(echo) "ports_lists = $(ports_lists)"
	@$(echo) "ports_all_raw_lists=$(ports_all_raw_lists)"
	@$(echo) "PORTS_LISTS = $(PORTS_LISTS)"
	@$(echo) "ports_all_raw = $(ports_all_raw)"
	@$(echo) "ports_all = $(ports_all)"

info.debug.category:
	@$(echo) "categories_all = $(categories_all)"

info.debug.category-all:
	@$(foreach c,$(categories_all),				\
	  echo "categories_$c = $(categories_$c)";)

show-categories-%:
	@echo "categories_$* = $(categories_$*)"

info.debug.port-categories:
	@$(foreach p,$(ports_all),					\
	  echo "$p_categories = $($p_categories)";)

show-%-categories:
	@echo "$*_categories = $($*_categories)"

info.debug.group:
	@$(echo) "special_groups_all = $(special_groups_all)"
	@$(echo) "PORTS_GROUP_DEFAULT = $(PORTS_GROUP_DEFAULT)"
	@$(echo) "groups_all = $(groups_all)"
	@$(echo) "ports_all_group = $(ports_all_group)"
	@$(echo) "ports_all_group_extra = $(ports_all_group_extra)"

info.debug.group-all:
	@$(foreach g,$(groups_all),					\
	  echo "groups_$g = $(groups_$g)";)

show-groups-%:
	@echo "groups_$* = $(groups_$*)"

info.debug.group-suffix:
	@$(foreach g,$(groups_all),					\
	  echo "$g_SUFFIX = $($g_SUFFIX)";)

show-groups-suffix-%:
	@echo "$*_SUFFIX = $($*_SUFFIX)"

info.debug.port-groups:
	@$(foreach p,$(ports_all),					\
	  echo "$p_groups = $($p_groups)";)

show-%-groups:
	@echo "$*_groups = $($*_groups)"

info.debug.targets:
	@$(echo) "lifecycle_suffixes = $(words $(suffix_all_lists))"
	@$(echo) "canonical_targets = $(words $(ports_target_all))"
	@$(echo) "alias_targets = $(words $(planner_alias_targets))"
	@$(echo) "aggregate_targets = $(words $(planner_category_targets) $(planner_group_targets) $(planner_global_targets))"
	@$(echo) "excluded_targets = $(words $(sort $(depends_exclude_targets)))"
	@$(echo) "ambiguous_short_ports = $(if $(ports_all_ambiguous),$(ports_all_ambiguous),none)"
	@$(echo) "target_validation = enabled"
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

info.debug.targets-all:
	@$(echo) "depends_exclude_targets = $(depends_exclude_targets)"

debug_targets		= sep1 plan sep2 origins sep3 instances sep4 variants \
			  sep5 port					\
			  sep6 category sep7 category-all sep8 port-categories \
			  sep9 group sep10 group-all sep11		\
			       group-suffix sep12 port-groups		\
			  sep13 targets					\
			  sep-end
double_line		= sep1 sep2 sep3 sep4 sep5 sep6 sep9 sep13 sep-end

$(addprefix info.debug.,$(filter sep%,$(debug_targets))):
	@sep=$(findstring $(patsubst info.debug.%,%,$@),$(double_line));\
	if [ ! -z "$$sep" ]; then					\
	    $(echo) "=================================================";\
	else								\
	    $(echo) "-------------------------------------------------";\
	fi

depends_exclude_targets	+= $(addsuffix .debug,i info)			\
			    info.debug.instance-envs info.debug.targets-all
$(addsuffix .debug,i info): $(addprefix info.debug.,$(debug_targets))
