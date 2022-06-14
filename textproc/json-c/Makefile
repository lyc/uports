# Prts collection:	json-c
# Date created:		14/Feb/2006
# Whom:                 colin@askey.com.tw

PORTNAME		= json-c
DISTVERSION		= 0.12
DISTVERSIONSUFFIX	= -20140410
CATEGORIES		= textproc
MASTER_SITES 		= $(MASTER_SITE_GITHUB)
MASTER_SITE_SUBDIR	= $(PORTNAME)/$(PORTNAME)

MAINTAINER		= dtchang@askey.com.tw
COMMENT			= A JSON implementation in C

LICENSE			= MIT

USES			= libtool:keepla
ifeq ($(USE_SCM),git)
MASTER_SITES		:= github.com
MASTER_SITE_SUBDIR	:= json-c
NO_SCM_PATCH_APPLY	= yes
endif

EXTRACT_TRANSFORM	= /json-c-json-c/json-c/g
USE_REINPLACE 		= yes
#NO_CHECK_CERTIFICATE	= yes
GNU_CONFIGURE		= yes
CONFIGURE_ARGS		+= --enable-shared				\
			   ac_cv_func_malloc_0_nonnull=yes		\
			   ac_cv_func_realloc_0_nonnull=yes

#
#
#

MASTERDIR		= $(CURDIR)
PORTSDIR		?= $(MASTERDIR)/../..
include $(PORTSDIR)/Mk/linux.port.pre.mk

ifeq ($(CROSS_COMPILE),mips-linux-uclibc)
override_targets 	+= post-configure

# Realtek toolchain don't support no-error=deprecated-declarations option
post-configure:
	@$(REINPLACE_CMD)						\
	    -e "s/\(^.*\) -Wno-error=deprecated-declarations\(.*$$\)/\1\2/" \
	    $(WRKSRC)/Makefile
endif

include $(PORTSDIR)/Mk/linux.port.post.mk
