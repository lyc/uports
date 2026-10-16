#
# linux.fetch-sites.mk
#
# GNU make implementation of FreeBSD-style mirror declaration semantics.
# Reference revision and scope: docs/01-FETCH-CONTRACT.md. Catalog unchanged.
#

MASTER_SITES_ABBREVS	?= GH:GITHUB SF:SOURCEFORGE
MASTER_SITES_SUBDIRS	?= GNU:$(PORTNAME)

# $(call fetch-alias, family)
fetch-alias		= $(or						\
			    $(word 2,$(subst :, ,			\
			      $(filter $1:%,$(MASTER_SITES_ABBREVS)))),$1)

# $(call fetch-family, declaration)
fetch-family		=						\
	$(call fetch-alias,$(firstword $(subst /, ,$(call get-file-name,$1))))

# $(call fetch-path, family/path)
fetch-path		= $(patsubst $(firstword $(subst /, ,$1))/%,%,$1)

# $(call fetch-default-subdir, family)
fetch-default-subdir	= $(word 2,$(subst :, ,				\
			    $(filter $1:%,$(MASTER_SITES_SUBDIRS))))

# $(call fetch-declaration-path, declaration)
fetch-declaration-path	=						\
	$(call remove-terminator,$(call fetch-path,$(call get-file-name,$1)))

# $(call fetch-declaration-subdir, declaration)
fetch-declaration-subdir	=					\
	$(call fetch-default-subdir,$(call fetch-family,$1))

# $(call fetch-group-suffix, declaration)
fetch-group-suffix	=						\
	$(if $(call get-file-group,$1),:$(call get-file-group,$1))

# $(call fetch-expand-family, declaration, subdirectory-variable)
define fetch-expand-family
$(if $(MASTER_SITE_$(call fetch-family,$1)),				\
  $(foreach mirror,$(MASTER_SITE_$(call fetch-family,$1)),		\
    $(call remove-terminator,						\
      $(if $(findstring /,$(call get-file-name,$1)),			\
        $(subst %SUBDIR%,$(call fetch-declaration-path,$1),$(mirror)),	\
        $(if $(filter undefined,$(origin $2)),				\
          $(if $(call fetch-default-subdir,$(call fetch-family,$1)),	\
            $(subst %SUBDIR%,$(call fetch-declaration-subdir,$1),$(mirror)),\
            $(mirror)),							\
          $(mirror))))/$(call fetch-group-suffix,$1)),			\
  $(error Unknown mirror family '$(call fetch-family,$1)' in $1))
endef

# $(call fetch-expand-sites, declarations, subdirectory-variable)
define fetch-expand-sites
$(strip									\
  $(foreach entry,$1,							\
    $(if $(and $(_GH_SITE),$(filter GH GITHUB,$(entry))),		\
      $(_GH_SITE),							\
      $(if $(findstring :/,$(entry)),				\
        $(entry),$(call fetch-expand-family,$(entry),$2)))))
endef

# Legacy Git uses MASTER_SITES as a host, not an archive family.
ifeq ($(strip $(USE_SCM)),)
_fetch_master_sites	:= $(call fetch-expand-sites,			\
			    $(MASTER_SITES),MASTER_SITE_SUBDIR)
_fetch_patch_sites	:= $(call fetch-expand-sites,			\
			    $(PATCH_SITES),PATCH_SITE_SUBDIR)
else
_fetch_master_sites	:= $(MASTER_SITES)
_fetch_patch_sites	:= $(PATCH_SITES)
endif

# $(call fetch-subdirs, subdirectories)
define fetch-subdirs
$(strip									\
  $(foreach entry,$1,							\
    $(if $(findstring /:,$(entry)),$(entry),				\
      $(if $(call get-file-group,$(entry)),				\
        $(call get-file-name,$(entry))/:$(call get-file-group,$(entry)),\
        $(entry)))))
endef

master_sites		= $(call patch-sites-DEFAULT,$(_fetch_master_sites))
patch_sites		= $(call patch-sites-DEFAULT,$(_fetch_patch_sites))

master_site_subdir	= $(call patch-sites-DEFAULT,			\
			    $(call fetch-subdirs,$(MASTER_SITE_SUBDIR)))
patch_site_subdir	= $(call patch-sites-DEFAULT,			\
			    $(call fetch-subdirs,$(PATCH_SITE_SUBDIR)))

# $(call transform-subdirs, pattern, group, subdirectories)
# Expand only the requested group, not all memberships of the same URL.
define transform-subdirs
$(if $(findstring $(SUBDIR),$1),					\
  $(if $(call filter-subdirs-by-group,$3,$2),				\
    $(foreach dir,$(call filter-subdirs-by-group,$3,$2),		\
      $(subst $(SUBDIR),$(dir),$1)),					\
    $(subst $(SUBDIR)/,,$1)),$1)
endef

# $(call generate-sites-by-group, group, sites, subdirectories)
define generate-sites-by-group
$(strip									\
  $(__master_site_override)						\
  $(foreach site,$(call filter-sites-by-group,$2,$1),			\
    $(call transform-subdirs,$(site),$1,$3))				\
  $(__master_site_backup))
endef

$(foreach group,							\
  $(call get-all-site-groups,						\
    $(master_sites) $(patch_sites)					\
    $(master_site_subdir) $(patch_site_subdir)),			\
  $(if $(filter all ALL default,$(group)),				\
    $(error Reserved fetch group '$(group)')))

# Diagnose unresolved named groups at fetch time, not metadata parse time.
# DEFAULT may be empty (local-only distfiles and NO_FETCH ports are valid).
.PHONY: fetch-groups-check
fetch-groups-check:
ifeq ($(strip $(USE_SCM)),)
	@$(foreach file,$(distfiles),					\
	  $(foreach group,						\
	    $(call remove-comma,$(call get-file-group,$(file))),	\
	    $(if $(filter DEFAULT					\
	      $(call get-all-site-groups,$(master_sites)),$(group)),,	\
	      $(error Missing MASTER_SITES group '$(group)'		\
	        for $(call get-file-name,$(file)))))) true
	@$(foreach file,$(patchfiles),					\
	  $(foreach group,						\
	    $(call remove-comma,$(call get-file-group,$(file))),	\
	    $(if $(filter DEFAULT					\
	      $(call get-all-site-groups,$(patch_sites)),$(group)),,	\
	      $(error Missing PATCH_SITES group '$(group)'		\
	        for $(call get-file-name,$(file)))))) true
endif

do-fetch: fetch-groups-check
