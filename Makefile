# NOTE: run "make help" for basic usage info
ROOT := .
SCRIPTS := $(ROOT)/script
MAKE_SCRIPTS := $(SCRIPTS)/makefile
TESTS := $(ROOT)/test
PYTHON := python
export PYTHON ROOT MAKE_SCRIPTS

include config.mk

VCFPARSER = lib/python/pyvcf/src/vcf/vcfparser.py
VPATH = lib/python/pyvcf
export VCFPARSER

RENDER = $(SCRIPTS)/render.py

.PHONY: all testparse

all: src/vcf/vcfparser.py

help:
	@$(MAKE_SCRIPTS)/usage.py

testparse: src/vcf/vcfparser.py
	$(TESTS)/testparse.sh

%.out: %
	$(RENDER) $<

%: %.jinja
	$(RENDER) $<

# load test

loadtest: $(CLUSTERDB_SCHEMA) $(CLUSTERDB_FILE) $(LOAD_TEST_QUERIES)
	mysqlslap --query="$(shell $(MAKE_SCRIPTS)/stripsql.sh $(LOAD_TEST_QUERIES))" --create-schema=$(CLUSTERDB_NAME) --iterations=$(iterations) --concurrency=$(concurrency)

.PHONY: loadtest

# fill clusterdb

CLUSTERDB_DEPENDENCIES := $(SCRIPTS)/load_genome_summary.py $(PYTHON_SRC_FILES) $(CLUSTERDB_SCHEMA)

define MK_CLUSTERDB 
$(CLUSTERDB_NAME)$(1): $(CLUSTERDB_DEPENDENCIES)
	MYSQL_CLUSTERDB_OPTS="$(4)" CLUSTERDB_ENGINE="$(3)" CLUSTERDB_NAME="$(CLUSTERDB_NAME)$(2)" $(MAKE_SCRIPTS)/mk_clusterdb.sh $(3)
.PHONY: $(CLUSTERDB_NAME)$(2)
endef

# creates clusterdb_local target
$(eval $(call MK_CLUSTERDB,_local,,NDB,$(MYSQL_CLUSTERDB_OPTS_LOCAL)))
# creates clusterdb_local_innodb target
$(eval $(call MK_CLUSTERDB,_innodb_local,_innodb,InnoDB,$(MYSQL_CLUSTERDB_OPTS_LOCAL)))
# creates clusterdb (remote) target
$(eval $(call MK_CLUSTERDB,,,NDB,$(MYSQL_CLUSTERDB_OPTS_REMOTE)))
# creates clusterdb_innodb (remote) target
$(eval $(call MK_CLUSTERDB,_innodb,_innodb,InnoDB,$(MYSQL_CLUSTERDB_OPTS_REMOTE)))

# documentation, maybe use this later
# include Makefile.sphinx

include lib/python/pyvcf/vcf.mk
