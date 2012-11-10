#
# Makefile
#
#   demonstration of how to ues tools.mk
#

# STEP 1: Create PORTS_LISTS
#
# Add port packages name (origin format) which you want to manage (bulk build)
# into "PORTS_LISTS" variable.
#
# Port package naming format will be:
#
#    [group1@[group2@]]category/name
#
# where
#
#    group1,group2,...: virtual "port group" name which will be used to group
#                       different port packages together for different purpose
#             category: the folder where port package stored
#                 name: the name of port package
#
# NOTE:
#
# 1. Every port package must belong to at least one "port group".
# 2. Port group are assigned to port package by add as its prefix part of name
#    with '@' separate mark.
# 3. Mulitple port groups can be assigned to single port simultaneously.
# 4. "Default group name" will be assigned to port package
#    if no prefix part found.
# 5. Default port group name are assigned on "PORTS_GROUP_DEFAULT" variable.
# 6. If no PORTS_GROUP_DEFAULT assigned, "host" will be used as
#    default port group name.

PORTS_GROUP_DEFAULT	= target
PORTS_LISTS		= host@devel/pkg-config				\
			  textproc/expat2				\
			  toolchain@math/gmp				\
			  host@target@security/openssl			\
			  graphics/webp

# STEP 2: Setup Environment Variables
#
# Following environment variable will be sent to ports system
#
#  1. PORTS_ENVS
#
# Following environment variables will be added or removed while
#
#     specific port group: "ggg", and
#     specific port package: "xxx"
#
# are assigned:
#
#  2. PORTS_ggg_ENVS : add
#  3. PORTS_ggg_xxx_EXTRA_ENVS : add
#  4. PORTS_ggg_xxx_EXCLUDE_ENVS : remove
#
# Possible candidates of environment variable may include:
#
#  USE_ALTERNATIVE: extract package source to other location
#  ALTERNATIVE_WRKDIR: the place package source will be extracted
#  PREFIX: the place built package will be installed
#  DESTDIR: a varialbe prepended to PREFIX
#  CROSS_COMPILE: if you are doing corss compile
#

wrkdir			= $(shell cd && pwd)/local
PORTS_ENVS		= USE_GLOBALBASE=yes				\
			  DISTDIR_SITE=/opt/distfiles/ports		\
			  PACKAGES_SITE=/opt/distfiles/ports/packages	\
			  USE_ALTERNATIVE=yes

PORTS_host_ENVS		= ALTERNATIVE_WRKDIR=$(wrkdir)/src/host		\
			  PREFIX=/usr					\
			  DESTDIR=$(wrkdir)/host

PORTS_target_ENVS	= ALTERNATIVE_WRKDIR=$(wrkdir)/src/target	\
			  PREFIX=/usr					\
			  DESTDIR=$(wrkdir)/target

PORTS_toolchain_ENVS	= ALTERNATIVE_WRKDIR=$(wrkdir)/src/host		\
			  PREFIX=/opt					\
			  DESTDIR=$(wrkdir)/host

PORTS_target_webp_EXTRA_ENVS	= WITH_GL=yes

# include ports package at here...
include ../tools.mk

#
# define your own targets...
#

clean:
	@find . -type f -name \*~ -o -name .DS_Store | xargs rm -fr

distclean: clean
