# linux.port.options.mk - Allow OPTIONS to determine dependencies
#
# usage:
#
#	.include "linux.port.options.mk"
#	<deal with user options>
#	.include "linux.port.pre.mk"
#	<other work, including adjusting dependencies>
#	.include "linux.port.post.mk"
#
# Created by: Shaun Amott <shaun@inerd.com>
# Modified by: Max Lee <yowching.lee@gmail.com>

OPTIONS_Include_MAINTAINER=		portmgr@FreeBSD.org

USEOPTIONSMK		= yes
INOPTIONSMK		= yes

include $(PORTSDIR)/Mk/linux.port.mk

undefine INOPTIONSMK
