# uports dependency metadata, resolution, validation, and execution.
# Included by Tools/tools.mk after normalized build-instance records exist.

#
# normalized dependency records...
#
# Dependency collection is deliberately opt-in during this read-only phase.
# It is enabled by the dependency diagnostics below, avoiding recursive port
# metadata probes during ordinary planner startup.

dependency-instance-key = $(call instance-key,$(call get-group,$1),$(call get-port,$1))
dependency-instance-directory = $(call instance-field,$(call dependency-instance-key,$1),root)/$(call instance-field,$(call dependency-instance-key,$1),origin)

VERTICAL_BAR := |
DEPENDENCY_METADATA_JOBS ?= 4
DEPENDENCY_PROVIDER_POLICIES ?=
DEPENDENCY_EXTERNAL_PROVIDERS ?= no
ifneq ($(filter $(DEPENDENCY_EXTERNAL_PROVIDERS),yes no),$(DEPENDENCY_EXTERNAL_PROVIDERS))
$(error DEPENDENCY_EXTERNAL_PROVIDERS must be yes or no)
endif
DEPENDENCY_BUILD_OPSYS ?= $(info_ports_opsys)
DEPENDENCY_BUILD_ARCH ?= $(info_ports_arch)
DEPENDENCY_TARGET_OPSYS ?= $(DEPENDENCY_BUILD_OPSYS)
DEPENDENCY_TARGET_ARCH ?= $(DEPENDENCY_BUILD_ARCH)

dependency-policy-field = $(word $1,$(subst $(AT), ,$2))
dependency-policy-origin-key = $(subst /,_,$1)
dependency-policy-validator = DEPENDENCY_PROVIDER_CHECK.$(call dependency-policy-field,7,$1).$(call dependency-policy-origin-key,$(call dependency-policy-field,6,$1))
dependency-policy-readiness-check = DEPENDENCY_PROVIDER_READY_$(1).$(call dependency-policy-field,7,$2).$(call dependency-policy-origin-key,$(call dependency-policy-field,6,$2))
dependency-policy-readiness-probe = $(if $(strip $($(call dependency-policy-readiness-check,$1,$2))),if { $($(call dependency-policy-readiness-check,$1,$2)); } >/dev/null 2>&1; then printf '%s\n' 'readiness|$(call dependency-policy-field,7,$2)|$(call dependency-policy-field,6,$2)|$1|ready'; else printf '%s\n' 'readiness|$(call dependency-policy-field,7,$2)|$(call dependency-policy-field,6,$2)|$1|missing'; fi;,printf '%s\n' 'readiness|$(call dependency-policy-field,7,$2)|$(call dependency-policy-field,6,$2)|$1|unspecified';)
dependency-provider-value = $(DEPENDENCY_PROVIDER_$1.$(call dependency-policy-field,7,$2).$(call dependency-policy-origin-key,$(call dependency-policy-field,6,$2)))
dependency-projection-field = $(word $1,$(subst $(VERTICAL_BAR), ,$2))
dependency-record-context = $(if $(filter build,$($1_type)),build,target)
dependency-record-opsys = $(strip $(if $(filter build,$(call dependency-record-context,$1)),\
	$(DEPENDENCY_BUILD_OPSYS),$(or $(DEPENDENCY_TARGET_OPSYS.$(call instance-field,$($1_consumer),group)),$(DEPENDENCY_TARGET_OPSYS))))
dependency-record-arch = $(strip $(if $(filter build,$(call dependency-record-context,$1)),\
	$(DEPENDENCY_BUILD_ARCH),$(or $(DEPENDENCY_TARGET_ARCH.$(call instance-field,$($1_consumer),group)),$(DEPENDENCY_TARGET_ARCH))))

define apply-dependency-provider-projection
  $(eval projection_record := $(call dependency-projection-field,2,$1))
  $(eval $(projection_record)_provider_kind := $(call dependency-projection-field,3,$1))
  $(eval $(projection_record)_provider_identity := $(call dependency-projection-field,4,$1))
  $(eval $(projection_record)_provider_context := $(call dependency-projection-field,5,$1))
  $(eval $(projection_record)_provider_opsys := $(call dependency-projection-field,6,$1))
  $(eval $(projection_record)_provider_arch := $(call dependency-projection-field,7,$1))
  $(eval $(projection_record)_provider_instance :=)
  $(eval $(projection_record)_resolution := selected)
endef

define dependency-provider-readiness-input
  $(dependency-provider-selection-input) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(call dependency-policy-readiness-probe,HEADER,$p)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(call dependency-policy-readiness-probe,LIBRARY,$p)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(call dependency-policy-readiness-probe,METADATA,$p)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(call dependency-policy-readiness-probe,TOOL,$p))
endef

define dependency-provider-policy-input
  $(foreach g,$(groups_all),printf '%s\n' 'group|$g';) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),printf '%s\n' 'policy|$p';)
