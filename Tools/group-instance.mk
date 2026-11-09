#
# group-instance.mk - group instance selection and bounded metadata workers
#

# $(call group-member-group, [group:]port[@flavor])
group-member-group	= $(strip $(if $(findstring :,$1),	       \
	$(firstword $(subst :, ,$1)),				       \
	$(or $(filter $(PORTS_GROUP_DEFAULT),			       \
	  $($(notdir $(call group-member-name,$1))_groups)),	       \
	  $(firstword $($(notdir $(call group-member-name,$1))_groups)),\
	  $(PORTS_GROUP_DEFAULT))))

# $(call group-member-name, [group:]port[@flavor])
group-member-name	= $(firstword $(subst @, ,		       \
	$(lastword $(subst :, ,$1))))

# $(call group-member-flavor, [group:]port[@flavor])
group-member-flavor	= $(strip $(if $(findstring @,$1),	       \
	$(word 2,$(subst @, ,$1))))

# $(call group-member-origins, [group:]port[@flavor])
group-member-origins	= $(strip $(if $(findstring /,		       \
	$(call group-member-name,$1)),				       \
	$(filter $(call group-member-name,$1),$(ports_all_raw_lists)), \
	$(filter %/$(call group-member-name,$1),$(ports_all_raw_lists))))

# $(call group-member-spelling, [group:]port[@flavor])
group-member-spelling	= $(if $(findstring :,$1),		       \
	$(call group-member-group,$1):)$(call group-member-name,$1)    \
	$(if $(findstring @,$1),@$(call group-member-flavor,$1))

group-member-chars	= $(group-name-chars) / : @ .
group-flavor-chars	= a b c d e f g h i j k l m n o p q r s t      \
			  u v w x y z 0 1 2 3 4 5 6 7 8 9 _

# $(call group-member-check, [group:]port[@flavor])
define group-member-check
$(if $(strip $(call group-name-invalid,$1,$(group-member-chars))),     \
  $(error Invalid package request '$1'))
$(if $(findstring @,$1),$(if $(call group-member-flavor,$1),,	       \
  $(error Empty package Flavor in '$1')))
$(if $(filter $1,$(subst $(space),,$(call group-member-spelling,$1))),,\
  $(error Malformed package request '$1'; use [group:]port[@flavor]))
$(if $(filter $(call group-member-group,$1),$(groups_all)),,	       \
  $(error Undeclared package group in '$1'))
$(if $(or $(findstring :,$1),					       \
  $(filter $(PORTS_GROUP_DEFAULT),				       \
    $($(notdir $(call group-member-name,$1))_groups))),,	       \
  $(if $(word 2,$($(notdir $(call group-member-name,$1))_groups)),     \
    $(error Ambiguous package group for '$1'; specify group:port)))
$(if $(call group-member-origins,$1),,				       \
  $(error Unknown package recipe '$1'))
$(if $(word 2,$(call group-member-origins,$1)),			       \
  $(error Ambiguous package recipe '$1'; specify category/port))
$(if $(strip $(call group-name-invalid,				       \
  $(call group-member-flavor,$1),$(group-flavor-chars))),	       \
  $(error Invalid package Flavor in '$1'))
endef

# $(call group-member-selection, [group:]port[@flavor])
# Explicit Flavor wins over the configured group-instance default.
group-member-selection = $(strip $(or				       \
  $(call group-member-flavor,$1),				       \
  $(patsubst FLAVOR=%,%,$(lastword $(filter FLAVOR=%,		       \
    $(call compose-port-env,$(call group-member-group,$1),$(notdir $(call group-member-name,$1))))))))

# $(call group-member-record, [group:]port[@flavor])
group-member-record = $(call group-member-group,$1)|		       \
  $(call group-member-origins,$1)|$(call group-member-selection,$1)

# $(call group-request-target, [group:]port[@flavor].phase)
# Apply scoped defaults only to requested roots, never dependency references.
group-request-target = $(subst $(space),,			       \
  $(call group-member-group,$(basename $1)):			       \
  $(notdir $(call group-member-name,$(basename $1)))		       \
  $(if $(call group-member-selection,$(basename $1)),		       \
    @$(call group-member-selection,$(basename $1)))$(suffix $1))

