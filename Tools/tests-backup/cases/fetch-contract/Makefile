# Read-only probes of the legacy fetch interfaces; no network is used.
PORTNAME = fetch-contract
DISTVERSION = 1
CATEGORIES = devel
MASTERDIR = $(CURDIR)
MASTER_SITES = https://dist.invalid:8443/%SUBDIR%/:src,extra https://plain.invalid/
ifneq ($(OMIT_SUBDIR),yes)
MASTER_SITE_SUBDIR = releases/:src,extra
endif
PATCH_SITES = https://patch.invalid/%SUBDIR%/:fix
PATCH_SITE_SUBDIR = fixes/:fix
DISTFILES = source.tar.gz:src,extra plain.tar.gz
PATCHFILES = fix.patch:fix
DIST_SUBDIR = contract
include $(PORTSDIR)/Mk/linux.port.mk

.PHONY: snapshot
snapshot:
	@printf '%s\n' \
	  'distfiles=$(strip $(distfiles))' \
	  'patchfiles=$(strip $(patchfiles))' \
	  'src=$(call generate-master-sites-by-group,src)' \
	  'extra=$(call generate-master-sites-by-group,extra)' \
	  'default=$(call generate-master-sites-by-group,DEFAULT)' \
	  'patch=$(call generate-patch-sites-by-group,fix)' \
	  'mode=$(SOURCE_MODE_EFFECTIVE)' \
	  'repo=$(SCM_REPO_URL)' \
	  'cache=$(SCM_CACHE_NAME)' \
	  'timeout=$(SCM_TIMEOUT)'
