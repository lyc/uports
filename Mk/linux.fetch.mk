#
# linux.fetch.mk - portable archive-fetch executor interface
#

FETCH_TOOL		?= $(notdir $(firstword $(FETCH_CMD)))
FETCH_TIMEOUT		?= 30
FORCE_FETCH_ALL		?= no
DISABLE_SIZE		?= no
MASTER_SORT		?=
MASTER_SORT_REGEX	?=
RANDOMIZE_MASTER_SITES	?= no

# $(call fetch-export-sites, flavor, group, sites, subdirectories)
# Keep overrides/backups separate so the executor applies them only once.
define fetch-export-sites
$(eval export _$1_SITES_$2 = $(strip				       \
  $(foreach site,$(call filter-sites-by-group,$3,$2),		       \
    $(call transform-subdirs,$(site),$2,$4))))
endef

$(foreach group,DEFAULT $(call get-all-site-groups,$(master_sites)),   \
  $(call fetch-export-sites,MASTER,$(group),			       \
    $(master_sites),$(master_site_subdir)))
$(foreach group,DEFAULT $(call get-all-site-groups,$(patch_sites)),    \
  $(call fetch-export-sites,PATCH,$(group),			       \
    $(patch_sites),$(patch_site_subdir)))

# $(call archive-fetch-env, target, flavor)
define archive-fetch-env
dp_DISTDIR="$(_DISTDIR)"					       \
dp_DIST_SUBDIR="$(DIST_SUBDIR)"					       \
dp_DISTINFO_FILE="$(abspath $(DISTINFO_FILE))"			       \
dp_DISTINFO_REQUIRED="$(DISTINFO_REQUIRED)"			       \
dp_SITE_FLAVOR="$2" dp_TARGET="$1"				       \
dp_FETCH_CMD="$(FETCH_CMD)" dp_FETCH_TOOL="$(FETCH_TOOL)"	       \
dp_FETCH_TIMEOUT="$(FETCH_TIMEOUT)" dp_FETCH_REGET="$(FETCH_REGET)"    \
dp_FETCH_ENV="$(FETCH_ENV)"					       \
dp_FETCH_BEFORE_ARGS="$(FETCH_BEFORE_ARGS)"			       \
dp_FETCH_AFTER_ARGS="$(FETCH_AFTER_ARGS)"			       \
dp_FORCE_FETCH_ALL="$(FORCE_FETCH_ALL)"				       \
dp_FORCE_FETCH_LIST="$(FORCE_FETCH)"				       \
dp_NO_CHECKSUM="$(NO_CHECKSUM)" dp_DISABLE_SIZE="$(DISABLE_SIZE)"      \
dp_NO_CHECK_CERTIFICATE="$(NO_CHECK_CERTIFICATE)"		       \
dp_MASTER_SITE_OVERRIDE="$(__master_site_override)"		       \
dp_MASTER_SITE_BACKUP="$(__master_site_backup)"			       \
dp_MASTER_SORT="$(MASTER_SORT)"					       \
dp_MASTER_SORT_REGEX="$(MASTER_SORT_REGEX)"			       \
dp_RANDOMIZE_SITES="$(RANDOMIZE_MASTER_SITES)"
endef

# $(call archive-fetch, target)
define archive-fetch
$(call archive-fetch-env,$1,MASTER)				       \
  $(SH) "$(SCRIPTSDIR)/do-fetch.sh" $(distfiles)
$(call archive-fetch-env,$1,PATCH)				       \
  $(SH) "$(SCRIPTSDIR)/do-fetch.sh" $(patchfiles)
endef

.PHONY: fetch-list fetch-url-list
fetch-list fetch-url-list:
ifeq ($(USE_SCM),)
	@$(call archive-fetch,$@)
else
	@echo "  SKIP    $@ is for archive sources, not USE_SCM=$(USE_SCM)"
endif
