#
# flavor.mk - scoped Flavor selection, discovery and wrapper dispatch
#

FLAVOR_REQUEST		?=
flavor-instance-marker	:= __flavor_

# $(call flavor-both, first-condition, second-condition)
flavor-both		= $(and $(strip $1),$(strip $2))

# $(call flavor-all, first-condition, second-condition, third-condition)
flavor-all		= $(and $(strip $1),$(strip $2),$(strip $3))

# $(call flavor-either, first-condition, second-condition)
flavor-either		= $(or $(strip $1),$(strip $2))

# $(call flavor-any, first-condition, second-condition, third-condition)
flavor-any		= $(or $(strip $1),$(strip $2),$(strip $3))

flavor-target-chars	= a b c d e f g h i j k l m n o p q r s t u v  \
			  w x y z				       \
			  0 1 2 3 4 5 6 7 8 9 _

# $(call flavor-target-remove-chars, value, allowed-character-list)
define flavor-target-remove-chars
$(if $2,							       \
  $(call flavor-target-remove-chars,				       \
    $(subst $(firstword $2),,$1),$(wordlist 2,$(words $2),$2)),$1)
endef

# $(call flavor-target-base, [group:]port[@flavor].phase)
flavor-target-base	= $(firstword $(subst @, ,		       \
			    $(call extract-port,$1)))$(suffix $1)

# $(call flavor-target-selection, [group:]port[@flavor].phase)
flavor-target-selection	= $(strip $(if $(findstring @,$1),	       \
			    $(word 2,$(subst @, ,$(call extract-port,$1))), \
			    $(call instance-field,		       \
			      $(call target-base-instance-key,$1),     \
			      project_flavor)))

# $(call flavor-base-target, [group:]port[@flavor].phase)
flavor-base-target	= $(strip $(if				       \
			    $(filter .flavor-check,$(suffix $1)),      \
			    $(patsubst %.fetch,%.flavor-check,	       \
			      $(call resolve-unflavored-port-target,   \
			        $(call flavor-input-stem,$1).fetch)),  \
			    $(call resolve-unflavored-port-target,     \
			      $(call flavor-target-base,$1))))

# $(call flavor-target-stem, target)
flavor-target-stem	= $(basename $(call flavor-base-target,$1))

# $(call flavor-ending, target)
flavor-ending		= $(call flavor-target-selection,$1)$(suffix $1)

# $(call flavor-input-stem, target)
flavor-input-stem	= $(basename $(call flavor-target-base,$1))

# $(call flavor-target-spelling, target)
flavor-target-spelling	= $(call flavor-input-stem,$1)@$(call flavor-ending,$1)

# $(call resolve-port-target, [group:]port[@flavor].phase)
# Keep colons as data; escape only when defining make rules/prerequisites.
define resolve-port-target
$(strip $(if $(findstring @,$1),				       \
  $(if $(call flavor-both,					       \
    $(filter 2,$(words $(subst @, ,$(call extract-port,$1)))),	       \
    $(filter $1,$(call flavor-target-spelling,$1))),		       \
    $(if $(strip $(call flavor-target-remove-chars,		       \
      $(call flavor-target-selection,$1),$(flavor-target-chars))),,    \
      $(if $(call flavor-base-target,$1),			       \
        $(call flavor-target-stem,$1)@$(call flavor-ending,$1)))),     \
  $(call flavor-base-target,$1)))
endef

# $(call flavor-bridge-active, canonical-target)
flavor-bridge-active	= $(filter $1,$(_UPORTS_FLAVOR_TARGET))

# $(call flavor-target-escape, target)
flavor-target-escape	= $(subst :,\:,$1)

# $(call flavor-root, target)
flavor-root		= $(call flavor-base-field,$1,root)

# $(call flavor-origin, target)
flavor-origin		= $(call flavor-base-field,$1,origin)

# $(call flavor-base-field, target, field)
# Selection validation must address the real port before registering a variant.
define flavor-base-field
$(call target-instance-field,$(call flavor-base-target,$1),$2)
endef

# $(call flavor-target-directory, target)
flavor-target-directory	= $(call flavor-root,$1)/$(call flavor-origin,$1)

flavor-wrapper-suffixes	= $(addprefix .,$(suffix_all_lists)) .flavor-check
flavor-wrapper-goals	= $(filter $(addprefix %,		       \
			    $(flavor-wrapper-suffixes)),$(MAKECMDGOALS))

