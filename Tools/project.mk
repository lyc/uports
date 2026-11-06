#
# project.mk - explicit project root normalization and inspection
#

# $(call project-root-group, [group:]port[@flavor])
project-root-group	= $(if $(findstring :,$1),                     \
	$(firstword $(subst :, ,$1)),$(PORTS_GROUP_DEFAULT))

# $(call project-root-name, [group:]port[@flavor])
project-root-name	= $(firstword $(subst @, ,                     \
	$(lastword $(subst :, ,$1))))

# $(call project-root-flavor, [group:]port[@flavor])
project-root-flavor	= $(strip $(if $(findstring @,$1),             \
	$(word 2,$(subst @, ,$1))))

# $(call project-root-origins, [group:]port[@flavor])
project-root-origins	= $(strip $(if $(findstring /,                 \
	$(call project-root-name,$1)),                                 \
	$(filter $(call project-root-name,$1),$(ports_all_raw_lists)), \
	$(filter %/$(call project-root-name,$1),$(ports_all_raw_lists))))

# $(call project-root-spelling, [group:]port[@flavor])
project-root-spelling	= $(if $(findstring :,$1),                     \
	$(call project-root-group,$1):)$(call project-root-name,$1)    \
	$(if $(findstring @,$1),@$(call project-root-flavor,$1))

project-root-chars	= $(group-name-chars) / : @ .
project-flavor-chars	= a b c d e f g h i j k l m n o p q r s t      \
			  u v w x y z 0 1 2 3 4 5 6 7 8 9 _

# $(call project-root-check, [group:]port[@flavor])
define project-root-check
$(if $(strip $(call group-name-invalid,$1,$(project-root-chars))),     \
  $(error Invalid PROJECT_PORTS entry '$1'))
$(if $(findstring @,$1),$(if $(call project-root-flavor,$1),,          \
  $(error Empty PROJECT_PORTS Flavor in '$1')))
$(if $(filter $1,$(subst $(space),,$(call project-root-spelling,$1))),, \
  $(error Malformed PROJECT_PORTS entry '$1'; use [group:]port[@flavor]))
$(if $(filter $(call project-root-group,$1),$(groups_all)),,           \
  $(error Undeclared PROJECT_PORTS group in '$1'))
$(if $(call project-root-origins,$1),,                                 \
  $(error Unknown PROJECT_PORTS recipe '$1'))
$(if $(word 2,$(call project-root-origins,$1)),                        \
  $(error Ambiguous PROJECT_PORTS recipe '$1'; specify category/port))
$(if $(strip $(call group-name-invalid,                                \
  $(call project-root-flavor,$1),$(project-flavor-chars))),            \
  $(error Invalid PROJECT_PORTS Flavor in '$1'))
endef

# $(call project-root-record, [group:]port[@flavor])
# Keep Flavor requests separate until the recipe resolves its actual default.
project-root-record	= $(call project-root-group,$1)|               \
	$(call project-root-origins,$1)|$(call project-root-flavor,$1)

ifneq ($(origin PROJECT_PORTS),undefined)
$(foreach r,$(PROJECT_PORTS),$(call project-root-check,$r))
project_root_requests	:= $(call stable-unique,$(foreach r,           \
	$(PROJECT_PORTS),$(subst $(space),,$(call project-root-record,$r))))
endif

# $(call project-root-field, field-number, root-record)
project-root-field	= $(word $1,$(subst |, ,$2))

# $(call project-root-tree, root-record)
project-root-tree	= $(port_$(notdir $(call project-root-field,2,$1))_root)

# $(call project-root-directory, root-record)
project-root-directory = $(call project-root-tree,$1)/$(call project-root-field,2,$1)

# $(call project-root-probe, group|origin|requested-flavor)
define project-root-probe
$(MAKE) -s --no-print-directory                                        \
  -C "$(call project-root-directory,$1)"                               \
  $(filter-out FLAVOR=%,                                               \
    $(call compose-port-env,$(call project-root-field,1,$1),           \
      $(notdir $(call project-root-field,2,$1))))                      \
  PORTSDIR="$(portdir)"                                                \
  $(if $(call project-root-field,3,$1),                                \
    FLAVOR='$(call project-root-field,3,$1)',                          \
    --eval='override undefine FLAVOR')                                 \
  uports-flavor-metadata > "$$work/metadata" || exit $$?;              \
selected=$$(sed -n 's/^selected|//p' "$$work/metadata");               \
printf '%s|%s|%s\n' '$(call project-root-field,1,$1)'                  \
  '$(call project-root-field,2,$1)' "$$selected" >> "$$work/roots";
endef

.PHONY: project-ports-list
depends_exclude_targets	+= project-ports-list
project-ports-list:
	@$(if $(filter undefined,$(origin PROJECT_PORTS)),             \
	  $(error Define PROJECT_PORTS to inspect explicit roots))
	@set -e; work=$$(mktemp -d                                     \
	  "$${TMPDIR:-/tmp}/uports-project-roots.XXXXXX");             \
	trap 'rm -rf "$$work"' EXIT HUP INT TERM;                      \
	: > "$$work/roots";                                            \
	$(foreach r,$(project_root_requests),                          \
	  $(call project-root-probe,$r))                               \
	printf '%s\n' 'group|origin|flavor';                           \
	awk '!seen[$$0]++' "$$work/roots"
