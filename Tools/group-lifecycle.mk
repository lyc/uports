#
# group-lifecycle.mk - group members, provider-first dispatch and cleanup
#

group_cleanup_phases	:= clean distclean deinstall uninstall
group_direct_phases	:= $(group_cleanup_phases) fetch extract patch \
	$(suffix_special_all) flavor-check

# $(call group-goal-aggregate, target)
group-goal-aggregate	= $(filter ports $(groups_all)		       \
	$(categories_all),$(basename $1))

# $(call group-goal-records, target)
define group-goal-records
$(strip $(if $(call group-goal-aggregate,$1),			       \
  $(foreach r,$(group_member_requests),				       \
    $(if $(filter ports $(call group-member-field,1,$r)		       \
      $(firstword $(subst /, ,$(call group-member-field,2,$r))),       \
      $(basename $1)),$r)),					       \
  $(call group-port-records,$(basename $1))))
endef

# $(call group-port-records, [group:]port[@flavor])
define group-port-records
$(call group-member-check,$1)					       \
$(subst $(space),,$(call group-member-record,$1))
endef

# $(call group-selection-records, target)
group-selection-records = $(call group-goal-records,$1)

# $(call group-selection-probe, root-record, target)
define group-selection-probe
: > "$$work/targets";						       \
$(call group-member-probe,$1)					       \
selected=$$(sed -n 's/^selected|//p' "$$work/metadata");	       \
flavors=$$(sed -n 's/^flavors|//p' "$$work/metadata");		       \
$(if $(call group-goal-aggregate,$2),,				       \
  $(if $(call group-member-flavor,$(basename $2)),		       \
    test -n "$$flavors" || selected=;				       \
    test "$$selected" = '$(call group-member-flavor,$(basename $2))'   \
      || selected=;))						       \
if test -n "$$selected"; then					       \
  selections="$$selected";					       \
  $(if $(and $(call group-goal-aggregate,$2),			       \
    $(filter clean distclean,$(call extract-suffix,$2))),	       \
    test -z "$$flavors" || selections="$$flavors";)		       \
  for selected in $$selections; do				       \
  target='$(call group-member-field,1,$1):';			       \
  target="$$target"'$(notdir $(call group-member-field,2,$1))';	       \
  test -z "$$flavors" || target="$$target@$$selected";		       \
  printf '%s.%s\n' "$$target" '$(call extract-suffix,$2)'	       \
    >> "$$work/targets";					       \
  done;								       \
fi;
endef

.PHONY: group-targets-list
depends_exclude_targets	+= group-targets-list
group-targets-list:
	@$(if $(filter 1,$(words $(_UPORTS_GROUP_TARGET))),,	       \
	  $(error Specify one group lifecycle target))
	@$(if $(call group-selection-records,$(_UPORTS_GROUP_TARGET)),,\
	  $(if $(call group-goal-aggregate,$(_UPORTS_GROUP_TARGET)),,  \
	    $(error Unknown package target: $(_UPORTS_GROUP_TARGET))))
	@set -e; directory=$$(mktemp -d				       \
	  "$${TMPDIR:-/tmp}/uports-group-selection.XXXXXX");	       \
	trap 'wait || :; rm -rf "$$directory"' EXIT;		       \
	trap 'exit 1' HUP INT TERM;				       \
	jobs='$(DEPENDENCY_METADATA_JOBS)';			       \
	case "$$jobs" in					       \
	  ''|*[!0-9]*|0)					       \
	    echo 'DEPENDENCY_METADATA_JOBS must be a positive integer' >&2;\
	    exit 1;;						       \
	esac;							       \
	rows=0; active=0; pids=; failed=0;			       \
	$(foreach r,$(call group-selection-records,		       \
	  $(_UPORTS_GROUP_TARGET)),				       \
	  $(call group-member-worker,$r,$(_UPORTS_GROUP_TARGET)))      \
	for pid in $$pids; do					       \
	  wait "$$pid" || failed=1;				       \
	done;							       \
	row=1; : > "$$directory/roots";				       \
	while test "$$row" -le "$$rows"; do			       \
	  cat "$$directory/$$row.errors" >&2;			       \
	  if test "$$failed" = 0; then				       \
	    cat "$$directory/$$row/targets" >> "$$directory/roots";    \
	  fi;							       \
	  row=$$((row + 1));					       \
	done;							       \
	test "$$failed" = 0 || exit 1;				       \
	work="$$directory";					       \
	awk '!seen[$$0]++' "$$work/roots" > "$$work/unique";	       \
	$(if $(call group-goal-aggregate,$(_UPORTS_GROUP_TARGET)),,    \
	  if test "$$(wc -l < "$$work/unique")" -ne 1; then	       \
	    echo 'Select one package with group:port@flavor.phase' >&2;\
	    exit 1;						       \
	  fi;)							       \
	cat "$$work/unique"