# $(call obsolete-port-target, target)
# Planner group@origin records are internal; wrapper commands use group:port.
define obsolete-port-target
$(strip $(or $(filter $(groups_all),$(firstword $(subst @, ,$1))),     \
  $(and $(findstring :,$1),					       \
    $(filter-out $(groups_all),$(firstword $(subst :, ,$1))),	       \
    $(port_$(firstword $(subst :, ,$1))_origin))))
endef

obsolete-port-requests	:= $(foreach t,$(flavor-wrapper-goals)	       \
  $(dependency-requests) $(addsuffix .fetch,$(FLAVOR_REQUEST)),	       \
  $(if $(call obsolete-port-target,$t),$t))
ifneq ($(strip $(obsolete-port-requests)),)
$(error Obsolete uports target syntax: $(obsolete-port-requests);      \
  use [group:]port[@flavor].phase)
endif

flavor-qualified-goals	= $(foreach t,$(flavor-wrapper-goals),	       \
			    $(if $(findstring @,$t),$t))

# $(call flavor-dispatch-needed, target)
flavor-dispatch-needed	= $(strip $(if				       \
	$(call flavor-bridge-active,$(call resolve-port-target,$1)),,  \
	$(call flavor-any,$(findstring @,$1),			       \
	  $(filter .flavor-check,$(suffix $1)),			       \
	  $(call flavor-target-selection,$(call resolve-port-target,$1)))))

# $(call flavor-dispatch-command, canonical-target)
# Only source operations are independent of the pending flavored provider graph.
define flavor-dispatch-command
set -e; metadata_file=$$(mktemp					       \
  "$${TMPDIR:-/tmp}/uports-flavor-dispatch.XXXXXX");		       \
trap 'rm -f "$$metadata_file"' EXIT HUP INT TERM;		       \
$(MAKE) -s --no-print-directory					       \
  -C "$(call flavor-target-directory,$1)"			       \
  PORTSDIR="$(portdir)" $(call flavor-base-field,$1,env)	       \
  $(if $(call flavor-target-selection,$1),			       \
    FLAVOR='$(call flavor-target-selection,$1)',		       \
    --eval='override undefine FLAVOR')				       \
  uports-flavor-metadata > "$$metadata_file";			       \
selected=$$(sed -n 's/^selected|//p' "$$metadata_file");	       \
default=$$(sed -n 's/^default|//p' "$$metadata_file");		       \
phase='$(call extract-suffix,$1)';				       \
if test "$$phase" = flavor-check; then				       \
  $(call flavor-metadata-output,$(call target-base-instance-key,$1))   \
elif test "$$selected" != "$$default"; then			       \
  case "$$phase" in						       \
    fetch|makesum|checksum)					       \
      $(MAKE) --no-print-directory				       \
        -C "$(call flavor-target-directory,$1)"			       \
        PORTSDIR="$(portdir)" $(call flavor-base-field,$1,env)	       \
        FLAVOR="$$selected" "$$phase";;				       \
    *) target="$(call flavor-target-stem,$1)@$${selected}.$${phase}"; \
       $(MAKE) --no-print-directory                                   \
         _UPORTS_FLAVOR_TARGET="$$target" "$$target";;                  \
  esac;								       \
else								       \
  $(MAKE) --no-print-directory					       \
    _UPORTS_FLAVOR_TARGET='$(call flavor-base-target,$1)'	       \
    '$(call flavor-base-target,$1)';				       \
fi
endef

# $(call flavor-metadata-output, base-instance-key)
# Use the actual declared default, including before graph metadata is loaded.
define flavor-metadata-output
selected=$$(sed -n 's/^selected|//p' "$$metadata_file");	       \
default=$$(sed -n 's/^default|//p' "$$metadata_file");		       \
instance='$1';							       \
if test "$$selected" != "$$default"; then			       \
  instance="$${instance}$(flavor-instance-marker)$${selected}";	       \
fi;								       \
sed "s/^/$$instance|/" "$$metadata_file";
endef

# $(call generate-flavor-target, canonical-target)
define generate-flavor-target
$(call flavor-target-escape,$1): uports-force
	$$(validate-port-target)
	$$(if $$(strip $$(call flavor-target-remove-chars,	       \
	  $$(call flavor-target-selection,$1),$$(flavor-target-chars))), \
	  $$(error Invalid project Flavor selection))
	@$$(call flavor-dispatch-command,$1)
endef

