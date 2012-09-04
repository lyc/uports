PORTNAME		= bar
PORTVERSION		= 1.0
PORTREVISION		= 2

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)
include $(PORTSDIR)/linux.port.pre.mk

override_targets	+= pre-extract

quiet_cmd_pre-extract	?= PRE-EXTRACT $(PKGNAME)
      cmd_pre-extract	?= set -e;					\
	echo "Oops, run customized $@..."$(trash);			\
	echo "WRKSRC=$(WRKSRC)"$(trash)

pre-extract:
	$(call cmd,pre-extract)

include $(PORTSDIR)/linux.port.post.mk
