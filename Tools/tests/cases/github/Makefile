# Single-repository hosted archive fixture; URLs are never fetched by snapshot.
PORTNAME		= demo
DISTVERSION		= 1.2
CATEGORIES		= devel
USE_GITHUB		= yes
MASTERDIR		= $(CURDIR)
include $(PORTSDIR)/Mk/linux.port.pre.mk

override_targets		+= do-configure do-build do-install
do-configure:
	@:
do-build:
	@$(CC) $(WRKSRC)/hello.c -o $(WRKSRC)/hello
do-install:
	@mkdir -p $(STAGEDIR)$(PREFIX)/bin
	@cp $(WRKSRC)/hello $(STAGEDIR)$(PREFIX)/bin/hello

include $(PORTSDIR)/Mk/linux.port.post.mk

.PHONY: snapshot
snapshot:
	@printf '%s\n'							\
	  'account=$(GH_ACCOUNT)'					\
	  'project=$(GH_PROJECT)'					\
	  'tag=$(GH_TAGNAME)'						\
	  'sanitized=$(GH_TAGNAME_SANITIZED)'				\
	  'extract=$(GH_TAGNAME_EXTRACT)'					\
	  'name=$(DISTNAME)'						\
	  'files=$(strip $(DISTFILES))'					\
	  'source=$(notdir $(WRKSRC))'					\
	  'urls=$(call generate-master-sites-by-group,DEFAULT)'