endef

define dependency-provider-selection-input
  $(foreach g,$(groups_all),printf '%s\n' 'context|build|$g|$(DEPENDENCY_BUILD_OPSYS)|$(DEPENDENCY_BUILD_ARCH)';) \
  $(foreach g,$(groups_all),printf '%s\n' 'context|target|$g|$(or $(DEPENDENCY_TARGET_OPSYS.$g),$(DEPENDENCY_TARGET_OPSYS))|$(or $(DEPENDENCY_TARGET_ARCH.$g),$(DEPENDENCY_TARGET_ARCH))';) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),printf '%s\n' 'policy|$p';) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(if $(strip $($(call dependency-policy-validator,$p))),if { $($(call dependency-policy-validator,$p)); } >/dev/null 2>&1; then printf '%s\n' 'validation|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|valid'; else printf '%s\n' 'validation|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|failed'; fi;,printf '%s\n' 'validation|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|missing';)) \
  $(foreach d,$(dependency_record_ids),printf '%s\n' 'dependency|$d|$($(d)_consumer)|$(call instance-field,$($(d)_consumer),group)|$($(d)_type)|$($(d)_requirement)|$($(d)_origin)|$($(d)_provider_kind)|$($(d)_provider_instance)|$($(d)_resolution)';)
endef

define dependency-provider-environment-input
  $(dependency-provider-selection-input) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(foreach v,$(call dependency-provider-value,BINDIRS,$p),printf '%s\n' 'contribution|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|bindir|$v';)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(foreach v,$(call dependency-provider-value,INCLUDEDIRS,$p),printf '%s\n' 'contribution|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|includedir|$v';)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(foreach v,$(call dependency-provider-value,LIBDIRS,$p),printf '%s\n' 'contribution|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|libdir|$v';)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(foreach v,$(call dependency-provider-value,PKGCONFIGDIRS,$p),printf '%s\n' 'contribution|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|pkgconfigdir|$v';)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(foreach v,$(call dependency-provider-value,RUNTIMEDIRS,$p),printf '%s\n' 'contribution|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|runtimedir|$v';)) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),$(foreach v,$(call dependency-provider-value,SYSROOT,$p),printf '%s\n' 'contribution|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|sysroot|$v';))
endef

define generate-dependency-metadata-probe
dependency_metadata_probe_targets += dependency-metadata-probe-$(call dependency-instance-key,$1)
.PHONY: dependency-metadata-probe-$(call dependency-instance-key,$1)
dependency-metadata-probe-$(call dependency-instance-key,$1):
	@$$(MAKE) -s -C "$(call dependency-instance-directory,$1)" 	\
	  --no-print-directory PORTSDIR="$(portdir)" 			\
	  $(call instance-field,$(call dependency-instance-key,$1),env) \
	  uports-dependency-metadata					\
	  > "$$(DEPENDENCY_METADATA_DIR)/$(call dependency-instance-key,$1).raw" 2>/dev/null
	@sed -e 's#^#$(call dependency-instance-key,$1)$(VERTICAL_BAR)#' \
	  < "$$(DEPENDENCY_METADATA_DIR)/$(call dependency-instance-key,$1).raw" \
	  > "$$(DEPENDENCY_METADATA_DIR)/$(call dependency-instance-key,$1)"
endef

$(foreach p,$(ports_all_group),					\
  $(eval $(call generate-dependency-metadata-probe,$p)))

.PHONY: dependency-metadata-probes
depends_exclude_targets += dependency-metadata-probes $(dependency_metadata_probe_targets)
dependency-metadata-probes: $(dependency_metadata_probe_targets)

dependency-metadata-command = 						\
	metadata_dir=$$(mktemp -d "$${TMPDIR:-/tmp}/uports-dependencies.XXXXXX") && \
	$(MAKE) -s --no-print-directory -j$(DEPENDENCY_METADATA_JOBS) 	\
	  DEPENDENCY_METADATA_DIR="$$metadata_dir" dependency-metadata-probes \
	  >/dev/null &&							\
	$(if $(strip $(ports_all_group)),cat $(foreach p,$(ports_all_group),\
	  "$$metadata_dir/$(call dependency-instance-key,$p)"),:);	\
	status=$$?;							\
	case "$$metadata_dir" in					\
	  "$${TMPDIR:-/tmp}"/uports-dependencies.*)			\
	    find "$$metadata_dir" -type f -delete;			\
	    rmdir "$$metadata_dir";;					\
	esac;								\
	exit $$status

dependency_metadata_raw =

# $(call collect-dependency-capability, provider-key|provides|origin)
define collect-dependency-capability
  $(eval dependency_capability_words := $(subst $(VERTICAL_BAR), ,$1))
  $(eval dependency_capabilities_$(word 1,$(dependency_capability_words)) += $(word 3,$(dependency_capability_words)))
