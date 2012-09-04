PORTNAME		= bar
PORTVERSION		= 1.0
CATEGORIES		= unknown
PORTREVISION		= 2
LICENSE			= unknown

MAINTAINER 		= yowching.lee@gmail.com
COMMENT 		= Test package

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets	+= pre-extract

quiet_cmd_pre-extract	?= PRE-EXTRACT $(PKGNAME)
      cmd_pre-extract	?= set -e;					\
	echo "Oops, run customized $@..."$(trash);			\
	echo "WRKSRC=$(WRKSRC)"$(trash)

pre-extract:
	$(call cmd,pre-extract)

include $(PORTSDIR)/Mk/linux.port.post.mk
