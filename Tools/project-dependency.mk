#
# project-dependency.mk - bounded discovery for explicit project roots
#

ifneq ($(origin PROJECT_PORTS),undefined)
PROJECT_PHASE		?= install
ifneq ($(words $(PROJECT_PHASE)),1)
$(error PROJECT_PHASE must name one lifecycle phase)
endif
ifneq ($(filter $(PROJECT_PHASE),$(dependency-lifecycle-provider-suffixes)),$(PROJECT_PHASE))
$(error Unsupported PROJECT_PHASE=$(PROJECT_PHASE))
endif

# $(call project-root-target, root-record)
define project-root-target
$(subst $(space),,$(call project-root-field,1,$1):                     \
  $(notdir $(call project-root-field,2,$1))                            \
  $(if $(call project-root-field,3,$1),                                \
    @$(call project-root-field,3,$1)).$(PROJECT_PHASE))
endef

override DEPENDENCY_REQUESTS := $(foreach r,$(project_root_requests),  \
	$(call project-root-target,$r))
# PROJECT_PORTS selects root Flavors; dependency references select provider
# Flavors. Legacy per-port root selections must not activate unrelated variants.
$(foreach p,$(ports_all_group),                                        \
  $(eval instance_$(call dependency-instance-key,$p)_project_flavor :=))
dependency-scoped-targets += project-dependency-plan                   \
	project-dependency-snapshot

# $(call project-phase-types, lifecycle-phase)
project-phase-types	= $(if $(call dependency-state-class,$1),      \
	build lib)$(if $(filter stage,                                 \
	  $(call dependency-state-class,$1)), run)

# $(call project-record-provider, metadata-record)
define project-record-provider
$(call dependency-reference-instance,                                  \
  $(call dependency-reference-provider,                                \
    $(call instance-field,$(word 1,$(subst |, ,$1)),group),            \
    $(call dependency-metadata-origin,$1)),                            \
  $(call dependency-metadata-origin,$1))
endef

# $(call project-record-phase, metadata-record)
project-record-phase	= $(or $(word 3,                               \
	$(subst :, ,$(word 3,$(subst |, ,$1)))),install)

# $(call project-expand-node, instance-key, lifecycle-phase)
# Only reached references may materialize provider Flavors. Mark before walking
# children so a cycle terminates here and is diagnosed by the graph validator.
define project-expand-node
$(if $(strip $1),                                                      \
  $(if $(filter $(strip $1).$(strip $2),$(project_flavor_visited)),,   \
    $(eval project_flavor_visited += $(strip $1).$(strip $2))          \
    $(foreach d,$(filter $(strip $1)|%,$(dependency_metadata_raw)),    \
      $(if $(filter $(call project-phase-types,$2),                    \
        $(word 2,$(subst |, ,$d))),                                    \
        $(eval project_reached_metadata += $d)                         \
        $(call dependency-ensure-reference,                            \
          $(call instance-field,$1,group),                             \
          $(call dependency-metadata-origin,$d))                       \
        $(call project-expand-node,                                    \
          $(call project-record-provider,$d),                          \
          $(call project-record-phase,$d))))))
endef

define project-expand-reached-flavors
$(eval project_flavor_visited :=)                                      \
$(eval project_reached_metadata :=)                                    \
$(foreach r,$(dependency-request-targets),                             \
  $(call project-expand-node,$(call target-instance-key,$r),           \
    $(call extract-suffix,$r)))                                        \
$(eval project_reached_metadata :=                                     \
  $(call stable-unique,$(project_reached_metadata)))
endef

# $(call project-consumer-group, dependency-record)
project-consumer-group	= $(call instance-field,$($1_consumer),group)

# $(call project-provider-policy, dependency-record)
project-provider-policy	= $(addprefix DEPENDENCY_PROVIDER_UPORTS_GROUPS., \
	$(call project-consumer-group,$1))

# $(call project-provider-groups, dependency-record)
project-provider-groups	= $(if $(filter undefined,                     \
	$(origin $(call project-provider-policy,$1))),                 \
	$(groups_all),$($(call project-provider-policy,$1)))

# $(call project-configured-provider, dependency-record)
# Preserve implicit default-group membership without probing the full catalog.
define project-configured-provider
$(call select-dependency-provider-candidates,                          \
  $(call project-consumer-group,$1),                                   \
  $(call dependency-origin-base,$($1_origin)),                         \
  $(filter $(addsuffix @%,$(call project-provider-groups,$1)),         \
    $(filter %@$(call dependency-origin-base,$($1_origin)),            \
      $(project_provider_bindings))))
