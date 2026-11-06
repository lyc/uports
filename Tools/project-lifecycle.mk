#
# project-lifecycle.mk - project roots, provider-first dispatch and cleanup
#

ifneq ($(origin PROJECT_PORTS),undefined)
project_cleanup_phases	:= clean distclean deinstall uninstall
project_direct_phases	:= $(project_cleanup_phases) fetch extract patch \
	$(suffix_special_all) flavor-check

# $(call project-goal-aggregate, target)
project-goal-aggregate	= $(filter ports $(groups_all)                 \
	$(categories_all),$(basename $1))

# $(call project-goal-records, target)
define project-goal-records
$(strip $(if $(call project-goal-aggregate,$1),                        \
  $(foreach r,$(project_root_requests),                                \
    $(if $(filter ports $(call project-root-field,1,$r)                \
      $(firstword $(subst /, ,$(call project-root-field,2,$r))),       \
      $(basename $1)),$r)),                                            \
  $(call project-port-records,$(basename $1))))
endef

# $(call project-port-records, [group:]port[@flavor])
define project-port-records
$(strip $(if $(findstring :,$1),                                       \
  $(filter $(call project-root-group,$1)|%,                            \
    $(call project-name-records,$1)),                                  \
  $(or $(filter $(PORTS_GROUP_DEFAULT)|%,                              \
    $(call project-name-records,$1)),$(call project-name-records,$1))))
endef

# $(call project-name-records, [group:]port[@flavor])
project-name-records	= $(foreach r,$(project_root_requests),        \
	$(if $(filter $(notdir $(call project-root-field,2,$r)),       \
	  $(notdir $(call project-root-name,$1))),$r))

# $(call project-selection-records, target)
# Explicit provider cleanup is permitted; aggregates never add provider roots.
define project-selection-records
$(strip $(call project-filter-flavor,$1,                               \
  $(or $(call project-goal-records,$1),                                \
  $(if $(and $(findstring :,$1),                                       \
    $(filter $(suffix $1),$(addprefix .,$(project_cleanup_phases)))),  \
    $(call project-root-check,$(basename $1))                          \
    $(subst $(space),,$(call project-root-record,$(basename $1)))))))
endef

# $(call project-filter-flavor, target, root-records)
# Do not evaluate unrelated explicit Flavors with the caller's source mode.
define project-filter-flavor
$(if $(call project-root-flavor,$(basename $1)),                       \
  $(foreach r,$2,$(if $(call project-root-field,3,$r),                 \
    $(if $(filter $(call project-root-flavor,$(basename $1)),          \
      $(call project-root-field,3,$r)),$r),$r)),$2)
endef

# $(call project-selection-probe, root-record, target)
define project-selection-probe
$(call project-root-probe,$1)                                          \
flavors=$$(sed -n 's/^flavors|//p' "$$work/metadata");                 \
$(if $(call project-goal-aggregate,$2),,                               \
  $(if $(call project-root-flavor,$(basename $2)),                     \
    test -n "$$flavors" || selected=;                                  \
    test "$$selected" = '$(call project-root-flavor,$(basename $2))'   \
      || selected=;))                                                  \
if test -n "$$selected"; then                                          \
  target='$(call project-root-field,1,$1):';                           \
  target="$$target"'$(notdir $(call project-root-field,2,$1))';        \
  test -z "$$flavors" || target="$$target@$$selected";                 \
  printf '%s.%s\n' "$$target" '$(call extract-suffix,$2)'              \
    >> "$$work/targets";                                               \
fi;
endef

