#
# dependency-flavor.mk - demand-driven flavored dependency instances
#

dependency-base-instances := $(foreach p,$(ports_all_group),	       \
	$(call dependency-instance-key,$p))
dependency-instances	= $(dependency-base-instances)		       \
			  $(sort $(dependency_flavor_instances))

# $(call dependency-base-instance, instance-key)
dependency-base-instance = $(strip $(call flavor-either,	       \
	$(call instance-field,$1,flavor_base),$1))

# $(call dependency-instance-flavors, instance-key)
define dependency-instance-flavors
$(dependency_choices_$(call dependency-base-instance,$1))
endef

# $(call dependency-origin-base, origin[@flavor])
dependency-origin-base	= $(firstword $(subst @, ,$1))

# $(call dependency-origin-flavor, origin[@flavor])
dependency-origin-flavor = $(word 2,$(subst @, ,$1))

# $(call dependency-flavor-key, base-instance, flavor)
# The port's actual first Flavor determines default compatibility.
dependency-flavor-key	= $(strip $(if $(strip $2),		       \
	$(if $(filter $2,$(dependency_default_$(strip $1))),$1,	       \
	  $(call dependency-nondefault-key,$1,$2)),$1))

# $(call dependency-nondefault-key, base-instance, flavor)
define dependency-nondefault-key
$(strip $1)$(flavor-instance-marker)$(strip $2)
endef

# $(call dependency-target-instance, canonical-target)
dependency-target-instance = $(call dependency-flavor-key,	       \
	$(call target-base-instance-key,$1),			       \
	$(if $(findstring @,$1),				       \
	  $(call flavor-target-selection,$1)))
target-instance-key	= $(call dependency-target-instance,$1)

# $(call dependency-flavor-choice, base-instance, flavor)
dependency-flavor-choice = $(strip $(if $(strip $2),		       \
	$(filter $2,$(dependency_choices_$(strip $1))),default))

# $(call dependency-create-variant, base-instance, flavor)
define dependency-create-variant
$(call dependency-create-variant-impl,$(strip $1),$(strip $2))
endef

# $(call dependency-create-variant-impl, normalized arguments)
define dependency-create-variant-impl
$(if $(filter $(call dependency-flavor-key,$1,$2),		       \
  $(dependency_flavor_instances)),,				       \
  $(if $(call instance-field,$(call dependency-flavor-key,$1,$2),root), \
  $(if $(filter $1,						       \
    $(call instance-field,$(call dependency-flavor-key,$1,$2),flavor_base)),, \
    $(error Flavor instance key collision for $1/$2)),		       \
  $(foreach f,group port category origin root,			       \
    $(eval instance_$(call dependency-flavor-key,$1,$2)_$f :=	       \
      $(call instance-field,$1,$f))))				       \
  $(eval instance_$(call dependency-flavor-key,$1,$2)_variant := $2)   \
  $(eval instance_$(call dependency-flavor-key,$1,$2)_flavor_base := $1) \
  $(eval instance_$(call dependency-flavor-key,$1,$2)_env :=	       \
    $(filter-out FLAVOR=%,$(call instance-field,$1,env)) FLAVOR=$2)    \
  $(eval dependency_flavor_instances +=				       \
    $(call dependency-flavor-key,$1,$2)))
endef

# $(call dependency-collect-flavor, instance|kind|value)
define dependency-collect-flavor
$(if $(filter $(word 1,$(subst |, ,$1)),$(dependency-base-instances)), \
  $(if $(filter flavor-default,$(word 2,$(subst |, ,$1))),	       \
    $(eval dependency_default_$(word 1,$(subst |, ,$1)) :=	       \
      $(word 3,$(subst |, ,$1))))				       \
  $(if $(filter flavor-choice,$(word 2,$(subst |, ,$1))),	       \
    $(eval dependency_choices_$(word 1,$(subst |, ,$1)) +=	       \
      $(word 3,$(subst |, ,$1)))))
endef

# $(call dependency-variant-root, instance-key)
dependency-variant-root	= $(call instance-field,$1,root)