endef

# $(call dependency-provider-candidates, origin)
dependency-provider-candidates = $(filter %$(AT)$1,$(ports_all_group))

# $(call dependency-capability-candidates, origin)
dependency-capability-candidates = $(strip				\
	$(foreach p,$(ports_all_group),					\
	  $(if $(filter $1,$(dependency_capabilities_$(call dependency-instance-key,$p))),$p)))

# $(call dependency-all-provider-candidates, origin)
dependency-all-provider-candidates = $(sort				\
	$(call dependency-provider-candidates,$1)			\
	$(call dependency-capability-candidates,$1))

# $(call select-dependency-provider, consumer-group, origin)
# Prefer an exact provider in the consumer's group, then one capability provider
# there.  Otherwise accept only one exact/capability provider globally.
select-dependency-provider = $(strip					\
	$(if $(filter $1$(AT)$2,$(ports_all_group)),$1$(AT)$2,		\
	  $(if $(filter 1,$(words $(filter $1$(AT)%,$(call dependency-capability-candidates,$2)))),\
	    $(filter $1$(AT)%,$(call dependency-capability-candidates,$2)),	\
	    $(if $(filter 0,$(words $(filter $1$(AT)%,$(call dependency-capability-candidates,$2)))),\
	      $(if $(filter 1,$(words $(call dependency-all-provider-candidates,$2))),\
	        $(call dependency-all-provider-candidates,$2))))))

# $(call generate-dependency-record, consumer-key|type|requirement:origin[:target])
define generate-dependency-record
  $(eval dependency_record_id := dependency$(words x $(dependency_record_ids)))
  $(eval dependency_record_ids += $(dependency_record_id))
  $(eval dependency_words := $(subst $(VERTICAL_BAR), ,$1))
  $(eval dependency_entry := $(word 3,$(dependency_words)))
  $(eval dependency_parts := $(subst :, ,$(dependency_entry)))
  $(eval dependency_consumer := $(word 1,$(dependency_words)))
  $(eval dependency_type := $(word 2,$(dependency_words)))
  $(eval dependency_requirement := $(if $(filter :%,$(dependency_entry)),,$(word 1,$(dependency_parts))))
  $(eval dependency_origin := $(if $(filter :%,$(dependency_entry)),$(word 1,$(dependency_parts)),$(word 2,$(dependency_parts))))
  $(eval dependency_provider := $(call select-dependency-provider,$(call instance-field,$(dependency_consumer),group),$(dependency_origin)))
  $(eval $(dependency_record_id)_consumer := $(dependency_consumer))
  $(eval $(dependency_record_id)_type := $(dependency_type))
  $(eval $(dependency_record_id)_requirement := $(dependency_requirement))
  $(eval $(dependency_record_id)_origin := $(dependency_origin))
  $(eval $(dependency_record_id)_target := $(wordlist 3,$(words $(dependency_parts)),$(dependency_parts)))
  $(eval $(dependency_record_id)_provider_kind := $(if $(or $(filter $(dependency_origin),$(ports_all_raw_lists)),$(call dependency-capability-candidates,$(dependency_origin))),uports,unresolved))
  $(eval $(dependency_record_id)_provider_instance := $(if $(dependency_provider),$(call instance-key,$(call get-group,$(dependency_provider)),$(call get-port,$(dependency_provider))),))
  $(eval $(dependency_record_id)_resolution := $(if $(dependency_provider),selected,$(if $(or $(filter $(dependency_origin),$(ports_all_raw_lists)),$(call dependency-capability-candidates,$(dependency_origin))),$(if $(call dependency-all-provider-candidates,$(dependency_origin)),ambiguous,unselected),unknown-origin)))
endef

# Load records only when a dependency diagnostic recipe is expanded.  GNU make
# cannot reliably run recursive makes from a parse-time shell function, and
# ordinary planner targets must not pay this metadata cost.
load-dependency-records = 						\
	$(eval dependency_metadata_raw := $(shell $(dependency-metadata-command))) \
	$(if $(filter-out 0,$(.SHELLSTATUS)),				\
	  $(error dependency metadata collection failed),)		\
	$(foreach d,$(dependency_metadata_raw),				\
	  $(if $(filter provides,$(word 2,$(subst $(VERTICAL_BAR), ,$d))),\
	    $(call collect-dependency-capability,$d)))			\
	$(foreach d,$(dependency_metadata_raw),				\
	  $(if $(filter build lib run,$(word 2,$(subst $(VERTICAL_BAR), ,$d))),\
	    $(call generate-dependency-record,$d)))			\
	$(if $(filter yes,$(DEPENDENCY_EXTERNAL_PROVIDERS)),		\
	  $(eval dependency_policy_result := $(shell { $(dependency-provider-policy-input) :; } | awk -v fail=1 -f "$(portdir)/Tools/dependency-provider-policy.awk" >/dev/null))\
	  $(if $(filter-out 0,$(.SHELLSTATUS)),$(error dependency provider policy validation failed))\
	  $(eval dependency_provider_projection := $(shell { $(dependency-provider-selection-input) :; } | awk -v records=1 -f "$(portdir)/Tools/dependency-provider-selection.awk"))\
	  $(foreach p,$(dependency_provider_projection),		\
	    $(if $(filter invalid%,$p),$(error dependency provider validation failed: $p),\
	      $(call apply-dependency-provider-projection,$p))))