# Aggregate membership comes directly from the configured group instances.
group_provider_bindings := $(ports_all_group)
group_member_requests = $(strip $(foreach p,$(ports_root_group),       \
  $(call get-group,$p)|$(call rm-groups,$p)|$(strip		       \
  $(patsubst FLAVOR=%,%,$(lastword $(filter FLAVOR=%,		       \
    $(call compose-port-env,$(call get-group,$p),$(call get-port,$p))))))))

# $(call group-member-field, field-number, root-record)
group-member-field	= $(word $1,$(subst |, ,$2))

# $(call group-member-tree, root-record)
group-member-tree	= $(port_$(notdir $(call group-member-field,2,$1))_root)

# $(call group-member-directory, root-record)
group-member-directory = $(call group-member-tree,$1)/$(call group-member-field,2,$1)

# $(call group-member-probe, group|origin|requested-flavor)
define group-member-probe
$(MAKE) -s --no-print-directory					       \
  -C "$(call group-member-directory,$1)"			       \
  $(filter-out FLAVOR=%,					       \
    $(call compose-port-env,$(call group-member-field,1,$1),$(notdir $(call group-member-field,2,$1))))\
  PORTSDIR="$(portdir)"						       \
  $(if $(call group-member-field,3,$1),				       \
    FLAVOR='$(call group-member-field,3,$1)',			       \
    --eval='override undefine FLAVOR')				       \
  uports-flavor-metadata > "$$work/metadata" || exit $$?;
endef

# $(call group-member-worker, member-record, requested-target)
# Private files preserve declaration order without concurrent shared writes.
define group-member-worker
if test "$$failed" = 0; then					       \
  rows=$$((rows + 1));						       \
  (								       \
    work="$$directory/$$rows"; mkdir -p "$$work";		       \
    $(call group-selection-probe,$1,$2)				       \
  ) 2> "$$directory/$$rows.errors" &				       \
  pids="$$pids $$!"; active=$$((active + 1));			       \
  if test "$$active" -ge "$$jobs"; then				       \
    for pid in $$pids; do					       \
      wait "$$pid" || failed=1;					       \
    done;							       \
    pids=; active=0;						       \
  fi;								       \
fi;
endef

# Explicit requests may select any discovered recipe in a declared group.
group_explicit_records	:= $(foreach t,				       \
	$(MAKECMDGOALS) $(DEPENDENCY_REQUEST) $(DEPENDENCY_REQUESTS),  \
	$(if $(and $(filter $(addprefix %.,$(suffix_all_lists))	       \
	  %.flavor-check,$t),					       \
	  $(filter-out ports $(groups_all) $(categories_all),	       \
	    $(basename $t))),					       \
	  $(call group-member-check,$(basename $t))		       \
	  $(subst $(space),,$(call group-member-record,$(basename $t)))))
ports_all_group		:= $(call stable-unique,		       \
	$(ports_all_group) $(foreach r,$(group_explicit_records),      \
	  $(call group-member-field,1,$r)@$(call group-member-field,2,$r)))
ifneq ($(filter yes,$(UPORTS_DEPENDENCY_INVOCATION)),)
ifneq ($(strip $(DEPENDENCY_METADATA_SOURCE)),)
group_snapshot_instances := $(shell sed -n			       \
	's/^group-instance|\([^|]*\)|\([^|]*\)$$/\1@\2/p'	       \
	"$(DEPENDENCY_METADATA_SOURCE)")
ports_all_group		:= $(call stable-unique,		       \
	$(ports_all_group) $(group_snapshot_instances))
endif
endif
group_unknown_providers := $(filter-out $(ports_all_raw_lists),	       \
	$(foreach p,$(ports_all_group),$(call rm-groups,$p)))
ifneq ($(strip $(group_unknown_providers)),)
$(error Unknown group instance origins: $(group_unknown_providers))
endif
group_unknown_groups	:= $(filter-out $(groups_all),		       \
	$(foreach p,$(ports_all_group),$(call get-group,$p)))
ifneq ($(strip $(group_unknown_groups)),)
$(error Undeclared instance groups: $(group_unknown_groups))
endif
$(foreach g,$(groups_all),$(eval $(call generate-groups-lists,$g)))
$(foreach p,$(ports_all),$(eval $(call generate-port-groups-lists,$p)))
ports_all_group_extra	:= $(sort $(foreach p,$(ports_all_group),      \
	$(call filter-out-group-extra,$p)))
$(foreach p,$(ports_all_group),					       \
  $(eval $(call generate-port-env,$(call get-group,$p),$(call get-port,$p))))