# $(call dependency-variant-origin, instance-key)
dependency-variant-origin = $(call instance-field,$1,origin)

# $(call dependency-variant-path, instance-key)
define dependency-variant-path
$(call dependency-variant-root,$1)/$(call dependency-variant-origin,$1)
endef

# $(call dependency-variant-record, instance-key)
define dependency-variant-record
$1|variant|$(instance_$1_flavor_base)|$(instance_$1_variant)
endef

# $(call dependency-probe-variant, instance-key)
# Explicit selection overrides inherited make/environment FLAVOR for this probe.
define dependency-probe-variant
$(call dependency-probe-variant-impl,$(strip $1))
endef

# $(call dependency-probe-variant-impl, normalized arguments)
define dependency-probe-variant-impl
$(eval dependency_variant_raw := $(shell			       \
  $(MAKE) -s --no-print-directory -C				       \
    "$(call dependency-variant-path,$1)" PORTSDIR="$(portdir)"	       \
    $(call instance-field,$1,env)				       \
    --eval='override FLAVOR := $(call instance-field,$1,variant)'      \
    $(call dependency-metadata-source-options,$1)		       \
    uports-dependency-metadata))				       \
$(if $(filter-out 0,$(.SHELLSTATUS)),				       \
  $(error Flavor dependency metadata collection failed for $1))	       \
$(eval dependency_metadata_raw +=				       \
  $(call dependency-variant-record,$1))				       \
$(eval dependency_metadata_raw +=				       \
  $(addprefix $1|,$(dependency_variant_raw)))			       \
$(foreach d,$(addprefix $1|,$(dependency_variant_raw)),		       \
  $(if $(filter provides,$(word 2,$(subst |, ,$d))),		       \
    $(call collect-dependency-capability,$d)))			       \
$(call dependency-expand-flavors,				       \
  $(addprefix $1|,$(dependency_variant_raw)))
endef

# $(call dependency-reference-valid, origin[@flavor])
define dependency-reference-valid
$(strip $(if $(findstring @,$1),				       \
  $(if $(call flavor-both,					       \
    $(filter 2,$(words $(subst @, ,$1))),			       \
    $(filter $1,$(call dependency-reference-spelling,$1))),	       \
    $(if $(strip $(call flavor-target-remove-chars,		       \
      $(call dependency-origin-flavor,$1),$(flavor-target-chars))),,yes)), \
  yes))
endef

# $(call dependency-reference-spelling, origin[@flavor])
define dependency-reference-spelling
$(call dependency-origin-base,$1)@$(call dependency-origin-flavor,$1)
endef

# $(call dependency-reference-instance, group@origin, origin[@flavor])
define dependency-reference-instance
$(strip $(if $(call flavor-both,$1,                                   \
  $(call dependency-reference-valid,$2)),                            \
  $(if $(call dependency-flavor-choice,				       \
    $(call dependency-instance-key,$1),$(call dependency-origin-flavor,$2)), \
    $(if $(call dependency-reference-capability,		       \
      $(call dependency-flavor-key,				       \
        $(call dependency-instance-key,$1),			       \
        $(call dependency-origin-flavor,$2)),			       \
      $(call dependency-origin-base,$2)),			       \
      $(call dependency-flavor-key,				       \
        $(call dependency-instance-key,$1),			       \
        $(call dependency-origin-flavor,$2))))))
endef

# $(call dependency-reference-capability, provider-key, origin)
dependency-reference-capability = $(filter $(strip $2),		       \
	$(call instance-field,$1,origin)			       \
	$(dependency_capabilities_$(strip $1)))

# $(call dependency-ensure-variant, base-instance, flavor)
define dependency-ensure-variant
$(call dependency-ensure-variant-impl,$(strip $1),$(strip $2))
endef