dependency-graph-record-ids = $(foreach d,$(dependency_record_ids),\
	$(if $(and $(filter selected,$($(d)_resolution)),$(filter uports,$($(d)_provider_kind))),$d))
dependency-unresolved-record-ids = $(foreach d,$(dependency_record_ids),\
	$(if $(filter-out selected,$($(d)_resolution)),$d))
dependency-external-record-ids = $(foreach d,$(dependency_record_ids),\
	$(if $(filter system sdk,$($(d)_provider_kind)),$d))
dependency-external-preflight = $(if $(filter yes,$(DEPENDENCY_EXTERNAL_PROVIDERS)),\
	{ $(dependency-provider-environment-input) :; } | \
	  awk -v environment=1 -v external_only=1 -v preflight=1 -v fail=1 \
	    -f "$(portdir)/Tools/dependency-provider-selection.awk" >/dev/null &&)

define dependency-graph-input
  $(foreach p,$(ports_all_group),				\
    printf '%s\n' '$(call instance-key,$(call get-group,$p),$(call get-port,$p))';) \
  $(foreach d,$(dependency-graph-record-ids),			\
    printf '%s\n' '$($(d)_consumer)|$($(d)_provider_instance)';)
endef

define dependency-execution-input
  $(foreach p,$(ports_all_group),				\
    printf '%s\n' 'node|$(call instance-key,$(call get-group,$p),$(call get-port,$p))|$(call instance-field,$(call instance-key,$(call get-group,$p),$(call get-port,$p)),group)|$(call instance-field,$(call instance-key,$(call get-group,$p),$(call get-port,$p)),origin)|$(call instance-field,$(call instance-key,$(call get-group,$p),$(call get-port,$p)),env)';) \
  $(foreach d,$(dependency_record_ids),			\
    printf '%s\n' 'dependency|$($(d)_consumer)|$($(d)_provider_instance)|$($(d)_type)|$(if $($(d)_provider_instance),$(call dependency-lifecycle-provider-target,$d))|$(call dependency-lifecycle-provider-suffix,$d)|$($(d)_resolution)|$($(d)_requirement)|$($(d)_origin)|$($(d)_provider_kind)|$($(d)_provider_identity)|$(or $($(d)_provider_context),$(call dependency-record-context,$d))|$(or $($(d)_provider_opsys),$(call dependency-record-opsys,$d))|$(or $($(d)_provider_arch),$(call dependency-record-arch,$d))';) \
  $(foreach p,$(DEPENDENCY_PROVIDER_POLICIES),		\
    printf '%s\n' 'external-environment|$(call dependency-policy-field,7,$p)|$(call dependency-policy-field,6,$p)|$(call dependency-provider-value,BINDIRS,$p)|$(call dependency-provider-value,INCLUDEDIRS,$p)|$(call dependency-provider-value,LIBDIRS,$p)|$(call dependency-provider-value,PKGCONFIGDIRS,$p)|$(call dependency-provider-value,RUNTIMEDIRS,$p)|$(call dependency-provider-value,SYSROOT,$p)';) \
  $(foreach r,$(dependency-request-targets),			\
    printf '%s\n' 'request|$(call target-instance-key,$r)|$(call extract-suffix,$(call rm-group,$r))';)
endef

define dependency-project-execution-input
  $(foreach p,$(ports_all_group),				\
    printf '%s\n' '$(call instance-key,$(call get-group,$p),$(call get-port,$p))';) \
  $(foreach d,$(dependency-lifecycle-record-ids),		\
    printf '%s\n' '$($(d)_consumer)|$($(d)_provider_instance)|$(call dependency-lifecycle-provider-target,$d)';)
endef

# Dependency records keep logical instance keys.  Lifecycle prerequisites use
# canonical wrapper targets so group selection remains explicit and aliases are
# never involved in execution planning.
# $(call dependency-instance-target, instance-key, suffix)
dependency-instance-target = $(call instance-field,$1,group)$(AT)$(call instance-field,$1,port).$2

# Build and library dependencies are needed by the consumer's configure stage;
# runtime dependencies are needed by its stage/install flow.
dependency-lifecycle-consumer-suffix = $(if $(filter run,$($1_type)),stage,configure)
dependency-lifecycle-provider-suffix = $(if $($1_target),$($1_target),install)
dependency-lifecycle-provider-suffixes = fetch extract patch configure build \
	stage package install