.PHONY: project-targets-list
depends_exclude_targets	+= project-targets-list
project-targets-list:
	@$(if $(filter 1,$(words $(_UPORTS_PROJECT_TARGET))),,         \
	  $(error Specify one project lifecycle target))
	@$(if $(call project-selection-records,$(_UPORTS_PROJECT_TARGET)),, \
	  $(if $(call project-goal-aggregate,$(_UPORTS_PROJECT_TARGET)),, \
	    $(error Target is not a declared project root: $(_UPORTS_PROJECT_TARGET))))
	@set -e; work=$$(mktemp -d                                     \
	  "$${TMPDIR:-/tmp}/uports-project-selection.XXXXXX");         \
	trap 'rm -rf "$$work"' EXIT HUP INT TERM;                      \
	: > "$$work/roots"; : > "$$work/targets";                      \
	$(foreach r,$(call project-selection-records,                  \
	  $(_UPORTS_PROJECT_TARGET)),                                  \
	  $(call project-selection-probe,$r,$(_UPORTS_PROJECT_TARGET))) \
	awk '!seen[$$0]++' "$$work/targets" > "$$work/unique";         \
	$(if $(call project-goal-aggregate,$(_UPORTS_PROJECT_TARGET)),, \
	  if test "$$(wc -l < "$$work/unique")" -ne 1; then            \
	    echo 'Select one declared root with group:port@flavor.phase' >&2; \
	    exit 1;                                                    \
	  fi;)                                                         \
	cat "$$work/unique"

# $(call project-lifecycle-command, requested-target)
define project-lifecycle-command
set -e; invocation_dir=$$(mktemp -d                                    \
  "$${TMPDIR:-/tmp}/uports-project-invocation.XXXXXX");                \
trap 'rm -rf "$$invocation_dir"' EXIT HUP INT TERM;                    \
$(MAKE) -s --no-print-directory                                        \
  _UPORTS_PROJECT_TARGET='$1' project-targets-list                     \
  > "$$invocation_dir/targets";                                        \
targets=$$(tr '\n' ' ' < "$$invocation_dir/targets");                  \
if test -n "$$targets"; then                                           \
  $(if $(or $(filter $(call extract-suffix,$1),$(project_direct_phases)), \
    $(filter none,$(UPORTS_DEPENDENCIES))),                            \
    $(MAKE) --no-print-directory _UPORTS_PROJECT_DIRECT=yes            \
      DEPENDENCY_REQUESTS= DEPENDENCY_REQUEST=                         \
      UPORTS_DEPENDENCIES=none $$targets;,                             \
    $(MAKE) -s --no-print-directory                                    \
      DEPENDENCY_REQUESTS="$$targets" DEPENDENCY_REQUEST=              \
      project-dependency-snapshot > "$$invocation_dir/metadata";       \
    $(if $(filter yes,$(UPORTS_DEPENDENCIES)),                         \
    $(MAKE) --no-print-directory UPORTS_DEPENDENCY_INVOCATION=yes      \
      DEPENDENCY_METADATA_SOURCE="$$invocation_dir/metadata"           \
      DEPENDENCY_CONTEXT_ROOT="$$invocation_dir/context"               \
      DEPENDENCY_REQUESTS="$$targets" DEPENDENCY_REQUEST=              \
      dependency-lifecycle-execute;)                                   \
    $(MAKE) --no-print-directory UPORTS_DEPENDENCY_INVOCATION=yes      \
      DEPENDENCY_METADATA_SOURCE="$$invocation_dir/metadata"           \
      DEPENDENCY_CONTEXT_ROOT="$$invocation_dir/context"               \
      DEPENDENCY_REQUESTS= DEPENDENCY_REQUEST=                         \
      UPORTS_DEPENDENCIES=no $$targets;)                               \
fi
endef

ifeq ($(strip $(filter yes,                                            \
  $(UPORTS_DEPENDENCY_INVOCATION) $(_UPORTS_PROJECT_DIRECT))),)
flavor-mixed-goals	=
project_lifecycle_goals	:= $(filter $(addprefix %.,                    \
	$(suffix_all_lists) flavor-check),$(MAKECMDGOALS))

# $(call generate-project-lifecycle, requested-target)
define generate-project-lifecycle
.PHONY: $(call flavor-target-escape,$1)
$(call flavor-target-escape,$1): uports-force
	$$(if $$(strip $$(FLAVOR)),                                    \
	  $$(error Use port@flavor.phase, not global FLAVOR))
	@$$(call project-lifecycle-command,$1)
endef

$(foreach t,$(project_lifecycle_goals),                                \
  $(if $(or $(call project-goal-aggregate,$t),                         \
    $(call project-root-origins,$(basename $t))),                      \
    $(eval $(call generate-project-lifecycle,$t))))
else
# The validated union may contain both a recipe's default and extra Flavors.
flavor-mixed-goals	=
endif
endif