# $(call dependency-ensure-variant-impl, normalized arguments)
define dependency-ensure-variant-impl
$(if $(call flavor-all,$(strip $2),                                   \
  $(call dependency-flavor-choice,$1,$2),                             \
  $(filter-out $2,$(dependency_default_$1))),			       \
  $(if $(filter $(call dependency-flavor-key,$1,$2),		       \
    $(dependency_flavor_instances)),,				       \
    $(call dependency-create-variant,$1,$2)			       \
    $(call dependency-probe-variant,				       \
      $(call dependency-flavor-key,$1,$2))))
endef

# $(call dependency-reference-provider, consumer-group, origin[@flavor])
dependency-reference-provider = $(call select-dependency-provider-candidates, \
	$1,$(call dependency-origin-base,$2),			       \
	$(call dependency-reference-candidates,$1,$2))

# $(call dependency-reference-candidates, group, origin[@flavor])
define dependency-reference-candidates
$(strip $(if $(call dependency-reference-valid,$2),		       \
  $(foreach p,$(call dependency-allowed-provider-candidates,	       \
    $1,$(call dependency-origin-base,$2)),			       \
    $(if $(call dependency-flavor-choice,			       \
      $(call dependency-instance-key,$p),			       \
      $(call dependency-origin-flavor,$2)),$p))))
endef

# $(call dependency-reference-kind, origin[@flavor])
dependency-reference-kind = $(if $(call flavor-either,		       \
	$(filter $(call dependency-origin-base,$1),$(ports_all_raw_lists)), \
	$(call dependency-capability-candidates,		       \
	  $(call dependency-origin-base,$1))),uports,unresolved)

# $(call dependency-reference-resolution, group, origin[@flavor])
define dependency-reference-resolution
$(strip $(if $(filter unresolved,$(call dependency-reference-kind,$2)), \
  unknown-origin,						       \
  $(if $(call dependency-reference-valid,$2),			       \
    $(if $(call dependency-reference-provider,$1,$2),		       \
      $(if $(call dependency-reference-instance,		       \
        $(call dependency-reference-provider,$1,$2),$2),selected,      \
        invalid-capability),					       \
      $(if $(call dependency-allowed-provider-candidates,	       \
        $1,$(call dependency-origin-base,$2)),			       \
        $(if $(call dependency-reference-candidates,$1,$2),	       \
          ambiguous,unknown-flavor),				       \
        unselected)),invalid-flavor)))
endef

# $(call collect-dependency-context, instance|context|opsys|arch)
define collect-dependency-context
$(eval dependency_context_$(word 1,$(subst |, ,$1))_opsys :=	       \
  $(word 3,$(subst |, ,$1)))					       \
$(eval dependency_context_$(word 1,$(subst |, ,$1))_arch :=	       \
  $(word 4,$(subst |, ,$1)))
endef

# $(call dependency-record-context-compatible, record-id)
# Native build tools and target libraries have different compatibility roles.
define dependency-record-context-compatible
$(call dependency-record-context-compatible-impl,$(strip $1))
endef

# $(call dependency-record-context-compatible-impl, record-id)
define dependency-record-context-compatible-impl
$(strip $(if $(call flavor-either,				       \
  $(call dependency-instance-flavors,$($1_consumer)),		       \
  $(call dependency-instance-flavors,$($1_provider_instance))),	       \
  $(call flavor-both,$(filter					       \
    $(if $(filter build,$($1_type)),$(DEPENDENCY_BUILD_OPSYS),	       \
      $(dependency_context_$($1_consumer)_opsys)),		       \
    $(dependency_context_$($1_provider_instance)_opsys)),	       \
    $(filter							       \
      $(if $(filter build,$($1_type)),$(DEPENDENCY_BUILD_ARCH),	       \
        $(dependency_context_$($1_consumer)_arch)),		       \
      $(dependency_context_$($1_provider_instance)_arch))),yes))
endef

# $(call dependency-uports-root, record-id)
dependency-uports-root	= $(dependency_install_root_$($1_provider_instance))

# $(call dependency-uports-prefix, record-id)
define dependency-uports-prefix
contribution|$($1_provider_instance)|$($1_origin)|
endef

# $(call dependency-uports-contribution, record-id, field, path-suffix)
define dependency-uports-contribution
$(call dependency-uports-field,$1,$2)$(call dependency-uports-location,$1,$3)
endef