dependency-lifecycle-record-ids = $(dependency-graph-record-ids)
dependency-lifecycle-invalid-target-ids = $(foreach d,$(dependency-lifecycle-record-ids),\
	$(if $(filter-out $(dependency-lifecycle-provider-suffixes),$(call dependency-lifecycle-provider-suffix,$d)),$d))

define dependency-unresolved-diagnostics
  $(foreach d,$(dependency-unresolved-record-ids),			\
    echo "unresolved.$d = consumer=$($(d)_consumer) type=$($(d)_type) origin=$($(d)_origin) resolution=$($(d)_resolution)";)
endef

# $(call dependency-lifecycle-consumer-target, dependency-record-id)
dependency-lifecycle-consumer-target = $(call dependency-instance-target,\
	$($1_consumer),$(call dependency-lifecycle-consumer-suffix,$1))
# $(call dependency-lifecycle-provider-target, dependency-record-id)
dependency-lifecycle-provider-target = $(call dependency-instance-target,\
	$($1_provider_instance),$(call dependency-lifecycle-provider-suffix,$1))

UPORTS_DEPENDENCIES	?= no
ifneq ($(filter $(UPORTS_DEPENDENCIES),yes no),$(UPORTS_DEPENDENCIES))
$(error UPORTS_DEPENDENCIES must be yes or no)
endif
UPORTS_DEPENDENCY_STATE ?= $(UPORTS_DEPENDENCIES)
ifneq ($(filter $(UPORTS_DEPENDENCY_STATE),yes no),$(UPORTS_DEPENDENCY_STATE))
$(error UPORTS_DEPENDENCY_STATE must be yes or no)
endif

dependency-state-class = $(if $(filter configure build rebuild,$1),configure,\
	$(if $(filter stage package install restage reinstall generate-plist,$1),stage))
dependency-dispatch-state-class = $(strip $(call dependency-state-class,\
	$(call extract-suffix,$(call rm-group,$(resolved-port-target)))))

dependency-dispatch-command = $(if $(filter yes,$(UPORTS_DEPENDENCIES)),\
	$(MAKE) --no-print-directory DEPENDENCY_REQUEST='$(resolved-port-target)' \
	  dependency-lifecycle-execute &&)
dependency-consumer-environment-command = $(if $(filter yes,$(DEPENDENCY_EXTERNAL_PROVIDERS)),\
	environment_file=$$(mktemp "$${TMPDIR:-/tmp}/uports-provider-env.XXXXXX"); \
	$(MAKE) -s --no-print-directory \
	  DEPENDENCY_REQUEST='$(resolved-port-target)' \
	  dependency-provider-environment-export > "$$environment_file"; \
	. "$$environment_file";)
dependency-consumer-provenance-command = $(if $(and \
	$(filter yes,$(UPORTS_DEPENDENCIES)),\
	$(filter package,$(call extract-suffix,$(call rm-group,$(resolved-port-target))))),\
	provenance_file=$$(mktemp "$${TMPDIR:-/tmp}/uports-provider-provenance.XXXXXX"); \
	$(MAKE) -s --no-print-directory \
	  DEPENDENCY_REQUEST='$(resolved-port-target)' \
	  dependency-provider-provenance > "$$provenance_file"; \
	export UPORTS_DEPENDENCY_PROVENANCE_FILE="$$provenance_file";)
dependency-consumer-cleanup-command = $(if $(or \
	$(filter yes,$(DEPENDENCY_EXTERNAL_PROVIDERS)),\
	$(and $(filter yes,$(UPORTS_DEPENDENCIES)),\
	  $(filter package,$(call extract-suffix,$(call rm-group,$(resolved-port-target)))))),\
	trap 'rm -f $${environment_file:+"$$environment_file"} $${provenance_file:+"$$provenance_file"}' EXIT HUP INT TERM;)
dependency-state-invalidate-command = $(if $(and \
	$(filter yes,$(UPORTS_DEPENDENCY_STATE)),\
	$(dependency-dispatch-state-class)),\
	$(MAKE) --no-print-directory DEPENDENCY_REQUEST='$(resolved-port-target)' \
	  dependency-state-invalidate >/dev/null &&)
dependency-state-save-command = $(if $(and \
	$(filter yes,$(UPORTS_DEPENDENCY_STATE)),\
	$(dependency-dispatch-state-class)),\
	$(MAKE) --no-print-directory DEPENDENCY_REQUEST='$(resolved-port-target)' \
	  dependency-state-save >/dev/null &&)

.PHONY: dependencies-list
depends_exclude_targets	+= dependencies-list
dependencies-list: info.debug.dependencies

.PHONY: dependency-provider-policy-list dependency-provider-policy-check \
	dependency-provider-selection-list dependency-provider-selection-check \
	dependency-provider-readiness-list dependency-provider-readiness-check \
	dependency-provider-environment-list dependency-provider-environment-check \
	dependency-provider-environment-export dependency-provider-environment-run
