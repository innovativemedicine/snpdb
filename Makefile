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

%.out: % config.mk
	$(RENDER) $<

%: %.jinja config.mk
	$(RENDER) $<

# generic rule "%: %.jinja config.mk" doesn't seem to work for matching %.sql dependency for %.mysqlslap...
# %.sql: %.sql.jinja config.mk
%.sql: %.sql.jinja config.mk
	$(RENDER) $<

test/out/query/%.mysqlslap.csv: test/in/query/%.sql $(CLUSTERDB_FILE) $(CLUSTERDB_SCHEMA)
	@mkdir -p $(dir $@)
	$(eval MYSQLSLAP_QUERY = $(shell $(MAKE_SCRIPTS)/strip_sql.sh $<))
	@if [ "$(MYSQLSLAP_QUERY)" == ";" ]; then \
		echo "Skipping $< (empty query file)"; \
	else \
		echo mysqlslap --create-schema=$(CLUSTERDB_NAME) --iterations=$(iterations) --concurrency=$(concurrency) --query=$<; \
		$(MAKE_SCRIPTS)/mysqlslap_wrapper.sh --create-schema=$(CLUSTERDB_NAME) --iterations=$(iterations) --concurrency=$(concurrency) --query="$(MYSQLSLAP_QUERY)" --csv | sed "s#^#$<,#" > $@; \
	fi;

$(MYSQLSLAP_SUMMARY_FILE): $(LOAD_TEST_QUERY_RESULTS)
	# Ignore files that don't exist because their queries were empty
	@echo "query_file,load_type,avg_time,min_time,max_time,clients,queries_per_client" > $@
	# Sort output by max_time, min_time, avg_time, query_file
	@cat $(LOAD_TEST_QUERY_RESULTS) | sort -g -k 5 -k 4 -k 3 -k 1 -nk 1 -t, -r >> $@

# load test

loadtest: test/out/query/$(SCHEMA_FILENAME)/summary.csv

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