# $(call dependency-uports-field, record-id, field)
define dependency-uports-field
$(call dependency-uports-prefix,$1)$(strip $2)|
endef

# $(call dependency-uports-location, record-id, path-suffix)
define dependency-uports-location
$(call dependency-uports-root,$1)$(strip $2)
endef

dependency-uports-library-paths = include lib lib64		       \
	lib/pkgconfig lib64/pkgconfig share/pkgconfig

# $(call dependency-flavor-environment, record-id)
# Existing unflavored edges keep their established environment behavior.
define dependency-flavor-environment
$(if $(call flavor-either,					       \
  $(call dependency-instance-flavors,$($1_consumer)),		       \
  $(call dependency-instance-flavors,$($1_provider_instance))),	       \
  $(if $(filter build,$($1_type)),				       \
    printf '%s\n' '$(call dependency-uports-contribution,$1,bindir,/bin)';, \
    $(foreach s,$(dependency-uports-library-paths),		       \
      printf '%s\n'						       \
        '$(call dependency-uports-contribution,$1,		       \
          $(call dependency-path-kind,$s),/$s)';))		       \
  $(foreach s,lib lib64,					       \
    printf '%s\n' '$(call dependency-uports-contribution,$1,runtimedir,/$s)';))
endef

# $(call dependency-path-kind, relative-directory)
dependency-path-kind	= $(strip $(if $(filter include,$1),includedir, \
	$(if $(filter lib lib64,$1),libdir,pkgconfigdir)))

dependency-environment-enabled = $(call flavor-either,		       \
	$(filter yes,$(dependency-external-providers-enabled)),	       \
	$(strip $(dependency_flavor_instances)))

# $(call dependency-state-env, instance-key)
dependency-state-env	= $(filter-out USE_GLOBALBASE=% DISTDIR_SITE=% \
	PACKAGES_SITE=% SCMDIR_SITE=%,$(call instance-field,$1,env))

# $(call dependency-node-record, normalized-instance-key)
define dependency-node-record
$(call dependency-node-head,$1)$(call dependency-state-env,$1)
endef

# $(call dependency-node-head, normalized-instance-key)
define dependency-node-head
node|$1|$(instance_$1_group)|$(instance_$1_origin)|
endef

# $(call dependency-cookie-identity, normalized-instance-key, phase)
define dependency-cookie-identity
cookie|$1|$2|$(dependency_cookie_$1_$2)|
endef

# $(call dependency-cookie-ready, normalized-instance-key, phase)
define dependency-cookie-ready
$(if $(wildcard $(dependency_cookie_$1_$2)),ready,missing)
endef

# $(call dependency-cookie-record, normalized-instance-key, phase)
define dependency-cookie-record
$(call dependency-cookie-identity,$1,$2)$(call dependency-cookie-ready,$1,$2)
endef

# $(call dependency-ensure-reference, consumer-group, origin[@flavor])
define dependency-ensure-reference
$(call dependency-ensure-reference-impl,$(strip $1),$(strip $2))
endef

# $(call dependency-ensure-reference-impl, normalized arguments)
define dependency-ensure-reference-impl
$(if $(call flavor-all,$(call dependency-reference-valid,$2),	       \
  $(call dependency-origin-flavor,$2),				       \
  $(call dependency-reference-provider,$1,$2)),			       \
  $(call dependency-ensure-variant,				       \
    $(call dependency-instance-key,				       \
      $(call dependency-reference-provider,$1,$2)),		       \
    $(call dependency-origin-flavor,$2)))
endef

# $(call dependency-metadata-origin, instance|type|requirement:origin[:phase])
dependency-metadata-origin = $(strip $(if			       \
	$(filter :%,$(word 3,$(subst |, ,$1))),			       \
	$(word 1,$(subst :, ,$(word 3,$(subst |, ,$1)))),	       \
	$(word 2,$(subst :, ,$(word 3,$(subst |, ,$1))))))