depends_exclude_targets += dependency-provider-policy-list \
	dependency-provider-policy-check dependency-provider-selection-list \
	dependency-provider-selection-check dependency-provider-environment-list \
	dependency-provider-readiness-list dependency-provider-readiness-check \
	dependency-provider-environment-check \
	dependency-provider-environment-export dependency-provider-environment-run
dependency-provider-policy-list:
	@{ $(dependency-provider-policy-input) :; } | \
	  awk -v fail=0 -f "$(portdir)/Tools/dependency-provider-policy.awk"

dependency-provider-policy-check:
	@{ $(dependency-provider-policy-input) :; } | \
	  awk -v fail=1 -f "$(portdir)/Tools/dependency-provider-policy.awk"

dependency-provider-selection-list:
	@$(load-dependency-records)
	@{ $(dependency-provider-selection-input) :; } | \
	  awk -v fail=0 -f "$(portdir)/Tools/dependency-provider-selection.awk"

dependency-provider-selection-check: dependency-provider-policy-check
	@$(load-dependency-records)
	@{ $(dependency-provider-selection-input) :; } | \
	  awk -v fail=1 -f "$(portdir)/Tools/dependency-provider-selection.awk"

dependency-provider-readiness-list:
	@$(load-dependency-records)
	@{ $(dependency-provider-readiness-input) :; } | \
	  awk -v readiness_report=1 -v fail=0 \
	    -f "$(portdir)/Tools/dependency-provider-selection.awk"

dependency-provider-readiness-check: dependency-provider-policy-check
	@$(load-dependency-records)
	@{ $(dependency-provider-readiness-input) :; } | \
	  awk -v readiness_report=1 -v fail=1 \
	    -f "$(portdir)/Tools/dependency-provider-selection.awk"

dependency-provider-environment-list:
	@$(load-dependency-records)
	@{ $(dependency-provider-environment-input) :; } | \
	  awk -v environment=1 -v fail=0 \
	    -f "$(portdir)/Tools/dependency-provider-selection.awk"

dependency-provider-environment-check: dependency-provider-policy-check
	@$(load-dependency-records)
	@{ $(dependency-provider-environment-input) :; } | \
	  awk -v environment=1 -v fail=1 \
	    -f "$(portdir)/Tools/dependency-provider-selection.awk"

dependency-provider-export-awk = awk -v environment=1 -v exports=1 \
	-v fail=1 -v export_node="$(dependency-request-instance)" \
	-v export_phase="$(dependency-request-phase)" \
	-v build_opsys="$(DEPENDENCY_BUILD_OPSYS)" \
	-v build_arch="$(DEPENDENCY_BUILD_ARCH)" \
	-f "$(portdir)/Tools/dependency-provider-selection.awk"

dependency-provider-environment-export:
	@$(load-dependency-records)
	@if test "$(DEPENDENCY_EXTERNAL_PROVIDERS)" != yes || \
	    test "$(words $(dependency-requests))" -ne 1 || \
	    test -n "$(dependency-invalid-requests)"; then \
	  echo "external provider export requires opt-in and one valid request" >&2; \
	  exit 1; \
	fi
	@{ $(dependency-provider-environment-input) :; } | \
	  $(dependency-provider-export-awk)

dependency-provider-environment-run:
	@$(load-dependency-records)
	@if test "$(DEPENDENCY_EXTERNAL_PROVIDERS)" != yes || \
	    test "$(words $(dependency-requests))" -ne 1 || \
	    test -n "$(dependency-invalid-requests)" || \
	    test -z "$(strip $(DEPENDENCY_ENVIRONMENT_COMMAND))"; then \
	  echo "external provider runner requires opt-in, one valid request, and DEPENDENCY_ENVIRONMENT_COMMAND" >&2; \
	  exit 1; \
	fi
	@set -e; environment_file=$$(mktemp "$${TMPDIR:-/tmp}/uports-provider-env.XXXXXX"); \
	  trap 'rm -f "$$environment_file"' EXIT HUP INT TERM; \
	  { $(dependency-provider-environment-input) :; } | \
	    $(dependency-provider-export-awk) > "$$environment_file"; \
	  . "$$environment_file"; \
	  $(DEPENDENCY_ENVIRONMENT_COMMAND)

.PHONY: dependency-graph-list dependency-order-list dependency-lifecycle-list \
	dependency-lifecycle-check dependency-execution-plan \
	dependency-execution-state dependency-provider-provenance \
	dependency-state-check dependency-state-save dependency-state-invalidate \
	dependency-lifecycle-execute dependencies-check
