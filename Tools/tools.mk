#
# tools.mk
#

# $(call subdirectory,makefile)
subdirectory		= $(patsubst %/$1,%,				\
			    $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))

portdir			:= $(abspath $(call subdirectory,tools.mk)/..)

include $(portdir)/Mk/linux.debug.mk

# default target ...
ports:

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

suffix_all_lists	=						\
	fetch extract patch configure build stage package install	\
	clean distclean deinstall uninstall

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

# $(call transform-port-string, port.suffix)
transform-port-string	= $(subst ., ,$(call get-category,$1)/$1)

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
# generate port_xxx_env variable...
#

#  Listing below are extra envs will be append into "port_xxx_env",
#  1. $(PORTS_ENVS)
#    1.1. Remove $(PORTS_xxx_EXCLUDE_ENVS) if existed
#  2. $(PORTS_xxx_EXTRA_ENVS)

# $(call generate-port-env, port)
define generate-port-env
  ifneq ($(PORTS_ENVS),)
    port_$1_env	+=							\
      $(if $(PORTS_$1_EXCLUDE_ENVS),					\
        $(filter-out $(PORTS_$1_EXCLUDE_ENVS),$(PORTS_ENVS)),		\
        $(PORTS_ENVS))
  endif
  ifneq ($(PORTS_$1_EXTRA_ENVS),)
    port_$1_env	+= $(PORTS_$1_EXTRA_ENVS)
  endif
endef

$(foreach p,$(ports_all),						\
  $(eval								\
    $(call generate-port-env,$p)))

#
# generate port.suffix target...
#

# $(call generate-all-port-target, suffix)
define generate-all-port-target
  ports_target_all	+= $(addsuffix .$1,$(ports_all))
endef

$(foreach s,$(suffix_all_lists),					\
  $(eval								\
    $(call generate-all-port-target,$s)))

quiet_cmd_generate-port-target	?= PORT    $(call transform-port-string,$@)
      cmd_generate-port-target	?= set -e;				\
	category=$(call get-category,$@);				\
	port=$(call extract-port,$@);					\
	suffix=$(call extract-suffix,$@);				\
	envs="$(port_$(call extract-port,$@)_env)";			\
	make -C $(portdir)/$$category/$$port --no-print-directory $$envs $$suffix$(trash)

.PHONY: $(ports_target_all)
depends_exclude_targets	+= $(ports_target_all)
$(ports_target_all):
	$(call cmd,generate-port-target)

#
# generate ports catagory.suffix targets...
#

# $(call generate-all-category-target, category, suffix)
define generate-all-categories-target
.PHONY: $1.$2
depends_exclude_targets	+= $1.$2
$1.$2: $(addsuffix .$2,$(categories_$1))
endef

$(foreach c,$(categories_all),						\
  $(foreach s,$(suffix_all_lists),					\
    $(eval								\
      $(call generate-all-categories-target,$c,$s))))

#
# generate ports.suffix targets...
#

# $(call generate-all-target, suffix)
define generate-all-ports-target
.PHONY: ports.$1
depends_exclude_targets	+= ports.$1
ports.$1: $(addsuffix .$1,$(ports_all))
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
#
#

echo			= $(shell which echo)

#
# info targets...
#

info_lists		+= ports debug

info:
	@$(echo) "Available info targets: info.($(info_lists))..."

#
# info.ports
#

info.ports.sep:
	@$(echo) "                     ----  ---------------"

info.ports.ports:
	@for p in $(sort $(ports_all_raw)); do				\
	    flag=' ';							\
	    work=$(portdir)/$$p/work;					\
	    status=`if [ ! -d $$work ]; then $(echo) ' ';		\
	    elif [ -f $$work/install._done.* ]; then $(echo) I;		\
	    elif [ -f $$work/package._done.* ]; then $(echo) K;		\
	    elif [ -f $$work/stage._done.* ]; then $(echo) S;		\
	    elif [ -f $$work/build._done.* ]; then $(echo) B;		\
	    elif [ -f $$work/configure._done.* ]; then $(echo) C;	\
	    elif [ -f $$work/patch._done.* ]; then $(echo) P;		\
	    elif [ -f $$work/extract._done.* ]; then $(echo) E;		\
	    fi`;							\
	    $(echo) "                     [$$flag$$status]: $$p";	\
	done

depends_exclude_targets	+= info.ports
info.ports: $(addprefix info.ports.,sep ports)

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

debug_targets		= sep1 port					\
			  sep2 category sep3 category-all sep4 port-categories \
			  sep-end
double_line		= sep1 sep2 sep-end

$(addprefix info.debug.,$(filter sep%,$(debug_targets))):
	@sep=$(findstring $(patsubst info.debug.%,%,$@),$(double_line));\
	if [ ! -z "$$sep" ]; then					\
	    $(echo) "=================================================";\
	else								\
	    $(echo) "-------------------------------------------------";\
	fi

depends_exclude_targets	+= info.debug
info.debug: $(addprefix info.debug.,$(debug_targets))
