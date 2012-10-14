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

PORTS_LISTS		= devel/pkg-config				\
			  textproc/expat2				\
			  graphics/webp

# STEP 2: Setup Environment Variables
#
# Following environment variable will be sent to ports system
#
#  1. PORTS_ENVS
#
# Following environment variables will be added or removed while
# specific port package "xxx" is working
#
#  2. PORTS_xxx_EXTRA_ENVS : add
#  3. PORTS_xxx_EXCLUDE_ENVS : remove
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
			  USE_ALTERNATIVE=yes				\
			  ALTERNATIVE_WRKDIR=$(wrkdir)/src		\
			  PREFIX=/usr					\
			  DESTDIR=$(wrkdir)

PORTS_webp_EXTRA_ENVS	= WITH_GL=yes

# include ports package at here...
include ../tools.mk

#
# define your own targets...
#

clean:
	@find . -type f -name \*~ -o -name .DS_Store | xargs rm -fr

distclean: clean