depends_exclude_targets	+= dependency-graph-list dependency-order-list \
			   dependency-lifecycle-list \
			   dependency-lifecycle-check dependency-execution-plan \
			   dependency-execution-state dependency-provider-provenance \
			   dependency-state-check dependency-state-save \
			   dependency-state-invalidate \
			   dependency-lifecycle-execute dependencies-check
dependency-graph-list: info.debug.dependency-graph
dependency-order-list: info.debug.dependency-order
dependency-lifecycle-list: info.debug.dependency-lifecycle

dependencies-check:
	@$(load-dependency-records)
	@if test "$(words $(dependency-unresolved-record-ids))" -ne 0; then \
	  echo "unresolved_dependencies = $(words $(dependency-unresolved-record-ids))"; \
	  $(dependency-unresolved-diagnostics) \
	  exit 1; \
	fi
	@{ $(dependency-graph-input) :; } | \
	  awk -v fail=1 -f "$(portdir)/Tools/dependency-graph.awk"

dependency-lifecycle-check:
	@$(load-dependency-records)
	@if test "$(words $(dependency-unresolved-record-ids))" -ne 0; then \
	  echo "unresolved_dependencies = $(words $(dependency-unresolved-record-ids))"; \
	  exit 1; \
	fi
	@if test "$(words $(dependency-lifecycle-invalid-target-ids))" -ne 0; then \
	  echo "invalid_dependency_targets = $(words $(dependency-lifecycle-invalid-target-ids))"; \
	  exit 1; \
	fi
	@{ $(dependency-graph-input) :; } | \
	  awk -v fail=1 -f "$(portdir)/Tools/dependency-graph.awk"

# Keep execution opt-in while the dependency-aware canonical target behavior is
# evaluated.  Tests may replace this command with a recorder.
DEPENDENCY_EXECUTE_COMMAND ?= $(MAKE) --no-print-directory -j1 \
	UPORTS_DEPENDENCIES=no $(if $(filter yes,$(DEPENDENCY_EXTERNAL_PROVIDERS)),UPORTS_DEPENDENCY_STATE=yes)

dependency-requests = $(strip $(if $(DEPENDENCY_REQUESTS),$(DEPENDENCY_REQUESTS),$(DEPENDENCY_REQUEST)))
dependency-request-targets = $(foreach r,$(dependency-requests),$(call resolve-port-target,$r))
dependency-request-target = $(firstword $(dependency-request-targets))
dependency-request-instance = $(call target-instance-key,$(dependency-request-target))
dependency-request-phase = $(call extract-suffix,$(call rm-group,$(dependency-request-target)))
dependency-invalid-requests = $(strip $(foreach r,$(dependency-requests),\
	$(if $(call resolve-port-target,$r),,$r)))

dependency-execution-plan:
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@if test -z "$(dependency-requests)" || \
	    test -n "$(dependency-invalid-requests)"; then \
	  echo "invalid dependency execution request: $(dependency-invalid-requests)" >&2; \
	  exit 1; \
	fi
	@{ $(dependency-execution-input) :; } | \
	  awk -v inspect=1 -f "$(portdir)/Tools/dependency-execution.awk"

dependency-execution-state:
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@if test -z "$(dependency-requests)" || \
	    test -n "$(dependency-invalid-requests)"; then \
	  echo "invalid dependency execution request: $(dependency-invalid-requests)" >&2; \
	  exit 1; \
	fi
	@{ $(dependency-execution-input) :; } | \
	  awk -v state=1 -f "$(portdir)/Tools/dependency-execution.awk"

dependency-provider-provenance:
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@if test -z "$(dependency-requests)" || \
	    test -n "$(dependency-invalid-requests)"; then \
	  echo "invalid dependency provenance request: $(dependency-invalid-requests)" >&2; \
	  exit 1; \
	fi
	@{ $(dependency-execution-input) :; } | \
	  awk -v provenance=1 -f "$(portdir)/Tools/dependency-execution.awk"

define dependency-state-operation
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@if test "$(words $(dependency-requests))" -ne 1 || \
	    test -n "$(dependency-invalid-requests)" || \
	    test -z "$(call dependency-state-class,$(dependency-request-phase))"; then \
	  echo "invalid dependency state request: $(dependency-requests)" >&2; \
	  exit 1; \
	fi
	@state_file=$$(mktemp "$${TMPDIR:-/tmp}/uports-dependency-state.XXXXXX"); \
	trap 'rm -f "$$state_file"' EXIT HUP INT TERM; \
	{ $(dependency-execution-input) :; } | \
	  awk -v state=1 -f "$(portdir)/Tools/dependency-execution.awk" \
	  > "$$state_file"; \
	dir="$(call target-instance-field,$(dependency-request-target),root)"; \
	category="$(call target-instance-field,$(dependency-request-target),category)"; \
	port="$(call target-instance-field,$(dependency-request-target),port)"; \
	envs="$(call get-envs,$(dependency-request-target))"; \
	$(MAKE) -s -C "$$dir/$$category/$$port" --no-print-directory \
	  $$envs \
	  DEPENDENCY_STATE_CLASS="$(call dependency-state-class,$(dependency-request-phase))" \
	  DEPENDENCY_STATE_SOURCE="$$state_file" \
	  uports-dependency-state-$1