# $(call generate-flavor-alias, alias, canonical-target)
define generate-flavor-alias
$(call flavor-target-escape,$1): $(call flavor-target-escape,$2) ;
endef

flavor-dispatch-goals	:= $(foreach t,$(flavor-wrapper-goals),	       \
	$(if $(call resolve-port-target,$t),			       \
	  $(if $(call flavor-dispatch-needed,$t),$t)))
flavor-dispatch-targets	:= $(sort $(foreach t,$(flavor-dispatch-goals), \
	$(call resolve-port-target,$t)))

# Avoid duplicate default execution across separate wrapper goal spellings.
flavor-mixed-goals	= $(strip				       \
	$(foreach t,$(flavor-qualified-goals),			       \
	  $(filter $(call flavor-base-target,$t),		       \
	    $(foreach u,$(filter-out $(flavor-qualified-goals),	       \
	      $(flavor-wrapper-goals)),$(call flavor-base-target,$u)))))

depends_exclude_targets	+= $(flavor-qualified-goals)		       \
			   $(flavor-dispatch-goals) $(flavor-dispatch-targets)

ifneq ($(strip $(filter undefined,$(origin PROJECT_PORTS))            \
  $(filter yes,$(UPORTS_DEPENDENCY_INVOCATION) $(_UPORTS_PROJECT_DIRECT))),)
$(foreach t,$(flavor-dispatch-targets),				       \
  $(eval $(call generate-flavor-target,$t)))
$(foreach t,$(flavor-dispatch-goals),				       \
  $(if $(filter-out $(call resolve-port-target,$t),$t),		       \
    $(eval $(call generate-flavor-alias,$t,$(call resolve-port-target,$t)))))
endif

# $(call flavor-request-instance, [group:]port)
flavor-request-instance	= $(call target-base-instance-key,	       \
			    $(call resolve-port-target,$1.fetch))

# $(call flavor-probe-command, instance-key)
# A global FLAVOR is scoped only when the caller selects FLAVOR_REQUEST.
define flavor-probe-command
$(MAKE) -s --no-print-directory					       \
  -C "$(call instance-field,$1,root)/$(call instance-field,$1,origin)" \
  PORTSDIR="$(portdir)" $(call instance-field,$1,env)		       \
  $(if $(strip $(FLAVOR_REQUEST)),,				       \
    $(if $(filter FLAVOR=%,$(call instance-field,$1,env)),	       \
      FLAVOR='$(call dependency-env-value,			       \
        $(call instance-field,$1,env),FLAVOR)',			       \
      --eval='override undefine FLAVOR'))			       \
  $(if $(findstring @,$(FLAVOR_REQUEST)),			       \
    FLAVOR='$(call flavor-target-selection,$(FLAVOR_REQUEST).fetch)')  \
  uports-flavor-metadata > "$$metadata_file" || exit $$?;	       \
$(call flavor-metadata-output,$(strip $1))
endef

.PHONY: flavor-list flavor-check
depends_exclude_targets	+= flavor-list flavor-check
flavor-list flavor-check:
	@$(if $(and $(findstring @,$(FLAVOR_REQUEST)),$(strip $(FLAVOR))), \
	  $(if $(filter $(FLAVOR),				       \
	    $(call flavor-target-selection,$(FLAVOR_REQUEST).fetch)),, \
	    $(error FLAVOR conflicts with the qualified FLAVOR_REQUEST)))
	@$(if $(strip $(FLAVOR_REQUEST)),			       \
	  $(if $(filter 1,$(words $(FLAVOR_REQUEST))),,		       \
	    $(error FLAVOR_REQUEST must name one selected instance))   \
	  $(if $(call resolve-port-target,$(FLAVOR_REQUEST).fetch),,   \
	    $(error Unknown or ambiguous			       \
	      FLAVOR_REQUEST=$(FLAVOR_REQUEST))))
	@metadata_file=$$(mktemp				       \
	  "$${TMPDIR:-/tmp}/uports-flavors.XXXXXX");		       \
	trap 'rm -f "$$metadata_file"' EXIT HUP INT TERM;	       \
	$(if $(strip $(FLAVOR_REQUEST)),			       \
	  $(call flavor-probe-command,				       \
	    $(call flavor-request-instance,$(FLAVOR_REQUEST))),	       \
	  $(foreach p,$(ports_all_group),			       \
	    $(call flavor-probe-command,			       \
	      $(call instance-key,$(call get-group,$p),$(call get-port,$p)))))
