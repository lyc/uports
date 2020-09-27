#
# linux.port.mk
#

# $(call subdirectory,makefile)
subdirectory		= $(patsubst %/$1,%,				\
			    $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))

PORTSDIR		:= $(abspath $(call subdirectory,linux.port.mk)/..)

include $(PORTSDIR)/Mk/linux.port.pre.mk
include $(PORTSDIR)/Mk/linux.port.post.mk
