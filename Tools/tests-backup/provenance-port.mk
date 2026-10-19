# Isolated package fixture: real pkg/state scripts, no fetching or compiling.
WRKDIR := $(PROVENANCE_TEST_ROOT)/work.$(PORTNAME)
PACKAGE_FILE := $(WRKDIR)/$(PORTNAME).pkg

.PHONY: uports-dependency-metadata install package \
	uports-dependency-state-invalidate uports-dependency-state-save

uports-dependency-metadata:
	@$(if $(filter tool,$(PORTNAME)),:,printf '%s\n' 'build|tool:devel/tool')
	@$(if $(filter alpha,$(PORTNAME)),printf '%s\n' 'lib|libnative.so:devel/native',:)

install:
	@printf '%s\n' 'provider=$(PORTNAME)' >> "$(PROVENANCE_TEST_ROOT)/events"

# Exercise package creation reached through an install lifecycle request.
ifeq ($(INSTALL_CREATES_PACKAGE),yes)
install reinstall: package
endif

package:
	@set -e; mkdir -p "$(WRKDIR)"; \
	  if test -n "$${UPORTS_DEPENDENCY_PROVENANCE_FILE:-}"; then \
	    printf '%s\n' "$$UPORTS_DEPENDENCY_PROVENANCE_FILE" >> "$(PROVENANCE_TEST_ROOT)/temporary-files"; \
	  fi; \
	  test "$(PACKAGE_FAIL)" != yes || exit 1; \
	  test ! -f "$(WRKDIR)/package.done" || exit 0; \
	  mkdir -p "$(WRKDIR)/stage/usr/local"; \
	  printf '%s\n' '$(PORTNAME) payload' > "$(WRKDIR)/stage/usr/local/payload.txt"; \
	  printf '%s\n' payload.txt > "$(WRKDIR)/plist"; \
	  env STAGEDIR="$(WRKDIR)/stage" PKGNAME=$(PORTNAME) VERSION=1 \
	    ORIGIN=devel/$(PORTNAME) PREFIX=/usr/local INDEX=devel COMPRESS=XZ EXT=linux \
	    PLIST="$(WRKDIR)/plist" WRKDIR_PKGFILE="$(PACKAGE_FILE)" \
	    PROVENANCE="$${UPORTS_DEPENDENCY_PROVENANCE_FILE:-}" \
	    "$(PORTSDIR)/Mk/Scripts/pkg.sh" create; \
	  touch "$(WRKDIR)/package.done"; \
	  printf '%s\n' 'package=$(PORTNAME)' >> "$(PROVENANCE_TEST_ROOT)/events"

uports-dependency-state-invalidate uports-dependency-state-save:
	@env DEPENDENCY_STATE_FILE="$(WRKDIR)/dependency.$(DEPENDENCY_STATE_CLASS).state" \
	  DEPENDENCY_STATE_SOURCE="$(DEPENDENCY_STATE_SOURCE)" \
	  DEPENDENCY_STATE_COOKIES="$(WRKDIR)/package.done" \
	  DEPENDENCY_STATE_ARTIFACTS="$(PACKAGE_FILE)" \
	  /bin/sh "$(PORTSDIR)/Mk/Scripts/dependency-state.sh" \
	  $(patsubst uports-dependency-state-%,%,$@)
