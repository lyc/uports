#
# dependency-context.mk - bounded discovery for requested group instances
#

# $(call group-member-target, root-record)
define group-member-target
$(subst $(space),,$(call group-member-field,1,$1):		       \
  $(notdir $(call group-member-field,2,$1))			       \
  $(if $(call group-member-field,3,$1),				       \
    @$(call group-member-field,3,$1)).install)
endef

ifneq ($(filter group-dependency-snapshot			       \
  dependency-% dependencies-% info.debug.depend%,		       \
  $(MAKECMDGOALS)),)
ifeq ($(strip $(DEPENDENCY_REQUESTS) $(DEPENDENCY_REQUEST)),)
DEPENDENCY_REQUESTS	:= $(foreach r,$(group_member_requests),       \
	$(call group-member-target,$r))
endif
endif
# Group environments select aggregate Flavors; dependencies select provider
# Flavors. Legacy per-port root selections must not activate unrelated variants.
$(foreach p,$(ports_all_group),					       \
  $(eval instance_$(call dependency-instance-key,$p)_project_flavor :=))
dependency-scoped-targets += group-dependency-snapshot

# $(call dependency-context-phase-types, lifecycle-phase)
dependency-context-phase-types	= $(if $(call dependency-state-class,$1),\
	build lib)$(if $(filter stage,				       \
	  $(call dependency-state-class,$1)), run)

# $(call dependency-context-record-provider, metadata-record)
define dependency-context-record-provider
$(call dependency-reference-instance,				       \
  $(call dependency-reference-provider,				       \
    $(call instance-field,$(word 1,$(subst |, ,$1)),group),	       \
    $(call dependency-metadata-origin,$1)),			       \
  $(call dependency-metadata-origin,$1))
endef

# $(call dependency-context-record-phase, metadata-record)
dependency-context-record-phase	= $(or $(word 3,		       \
	$(subst :, ,$(word 3,$(subst |, ,$1)))),install)

# $(call dependency-context-expand-node, instance-key, lifecycle-phase)
# Only reached references may materialize provider Flavors. Mark before walking
# children so a cycle terminates here and is diagnosed by the graph validator.
define dependency-context-expand-node
$(if $(strip $1),						       \
  $(if $(filter $(strip $1).$(strip $2),$(dependency_context_flavor_visited)),,\
    $(eval dependency_context_flavor_visited += $(strip $1).$(strip $2))\
    $(foreach d,$(filter $(strip $1)|%,$(dependency_metadata_raw)),    \
      $(if $(filter $(call dependency-context-phase-types,$2),	       \
        $(word 2,$(subst |, ,$d))),				       \
        $(eval dependency_context_reached_metadata += $d)	       \
        $(call dependency-ensure-reference,			       \
          $(call instance-field,$1,group),			       \
          $(call dependency-metadata-origin,$d))		       \
        $(call dependency-context-expand-node,			       \
          $(call dependency-context-record-provider,$d),	       \
          $(call dependency-context-record-phase,$d))))))
endef

define dependency-expand-reached-flavors
$(eval dependency_context_flavor_visited :=)			       \
$(eval dependency_context_reached_metadata :=)			       \
$(foreach r,$(dependency-request-targets),			       \
  $(call dependency-context-expand-node,$(call target-instance-key,$r),\
    $(call extract-suffix,$r)))					       \
$(eval dependency_context_reached_metadata :=			       \
  $(call stable-unique,$(dependency_context_reached_metadata)))
endef

# $(call dependency-context-consumer-group, dependency-record)
dependency-context-consumer-group	= $(call instance-field,$($1_consumer),group)

# $(call dependency-context-provider-policy, dependency-record)
dependency-context-provider-policy	= $(addprefix DEPENDENCY_PROVIDER_UPORTS_GROUPS.,\
	$(call dependency-context-consumer-group,$1))

# $(call dependency-context-provider-groups, dependency-record)
dependency-context-provider-groups	= $(if $(filter undefined,     \
	$(origin $(call dependency-context-provider-policy,$1))),      \
	$(groups_all),$($(call dependency-context-provider-policy,$1)))

# $(call dependency-context-configured-provider, dependency-record)
# Preserve implicit default-group membership without probing the full catalog.
define dependency-context-configured-provider
$(call select-dependency-provider-candidates,			       \
  $(call dependency-context-consumer-group,$1),			       \
  $(call dependency-origin-base,$($1_origin)),			       \
  $(filter $(addsuffix @%,$(call dependency-context-provider-groups,$1)),\
    $(filter %@$(call dependency-origin-base,$($1_origin)),	       \
      $(group_provider_bindings))))