endef

dependency-state-check:
	$(call dependency-state-operation,check)

dependency-state-save:
	$(call dependency-state-operation,save)

dependency-state-invalidate:
	$(call dependency-state-operation,invalidate)

dependency-lifecycle-execute:
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@if test -n "$(dependency-requests)" && \
	    test -n "$(dependency-invalid-requests)"; then \
	  echo "invalid dependency execution request: $(dependency-invalid-requests)" >&2; \
	  exit 1; \
	fi
	@if test "$(words $(dependency-unresolved-record-ids))" -ne 0; then \
	  if test -z "$(dependency-requests)"; then \
	    echo "unresolved_dependencies = $(words $(dependency-unresolved-record-ids))"; \
	    exit 1; \
	  fi; \
	fi
	@if test "$(words $(dependency-lifecycle-invalid-target-ids))" -ne 0; then \
	  if test -z "$(dependency-requests)"; then \
	    echo "invalid_dependency_targets = $(words $(dependency-lifecycle-invalid-target-ids))"; \
	    exit 1; \
	  fi; \
	fi
	@if test -z "$(dependency-requests)"; then \
	  { $(dependency-graph-input) :; } | \
	    awk -v fail=1 -f "$(portdir)/Tools/dependency-graph.awk" >/dev/null; \
	fi
	@targets="$$( if test -n "$(dependency-requests)"; then \
	    { $(dependency-execution-input) :; } | \
	      awk -f "$(portdir)/Tools/dependency-execution.awk"; \
	  else \
	    { $(dependency-project-execution-input) :; } | \
	      awk -v raw_targets=1 -v fail=1 \
	        -f "$(portdir)/Tools/dependency-graph.awk"; \
	  fi )"; \
	  if test -n "$$targets"; then \
	    $(DEPENDENCY_EXECUTE_COMMAND) $$targets; \
	  fi

info.debug.dependencies:
	@$(load-dependency-records)
	@$(echo) "dependency_records = $(words $(dependency_record_ids))"
	@$(foreach d,$(dependency_record_ids),				\
	  echo "$(d) = consumer=$($(d)_consumer) type=$($(d)_type) requirement=$($(d)_requirement) origin=$($(d)_origin) provider_kind=$($(d)_provider_kind) provider_instance=$(if $($(d)_provider_instance),$($(d)_provider_instance),none) resolution=$($(d)_resolution)$(if $($(d)_provider_identity), provider_identity=$($(d)_provider_identity))";)

info.debug.dependency-graph:
	@$(load-dependency-records)
	@$(echo) "dependency_graph_nodes = $(words $(ports_all_group))"
	@$(echo) "dependency_graph_edges = $(words $(dependency-graph-record-ids))"
	@$(echo) "dependency_graph_unresolved = $(words $(dependency-unresolved-record-ids))"
	@$(foreach d,$(dependency-graph-record-ids),			\
	  echo "edge.$(d) = consumer=$($(d)_consumer) provider=$($(d)_provider_instance) type=$($(d)_type) origin=$($(d)_origin)";)
	@$(foreach d,$(dependency-unresolved-record-ids),		\
	  echo "unresolved.$(d) = consumer=$($(d)_consumer) type=$($(d)_type) origin=$($(d)_origin) resolution=$($(d)_resolution)";)
	@{ $(dependency-graph-input) :; } | \
	  awk -v fail=0 -f "$(portdir)/Tools/dependency-graph.awk"

info.debug.dependency-order:
	@$(load-dependency-records)
	@$(echo) "dependency_order_nodes = $(words $(ports_all_group))"
	@$(echo) "dependency_order_edges = $(words $(dependency-graph-record-ids))"
	@$(echo) "dependency_order_unresolved = $(words $(dependency-unresolved-record-ids))"
	@{ $(dependency-graph-input) :; } | \
	  awk -v fail=0 -f "$(portdir)/Tools/dependency-graph.awk"

info.debug.dependency-lifecycle:
	@$(load-dependency-records)
	@$(echo) "dependency_lifecycle_prerequisites = $(words $(dependency-lifecycle-record-ids))"
	@$(echo) "dependency_lifecycle_unresolved = $(words $(dependency-unresolved-record-ids))"
	@$(echo) "dependency_lifecycle_invalid_targets = $(words $(dependency-lifecycle-invalid-target-ids))"
	@$(foreach d,$(dependency-lifecycle-record-ids),		\
	  echo "prerequisite.$d = consumer=$(call dependency-lifecycle-consumer-target,$d) provider=$(call dependency-lifecycle-provider-target,$d) type=$($d_type) origin=$($d_origin)";)
