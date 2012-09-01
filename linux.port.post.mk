#
# linux.port.post.mk
#

$(if $(_POSTMKINCLUDED),						\
  $(error $(PKGNAME): You cannot inlcude linux.port[.post].mk twice))
_POSTMKINCLUDED		:= yes

WRKDIR			?= $(WRKDIRPREFIX)$(MASTERDIR)/work

ifneq ($(NO_WRKSUBDIR),yes)
WRKSRC			?= $(WRKDIR)/$(DISTNAME)
else
WRKSRC			?= $(WRKDIR)
endif

PATCH_WRKSRC		?= $(WRKSRC)
CONFIGURE_WRKSRC	?= $(WRKSRC)
BUILD_WRKSRC		?= $(WRKSRC)
INSTALL_WRKSRC		?= $(WRKSRC)

# Name of cookies used to skip already completed stages
EXTRACT_COOKIE		?= $(WRKDIR)/extract._done.$(PKGNAME)
PATCH_COOKIE		?= $(WRKDIR)/patch._done.$(PKGNAME)
CONFIGURE_COOKIE	?= $(WRKDIR)/configure._done.$(PKGNAME)
BUILD_COOKIE		?= $(WRKDIR)/build._done.$(PKGNAME)
INSTALL_COOKIE		?= $(WRKDIR)/install._done.$(PKGNAME)
PACKAGE_COOKIE		?= $(WRKDIR)/package._done.$(PKGNAME)

# How to do nothing.  Override if you, for some strange reason, would rather
# do something.
DO_NADA			?= true

# -maintainer:
# -check-categories:

################################################################
# The following are used to create easy dummy target for
# disabling some bit of default target behavior you don't want.
# They still check to see if the target exists, and if so don't
# do anything, since you might want to set this globally for a
# group of ports in a Makefile.inc, but still be able to
# override from an individual Makefile
################################################################



################################################################
# More standard target start here
#
# These are the body of the build/install framework.  If you are
# not happy with the default actions, and you can't solve it by
# adding pre-* or post-* target/scripts, override these.
################################################################

ifeq ($(filter $(override_targets),pre-everything),)
pre-everything::
	@echo "  pre-everything..."
	@$(DO_NADA)
endif

#
# Fetch...
#

ifeq ($(filter $(override_targets),do-fetch),)
do-fetch:
	@echo "  do-fetch..."
endif

#
# Extract...
#

.PHONY: wrkdir
wrkdir:
	@echo "  wrkdir..."
	@[ -d $(WRKDIR) ] || mkdir -p $(WRKDIR)

ifeq ($(filter $(override_targets),do-extract),)
do-extract: wrkdir $(EXTRACT_ONLY)
	@echo "  do-extract..."
endif

#
# Patch...
#

ifeq ($(filter $(override_targets),do-patch),)
do-patch:
	@echo "  do-patch..."
endif

#
# Configure...
#

# -run-autotools-fixup:
# -configure-autotools:
# -run-autotools:

ifeq ($(filter $(override_targets),do-configure),)
do-configure:
	@echo "  do-configure..."
endif

#
# Build...
#

ifeq ($(filter $(override_targets),do-build),)
do-build:
	@echo "  do-build..."
endif

#- check-conflicts:

#
# Install...
#

ifeq ($(filter $(override_targets),do-install),)
do-install:
	@echo "  do-install..."
endif

#
# Package...
#

ifeq ($(filter $(override_targets),do-package),)
do-package:
	@echo "  do-package..."
endif

#- package-links: delete-package-links
#- delete-package-links:
#- delete-package: delete-package-links
#- delete-package-link-list:
#- delete-package-list: delete-package-links-list

# Utility targets follow

#- install-mtree
# -check-already-installed:
# -install-ldconfig-file:
# -security-check:

################################################################
# Skeleton targets start here
#
# You shouldn't have to change these.  Either add the pre-* or
# post-* targets/scripts or redefine the do-* targets.  These
# targets don't do anything other than checking for cookies and
# call the necessary targets/scripts.
################################################################

# Please note that the order of the following targets is important, and
# should not be modified.

_FETCH_SEQ		= pre-everything				\
			  do-fetch

_EXTRACT_DEP		= fetch
_EXTRACT_SEQ		= extract-message				\
			  do-extract

_PATCH_DEP		= extract
_PATCH_SEQ		= patch-message					\
			  do-patch

_CONFIGURE_DEP 		= patch
_CONFIGURE_SEQ		= configure-message				\
			  do-configure

_BUILD_DEP		= configure
_BUILD_SEQ		= build-message					\
			  do-build

_INSTALL_DEP		= build
_INSTALL_SEQ		= install-message				\
			  do-install

_PACKAGE_DEP		= install
_PACKAGE_SEQ		= package-message				\
			  do-package

cookie_targets		:=						\
	extract patch configure build install package

ifeq ($(filter $(override_targets),fetch),)
fetch: $(_FETCH_SEQ)
endif