endef

# $(call project-context-groups, dependency-record)
# Build tools require a native context. Library/runtime edges retain target
# context. Actual recipe metadata supplies the final compatibility check.
define project-context-groups
$(strip $(foreach g,$(call project-provider-groups,$1),                \
  $(if $(and                                                           \
    $(filter $(call dependency-record-opsys,$1),                       \
      $(call dependency-target-opsys,$g)),                             \
    $(filter $(call dependency-record-arch,$1),                        \
      $(call dependency-target-arch,$g))),                             \
    $(if $(and $(filter build,$($1_type)),                             \
      $(call dependency-group-cross-compile,$g)),,$g))))
endef

# $(call project-provider-group, dependency-record)
define project-provider-group
$(strip $(if $(filter $(call project-consumer-group,$1),               \
  $(call project-context-groups,$1)),                                  \
  $(call project-consumer-group,$1),                                   \
  $(if $(filter 1,$(words $(call project-context-groups,$1))),         \
    $(call project-context-groups,$1),                                 \
    $(error No unique permitted context for $($1_consumer):$($1_origin); candidates: $(call project-context-groups,$1)))))
endef

# $(call project-missing-provider, dependency-record)
project-missing-provider = $(strip $(if $(and                          \
	$(filter unselected unknown-flavor,$($1_resolution)),          \
	$(if $(strip $(call dependency-allowed-provider-candidates,    \
	  $(call instance-field,$($1_consumer),group),                 \
	  $(call dependency-origin-base,$($1_origin)))),,yes),         \
	$(filter uports,$($1_provider_kind)),                          \
	$(filter $(call dependency-origin-base,$($1_origin)),          \
	  $(ports_all_raw_lists))),                                    \
	$(or $(strip $(call project-configured-provider,$1)),          \
	  $(call project-provider-group,$1)@$(call dependency-origin-base,$($1_origin)))))

# $(call project-register-provider, group@origin)
define project-register-provider
$(eval ports_all_group += $1)                                          \
$(eval groups_$(call get-group,$1) += $(call get-port,$1))             \
$(eval dependency-base-instances += $(call dependency-instance-key,$1)) \
$(eval $(call generate-port-env,$(call get-group,$1),$(call get-port,$1))) \
$(eval $(call generate-instance-record,$1))                            \
$(eval instance_$(call dependency-instance-key,$1)_project_flavor :=)
endef

# Collect the new frontier together, reusing the bounded metadata worker.
define project-probe-providers
$(eval project_provider_metadata := $(shell                            \
  $(call dependency-prefetch-command,                                  \
    $(foreach p,$(project_new_providers),                              \
      $(call dependency-instance-key,$p)),default)))                   \
$(if $(filter-out 0,$(.SHELLSTATUS)),                                  \
  $(error Project provider metadata collection failed))                \
$(eval dependency_metadata_raw += $(project_provider_metadata))
endef

# Existing resolver/projection has already considered configured and external
# providers. Only unresolved active edges may extend the candidate set.
define project-discover-providers
$(if $(dependency-requests),                                           \
  $(eval project_new_providers := $(filter-out $(ports_all_group),     \
    $(call stable-unique,$(foreach d,$(dependency-active-record-ids),  \
      $(call project-missing-provider,$d)))))                          \
  $(if $(project_new_providers),                                       \
    $(eval project_metadata_loaded := yes)                             \
    $(foreach p,$(project_new_providers),                              \
      $(call project-register-provider,$p))                            \
    $(project-probe-providers)                                         \
    $(call load-dependency-records)))
endef

.PHONY: project-dependency-plan project-dependency-snapshot
depends_exclude_targets += project-dependency-plan                     \
	project-dependency-snapshot
project-dependency-plan:
	@$(if $(dependency-requests),,                                 \
	  $(error PROJECT_PORTS has no roots to plan))
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@{ $(dependency-execution-input) :; } |                        \
	  awk -v inspect=1 -f "$(portdir)/Tools/dependency-execution.awk"

project-dependency-snapshot:
	@$(if $(dependency-requests),,                                 \
	  $(error PROJECT_PORTS has no roots to snapshot))
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@$(foreach p,$(ports_all_group),printf '%s\n'                  \
	  'project-instance|$(call get-group,$p)|$(call rm-groups,$p)';)
	@$(foreach d,$(dependency_metadata_raw),printf '%s\n' '$d';)
endif