# $(call dependency-expand-flavors, metadata-records)
define dependency-expand-flavors
$(foreach d,$1,							       \
  $(if $(filter build lib run,$(word 2,$(subst |, ,$d))),	       \
    $(call dependency-ensure-reference,				       \
      $(call instance-field,$(word 1,$(subst |, ,$d)),group),	       \
      $(call dependency-metadata-origin,$d))))
endef

# $(call dependency-normalize-target, [group:]port[@flavor].phase)
define dependency-normalize-target
$(strip $(if $(call resolve-port-target,$1),			       \
  $(if $(call flavor-target-selection,				       \
    $(call resolve-port-target,$1)),				       \
    $(if $(filter $(call flavor-target-selection,		       \
      $(call resolve-port-target,$1)),				       \
      $(dependency_default_$(call target-base-instance-key,	       \
        $(call resolve-port-target,$1)))),			       \
      $(call flavor-base-target,$1),				       \
      $(call flavor-target-stem,$1)@$(call dependency-root-ending,$1)), \
    $(call flavor-base-target,$1))))
endef

# $(call dependency-root-ending, target)
define dependency-root-ending
$(call dependency-root-flavor,$1)$(suffix $1)
endef

# $(call dependency-root-flavor, target)
dependency-root-flavor	= $(call flavor-target-selection,	       \
	$(call resolve-port-target,$1))

# $(call dependency-flavor-command, instance-key)
define dependency-flavor-command
$(call dependency-command-base,$1)$(call dependency-command-qualifier,$1)
endef

# $(call dependency-command-base, instance-key)
define dependency-command-base
$(instance_$(strip $1)_group):$(instance_$(strip $1)_port)
endef

# $(call dependency-command-qualifier, instance-key)
# Explicit provider defaults bypass project root selections on that port.
define dependency-command-qualifier
$(strip $(if $(call instance-field,$1,flavor_base),		       \
  @$(call instance-field,$1,variant),				       \
  $(if $(dependency_choices_$(strip $1)),@$(dependency_default_$(strip $1)))))
endef

# Collect raw metadata without provider policy or lifecycle validation.
define load-dependency-metadata
$(foreach n,$(dependency-instances),				       \
  $(eval dependency_capabilities_$n :=))			       \
$(eval dependency_metadata_raw := $(shell $(dependency-metadata-command))) \
$(if $(filter-out 0,$(.SHELLSTATUS)),				       \
  $(error dependency metadata collection failed))		       \
$(foreach d,$(dependency_metadata_raw),				       \
  $(if $(filter provides,$(word 2,$(subst |, ,$d))),		       \
    $(call collect-dependency-capability,$d)))			       \
$(load-dependency-flavors)
endef

# $(call dependency-ensure-root, target)
define dependency-ensure-root
$(call dependency-ensure-root-impl,$(strip $1))
endef

# $(call dependency-ensure-root-impl, normalized arguments)
define dependency-ensure-root-impl
$(if $(call resolve-port-target,$1),				       \
  $(if $(call flavor-target-selection,$(call resolve-port-target,$1)), \
    $(if $(call dependency-flavor-choice,			       \
      $(call target-base-instance-key,$(call resolve-port-target,$1)), \
      $(call flavor-target-selection,$(call resolve-port-target,$1))),, \
      $(error Unknown Flavor in dependency request: $1))	       \
    $(call dependency-ensure-variant,				       \
      $(call target-base-instance-key,$(call resolve-port-target,$1)), \
      $(call flavor-target-selection,$(call resolve-port-target,$1)))))
endef

# $(call dependency-import-variant, instance|variant|base|flavor)
define dependency-import-variant
$(call dependency-create-variant,$(word 3,$(subst |, ,$1)),	       \
  $(word 4,$(subst |, ,$1)))
endef