# Main logick. The loop gererates 6 main targets and using cookies
# ensures that those already completed are skipped.

# $(call uppercase-target target)
define uppercase-target
$(strip									\
  $(if $(filter $1,extract),EXTRACT,					\
    $(if $(filter $1,patch),PATCH,					\
      $(if $(filter $1,configure),CONFIGURE,				\
        $(if $(filter $1,build),BUILD,					\
          $(if $(filter $1,install),INSTALL,				\
            $(if $(filter $1,package),PACKAGE)))))))
endef

# $(call generate-cookie-targets, target, uppercase_target)
define generate-cookie-targets
ifeq ($(filter $(override_targets),$1),)
$1: $($2_COOKIE)
endif
ifeq ($(wildcard $($2_COOKIE)),)
$($2_COOKIE): $($(patsubst %,_%_DEP,$2)) $($(patsubst %,_%_SEQ,$2))
	@touch $($2_COOKIE)
ifneq ($($2_LISTS),)
	@echo $($2_LISTS) >> $($2_COOKIE)
endif
else
($2_COOKIE):
	@$(DO_NADA)
endif
endef

$(foreach t,$(cookie_targets),						\
  $(eval 								\
    $(call generate-cookie-targets,$t,$(call uppercase-target,$t))))

extract-message:
	@echo "  EXTRACT $(PKGNAME)"
patch-message:
	@echo "  PATCH   $(PKGNAME)"
configure-message:
	@echo "  CONFIGURE $(PKGNAME)"
build-message:
	@echo "  BUILD   $(PKGNAME)"
install-message:
	@echo "  INSTALL $(PKGNAME)"
package-message:
	@echo "  PACKAGE $(PKGNAME)"

################################################################
# Some more target supplied for users' convenience
################################################################

#- checkpatch:
#- reinstall:
#- uninstall:


# clean

ifeq ($(filter $(override_targets),do-clean),)
do-clean:
	@echo "  CLEAN     $(PKGNAME)";					\
	if [ -d $(WRKSRC) ]; then					\
	    (cd $(WRKSRC) && make clean);				\
	    rm -fr $(BUILD_COOKIE);					\
	    rm -fr $(INSTALL_COOKIE);					\
	fi
endif

ifeq ($(filter $(override_targets),clean),)
clean:
	@cd $(MASTERDIR) && $(MAKE) --no-print-directory $(__softMAKEFLAGS) do-clean
endif

# distclean

ifeq ($(filter $(override_targets),pre-distclean),)
pre-distclean:
	@$(DO_NADA)
endif

ifeq ($(filter $(override_target),do-distclean),)
do-distclean:
	@echo "  DISTCLEAN $(PKGNAME)";					\
	if [ -d $(WRKDIR) ]; then					\
		if [ -w $(WRKDIR) ]; then				\
			rm -fr $(WRKDIR);				\
		else							\
			echo "  ERR     $(WRKDIR) not writable, skipping"; \
		fi;							\
	fi
endif

ifeq ($(filter $(override_targets),distclean),)
distclean: pre-distclean
ifneq ($(NOCLEANDEPENDS),yes)
	@cd $(MASTERDIR) && $(MAKE) --no-print-directory $(__softMAKEFLAGS) distclean-depends
endif
	@cd $(MASTERDIR) && $(MAKE) --no-print-directory $(__softMAKEFLAGS) do-distclean
endif

#--- really-distclean:
#- delete-distfiles:
#- delete-distfiles-list:
#- fetch-list:
#- update-patches:
#- makesum:

# -checksum:

################################################################
# The special package-building targets:
# You probably won't need to touch these
################################################################

#- package-name:
#- repackage:
#- pre-repackage:
#- package-noinstall:

################################################################
# Dependency checking
################################################################

# -pkg-depends:
# -extract-depends:
# -patch-depends:
# -fetch-depends:
# -build-depends:
# -run-depends:
# -lib-depends:
# -misc-depends:

# Dependency lists: both build and runtime, recursive.
# Print out directory names.
#- all-depends-list:

ifeq ($(filter $(override_depends),clean-depends),)
clean-depends:
	@$(DO_NADA)
endif

ifeq ($(filter $(override_depends),distclean-depends),)
distclean-depends:
	@$(DO_NADA)
endif


#- fetch-recursive:
#- fetch-recursive-list: fetch
#- fetch-required-list: fetch-list
#- checksum-recursive:

# Dependency lists: build and runtime.  Print out directory names.

#- build-depends-list:
#- run-depends-list:

# Package (recursive runtime) dependency list.  Print out both directory names
# and package names.

#- package-depends-list:
#- package-depends:

################################################################
# Everything after here are internal targets and really
# shouldn't be touched by anybody but the release engineers.
################################################################

#- describe:
#- www-site:
#- readmes:
#- readme:
#- $(CURDIR)/README.html:
#- pretty-print-depends-list:
#- pretty-print-run-depends-list:
#- generate-plist:
#- $(TMPPLIST):
#- compress-man:
#- fake-pkg:
#- depend:
#- tags:
