#
# bsd.commands.mk - Common commands used within the ports infrastructure
#

COMMANDS_Include_MAINTAINER=	yowching.lee@gmail.com

ifndef _COMMANDSMKINCLUDED
_COMMANDSMKINCLUDED	= yes

TAR			?= tar
XZCAT			?= $(shell which xzcat)
XZ_CMD			?= $(shell which xz)
BZCAT			?= $(shell which bzcat)
BZIP2_CMD		?= $(shell which bzip2)
$(if $(BZIP2_CMD),,$(error Sorry, ports need "bzip2" package...))
#GNUZIP_CMD		?= $(shell which gnuzip) -f
_gzip			?= $(shell which gzip)
_gzcat			?= $(shell which gzcat)
ifeq ($(_gzcat),)
ifeq ($(_gzip),)
$(error Sorry, ports need "gzcat" utility that did not exist on your distribution.  You can create a symbolic to "gzip" to fix this problem)
else
GZCAT			?= $(_gzip) -dc
endif
else
GZCAT			?= $(_gzcat)
endif
ifneq ($(_gzip),)
GZIP			?= -9
GZIP_CMD		?= $(_gzip) -nf $(GZIP)
endif
SETENV			?= env
SH			?= /bin/sh
UNAME			?= uname
SED			?= sed
WHICH			?= which
GREP			?= grep
EGREP			?= egrep
GIT			?= git

endif
