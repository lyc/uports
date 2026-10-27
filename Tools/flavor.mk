#
# flavor.mk - demand-driven Flavor discovery for selected project instances
#

FLAVOR_REQUEST		?=

# $(call flavor-request-instance, [group@]port)
flavor-request-instance	= $(call target-instance-key,		       \
			    $(call resolve-port-target,$1.fetch))

# $(call flavor-probe-command, instance-key)
# A global FLAVOR is scoped only when the caller selects FLAVOR_REQUEST.
define flavor-probe-command
$(MAKE) -s --no-print-directory					       \
  -C "$(call instance-field,$1,root)/$(call instance-field,$1,origin)" \
  PORTSDIR="$(portdir)" $(call instance-field,$1,env)		       \
  $(if $(strip $(FLAVOR_REQUEST)),,--eval='override undefine FLAVOR')  \
  uports-flavor-metadata > "$$metadata_file" || exit $$?;	       \
sed 's/^/$(strip $1)|/' "$$metadata_file";
endef

.PHONY: flavor-list flavor-check
depends_exclude_targets	+= flavor-list flavor-check
flavor-list flavor-check:
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
