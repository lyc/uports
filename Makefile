PORTNAME		= bar
PORTVERSION		= 1.0
PORTREVISION		= 2

# define for prevent run "distclean-depneds" target in distclean
#NOCLEANDEPENDS		= yes

#
#
#

MASTERDIR 		= $(CURDIR)
PORTSDIR 		= $(MASTERDIR)
include $(PORTSDIR)/linux.port.pre.mk

include $(PORTSDIR)/linux.port.post.mk
