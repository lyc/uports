#
# Special groups ...
#

bs_lists		= devel/m4					\
			  devel/autoconf-2.72				\
			  devel/autoconf-switch				\
			  devel/automake-1.17				\
			  devel/libtool

host_lists		= devel/pkg-config				\
			  devel/cmake					\
			  devel/ninja					\
			  devel/meson

special_groups_all	+= bs host

# $(call uports-native-group, custom-group)
# Declare defaults only; membership and provider policy stay separate.
define uports-native-group
$(if $(filter 1,$(words $1)),,$(error Specify one native group))
$(call uports-native-group-impl,$(strip $1))
endef

# $(call uports-native-group-impl, normalized group)
define uports-native-group-impl
ports_native_groups	+= $1
PORTS_$1_ENVS		+= PORTSDIR=$(portdir)			       \
			   PREFIX=$(PREFIX) DESTDIR=$(DESTDIR)	       \
			   USE_ALTERNATIVE=yes			       \
			   ALTERNATIVE_WRKDIR=$(DESTDIR)/src
endef
