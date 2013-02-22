PUPPET_CONF := $(abspath conf/common/puppet/puppet.conf)
# useful for testing; (e.g. make puppet_master PUPPET_OPTIONS="--noop")
PUPPET_OPTIONS :=
PUPPET_ENVIRONMENT := development
export PUPPET_MODULEPATH := $(ROOT)/src/puppet/modules
PUPPET_CMD = sudo puppet $1 $(PUPPET_OPTIONS) --config $(PUPPET_CONF) --environment $(PUPPET_ENVIRONMENT) 
PUPPET_APPLY_CMD = $(call PUPPET_CMD,apply $1)

%: %.jinja puppet.mk
	$(RENDER) $<

# Define a rule called puppet_$1 for appling a puppet configuration 
# $1 - the name of the configuration, for which there exists a puppet manifest file in src/puppet/snpdb/manifests/
define NODE_RULE
puppet_$1: $(PUPPET_CONF)
	$$(call PUPPET_APPLY_CMD,src/puppet/modules/snpdb/manifests/$1.pp)
.PHONY: puppet_$1
endef

$(eval $(call NODE_RULE,master))
$(eval $(call NODE_RULE,worker))

puppet_config_print: $(PUPPET_CONF)
	$(call PUPPET_CMD,config print) 