# $(call group-lifecycle-command, requested-target)
define group-lifecycle-command
set -e; invocation_dir=$$(mktemp -d				       \
  "$${TMPDIR:-/tmp}/uports-group-invocation.XXXXXX");		       \
trap 'rm -rf "$$invocation_dir"' EXIT HUP INT TERM;		       \
$(MAKE) -s --no-print-directory					       \
  _UPORTS_GROUP_TARGET='$1' group-targets-list			       \
  > "$$invocation_dir/targets";					       \
targets=$$(tr '\n' ' ' < "$$invocation_dir/targets");		       \
if test -n "$$targets"; then					       \
  $(if $(or $(filter $(call extract-suffix,$1),$(group_direct_phases)),\
    $(filter none,$(UPORTS_DEPENDENCIES))),			       \
    $(MAKE) --no-print-directory _UPORTS_GROUP_DIRECT=yes	       \
      DEPENDENCY_REQUESTS= DEPENDENCY_REQUEST=			       \
      UPORTS_DEPENDENCIES=none $$targets;,			       \
    $(MAKE) -s --no-print-directory				       \
      DEPENDENCY_REQUESTS="$$targets" DEPENDENCY_REQUEST=	       \
      group-dependency-snapshot > "$$invocation_dir/metadata";	       \
    $(if $(filter yes,$(UPORTS_DEPENDENCIES)),			       \
    $(MAKE) --no-print-directory UPORTS_DEPENDENCY_INVOCATION=yes      \
      DEPENDENCY_METADATA_SOURCE="$$invocation_dir/metadata"	       \
      DEPENDENCY_CONTEXT_ROOT="$$invocation_dir/context"	       \
      DEPENDENCY_REQUESTS="$$targets" DEPENDENCY_REQUEST=	       \
      dependency-lifecycle-execute;)				       \
    $(MAKE) --no-print-directory UPORTS_DEPENDENCY_INVOCATION=yes      \
      DEPENDENCY_METADATA_SOURCE="$$invocation_dir/metadata"	       \
      DEPENDENCY_CONTEXT_ROOT="$$invocation_dir/context"	       \
      DEPENDENCY_REQUESTS= DEPENDENCY_REQUEST=			       \
      UPORTS_DEPENDENCIES=no $$targets;)			       \
fi
endef

ifeq ($(strip $(filter yes,					       \
  $(UPORTS_DEPENDENCY_INVOCATION) $(_UPORTS_GROUP_DIRECT))),)
flavor-mixed-goals	=
group_lifecycle_goals	:= $(sort $(ports_aggregate_target_unique)     \
	$(filter $(addprefix %.,				       \
	$(suffix_all_lists) flavor-check),$(MAKECMDGOALS)))

# $(call generate-group-lifecycle, requested-target)
define generate-group-lifecycle
.PHONY: $(call flavor-target-escape,$1)
$(call flavor-target-escape,$1): uports-force
	$$(if $$(strip $$(FLAVOR)),				       \
	  $$(error Use port@flavor.phase, not global FLAVOR))
	@$$(call group-lifecycle-command,$1)
endef

$(foreach t,$(group_lifecycle_goals),				       \
  $(if $(or $(call group-goal-aggregate,$t),			       \
    $(call group-member-origins,$(basename $t))),		       \
    $(eval $(call generate-group-lifecycle,$t))))
else
# The validated union may contain both a recipe's default and extra Flavors.
flavor-mixed-goals	=
endif