# $(call dependency-refresh-default, target)
# Declaration discovery may initially hide SOURCE_MODE on an explicit default.
define dependency-refresh-default
$(if $(call flavor-all,						       \
  $(call dependency-root-flavor,$1),				       \
  $(filter-out undefined,$(origin SOURCE_MODE) $(origin USE_SCM)),     \
  $(if $(call flavor-both,                                           \
    $(filter yes,$(UPORTS_DEPENDENCY_INVOCATION)),                     \
    $(DEPENDENCY_METADATA_SOURCE)),,yes)),			       \
  $(if $(filter $(call dependency-root-flavor,$1),		       \
    $(dependency_default_$(call target-base-instance-key,	       \
      $(call resolve-port-target,$1)))),			       \
    $(call dependency-probe-default,				       \
      $(call target-base-instance-key,$(call resolve-port-target,$1)))))
endef

# $(call dependency-probe-default, base-instance)
define dependency-probe-default
$(call dependency-probe-default-impl,$(strip $1))
endef

# $(call dependency-probe-default-impl, base-instance)
define dependency-probe-default-impl
$(if $(filter $1,$(dependency_default_refreshed)),,		       \
  $(eval dependency_default_refreshed += $1)			       \
  $(eval dependency_default_raw := $(shell			       \
    $(MAKE) -s --no-print-directory -C				       \
      "$(call dependency-variant-path,$1)" PORTSDIR="$(portdir)"       \
      $(call instance-field,$1,env)				       \
      --eval='override undefine FLAVOR'				       \
      $(call dependency-metadata-source-options,$1)		       \
      uports-dependency-metadata))				       \
  $(if $(filter-out 0,$(.SHELLSTATUS)),				       \
    $(error Default source metadata collection failed for $1))	       \
  $(eval dependency_metadata_raw :=				       \
    $(filter-out $1|%,$(dependency_metadata_raw))		       \
    $(addprefix $1|,$(dependency_default_raw)))			       \
  $(eval dependency_capabilities_$1 :=)				       \
  $(eval dependency_choices_$1 :=)				       \
  $(foreach d,$(addprefix $1|,$(dependency_default_raw)),	       \
    $(call dependency-collect-flavor,$d)			       \
    $(if $(filter provides,$(word 2,$(subst |, ,$d))),		       \
      $(call collect-dependency-capability,$d))))
endef

# Full snapshots preserve discovered variants, avoiding a probe per recursion.
define load-dependency-flavors
$(eval dependency_flavor_instances :=)				       \
$(eval dependency_default_refreshed :=)				       \
$(foreach n,$(dependency-base-instances),			       \
  $(eval dependency_default_$n :=)				       \
  $(eval dependency_choices_$n :=)				       \
  $(eval instance_$n_env :=					       \
    $(filter-out FLAVOR=%,$(call instance-field,$n,env))))	       \
$(foreach d,$(dependency_metadata_raw),				       \
  $(call dependency-collect-flavor,$d))				       \
$(foreach d,$(dependency_metadata_raw),				       \
  $(if $(filter variant,$(word 2,$(subst |, ,$d))),		       \
    $(call dependency-import-variant,$d)))			       \
$(foreach r,$(dependency-requests),				       \
  $(call dependency-refresh-default,$r))			       \
$(foreach n,$(dependency-base-instances),			       \
  $(if $(call instance-field,$n,project_flavor),		       \
    $(call dependency-ensure-root,				       \
      $(call dependency-command-base,$n).install)))		       \
$(foreach r,$(dependency-requests),$(call dependency-ensure-root,$r))  \
$(call dependency-expand-flavors,$(dependency_metadata_raw))
endef

# Register the one validated wrapper selection before lifecycle recipes expand.
ifneq ($(findstring @,$(_UPORTS_FLAVOR_TARGET)),)
$(call dependency-create-variant,				       \
  $(call target-base-instance-key,$(_UPORTS_FLAVOR_TARGET)),	       \
  $(call flavor-target-selection,$(_UPORTS_FLAVOR_TARGET)))
endif

.PHONY: dependency-flavor-list
depends_exclude_targets	+= dependency-flavor-list
dependency-flavor-list:
	@$(load-dependency-records)
	@$(foreach n,$(dependency-instances),printf '%s\n'	       \
	  'instance|$n|$(call dependency-instance-target,$n,install)';)