endef

# $(call dependency-context-context-groups, dependency-record)
# Build tools require a native context. Library/runtime edges retain target
# context. Actual recipe metadata supplies the final compatibility check.
define dependency-context-context-groups
$(strip $(foreach g,$(call dependency-context-provider-groups,$1),     \
  $(if $(and							       \
    $(filter $(call dependency-record-opsys,$1),		       \
      $(call dependency-target-opsys,$g)),			       \
    $(filter $(call dependency-record-arch,$1),			       \
      $(call dependency-target-arch,$g))),			       \
    $(if $(and $(filter build,$($1_type)),			       \
      $(call dependency-group-cross-compile,$g)),,$g))))
endef

# $(call dependency-context-provider-group, dependency-record)
define dependency-context-provider-group
$(strip $(if $(filter $(call dependency-context-consumer-group,$1),    \
  $(call dependency-context-context-groups,$1)),		       \
  $(call dependency-context-consumer-group,$1),			       \
  $(if $(filter 1,$(words $(call dependency-context-context-groups,$1))),\
    $(call dependency-context-context-groups,$1),		       \
    $(error No unique permitted context for $($1_consumer):$($1_origin); candidates: $(call dependency-context-context-groups,$1)))))
endef

# $(call dependency-context-missing-provider, dependency-record)
dependency-context-missing-provider = $(strip $(if $(and	       \
	$(filter unselected unknown-flavor,$($1_resolution)),	       \
	$(if $(strip $(call dependency-allowed-provider-candidates,    \
	  $(call instance-field,$($1_consumer),group),		       \
	  $(call dependency-origin-base,$($1_origin)))),,yes),	       \
	$(filter uports,$($1_provider_kind)),			       \
	$(filter $(call dependency-origin-base,$($1_origin)),	       \
	  $(ports_all_raw_lists))),				       \
	$(or $(strip $(call dependency-context-configured-provider,$1)),\
	  $(call dependency-context-provider-group,$1)@$(call dependency-origin-base,$($1_origin)))))

# $(call dependency-context-register-provider, group@origin)
define dependency-context-register-provider
$(eval ports_all_group += $1)					       \
$(eval groups_$(call get-group,$1) += $(call get-port,$1))	       \
$(eval dependency-base-instances += $(call dependency-instance-key,$1))\
$(eval $(call generate-port-env,$(call get-group,$1),$(call get-port,$1)))\
$(eval $(call generate-instance-record,$1))			       \
$(eval instance_$(call dependency-instance-key,$1)_project_flavor :=)
endef

# Collect the new frontier together, reusing the bounded metadata worker.
define dependency-context-probe-providers
$(eval dependency_context_provider_metadata := $(shell		       \
  $(call dependency-prefetch-command,				       \
    $(foreach p,$(dependency_context_new_providers),		       \
      $(call dependency-instance-key,$p)),default)))		       \
$(if $(filter-out 0,$(.SHELLSTATUS)),				       \
  $(error Provider context metadata collection failed))		       \
$(eval dependency_metadata_raw += $(dependency_context_provider_metadata))
endef

# Existing resolver/projection has already considered configured and external
# providers. Only unresolved active edges may extend the candidate set.
define dependency-discover-providers
$(if $(dependency-requests),					       \
  $(eval dependency_context_new_providers := $(filter-out $(ports_all_group),\
    $(call stable-unique,$(foreach d,$(dependency-active-record-ids),  \
      $(call dependency-context-missing-provider,$d)))))	       \
  $(if $(dependency_context_new_providers),			       \
    $(eval dependency_context_metadata_loaded := yes)		       \
    $(foreach p,$(dependency_context_new_providers),		       \
      $(call dependency-context-register-provider,$p))		       \
    $(dependency-context-probe-providers)			       \
    $(call load-dependency-records)))
endef

.PHONY: group-dependency-snapshot
depends_exclude_targets += group-dependency-snapshot
group-dependency-snapshot:
	@$(if $(dependency-requests),,				       \
	  $(error No group members to snapshot))
	@$(load-dependency-records)
	@$(dependency-external-preflight) :
	@$(foreach p,$(ports_all_group),printf '%s\n'		       \
	  'group-instance|$(call get-group,$p)|$(call rm-groups,$p)';)
	@$(foreach d,$(dependency_metadata_raw),printf '%s\n' '$d';)
