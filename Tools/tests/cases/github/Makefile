# Single-repository hosted archive fixture; URLs are never fetched by snapshot.
# Synthetic archives must stay in each test's cache, even when the caller
# exports global-cache settings or passes them through MAKEFLAGS.
override USE_GLOBALBASE	= no

PORTNAME		= demo
DISTVERSION		= 1.2
CATEGORIES		= devel
USE_GITHUB		= yes
MASTERDIR		= $(CURDIR)
include $(PORTSDIR)/Mk/linux.port.pre.mk

ifeq ($(SOURCE_MODE_EFFECTIVE),git)
PATCH_DEPENDS		+= bootstrap:devel/bootstrap
endif

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
	@printf '%s\n'						       \
	  'globalbase=$(USE_GLOBALBASE)'				       \
	  'account=$(GH_ACCOUNT)'				       \
	  'project=$(GH_PROJECT)'				       \
	  'tag=$(GH_TAGNAME)'					       \
	  'sanitized=$(GH_TAGNAME_SANITIZED)'			       \
	  'extract=$(GH_TAGNAME_EXTRACT)'			       \
	  'mode=$(SOURCE_MODE_EFFECTIVE)'			       \
	  'name=$(DISTNAME)'					       \
	  'files=$(strip $(DISTFILES))'				       \
	  'source=$(notdir $(WRKSRC))'				       \
	  'repo=$(SCM_REPO_URL)'				       \
	  'branch=$(SCM_BRANCH)'				       \
	  'detach=$(SCM_DETACH)'				       \
	  'urls=$(call generate-master-sites-by-group,DEFAULT)'

.PHONY: source-order-snapshot
source-order-snapshot:
	@printf '%s\n'							\
	  'patch_depends=$(PATCH_DEPENDS)'				\
	  'patch_sequence=$(call get-real-seqs,PATCH)'

.PHONY: group-snapshot
group-snapshot:
	@printf '%s\n' 'groups=$(_GITHUB_GROUPS)'
	@$(foreach group,$(_GITHUB_GROUPS),			       \
	  printf '%s|%s|%s|%s|%s|%s|%s\n'			       \
	    '$(group)' '$(GH_ACCOUNT_$(group))'			       \
	    '$(GH_PROJECT_$(group))' '$(GH_TAGNAME_$(group))'	       \
	    '$(GH_SUBDIR_$(group))' '$(DISTFILE_$(group))'	       \
	    '$(notdir $(WRKSRC_$(group)))';) true
