#
# bsd.commands.mk - Common commands used within the ports infrastructure
#

COMMANDS_Include_MAINTAINER=	yowching.lee@gmail.com

ifndef _COMMANDSMKINCLUDED
_COMMANDSMKINCLUDED	= yes

EGREP			?= $(shell which egrep)
FIND			?= $(shell which find)
GREP			?= $(shell which grep)
GIT			?= git
REALPATH		?= $(shell which realpath)
SED			?= $(shell which sed)
SETENV			?= env
SH			?= /bin/sh
UNAME			?= uname
WHICH			?= which
XARGS			?= /usr/bin/xargs

XZ			?= -Mmax
XZCAT			=  /usr/bin/xzcat ${XZ}
XZ_CMD			?= /usr/bin/xz ${XZ}

MD5			?= /sbin/md5
SHA256			?= /sbin/sha256
SOELIM			?= /usr/bin/soelim

# ECHO is defined in /usr/share/mk/sys.mk, which can either be "echo",
# or "true" if the make flag -s is given.  Use ECHO_CMD where you mean
# the echo command.
ECHO_CMD		?= echo	# Shell builtin

endif
