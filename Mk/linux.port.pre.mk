#
# linux.port.pre.mk
#

BEFOREPORTMK		= yes

include $(PORTSDIR)/Mk/linux.port.mk

undefine BEFOREPORTMK
