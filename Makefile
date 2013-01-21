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

test/tmp/query/%.sql.strip: test/in/query/%.sql $(CLUSTERDB_FILE) $(CLUSTERDB_SCHEMA)
	@mkdir -p $(dir $@)
	$(MAKE_SCRIPTS)/strip_sql.sh $< > $@

test/out/query/%.mysqlslap.csv: test/tmp/query/%.sql.strip $(CLUSTERDB_FILE) $(CLUSTERDB_SCHEMA)
	@mkdir -p $(dir $@)
	$(eval MYSQL_QUERY = $(shell cat $<))
	@if [ "$(MYSQL_QUERY)" == ";" ]; then \
		echo "Skipping $< (empty query file)"; \
		touch $@; \
	else \
		echo mysqlslap --create-schema=$(CLUSTERDB_NAME) --iterations=$(iterations) --concurrency=$(concurrency) --query="$<" \> $@; \
		$(MAKE_SCRIPTS)/mysqlslap_wrapper.sh --create-schema=$(CLUSTERDB_NAME) --iterations=$(iterations) --concurrency=$(concurrency) --query="$<" --csv | sed 's#^#$<,#; s/,/	/g' > $@; \
	fi;

test/out/query/%.explain.csv: test/tmp/query/%.sql.strip $(CLUSTERDB_FILE) $(CLUSTERDB_SCHEMA)
	@mkdir -p $(dir $@)
	$(eval MYSQL_QUERY = $(shell cat $<))
	$(eval CMD = $(call MYSQL_CSV,"explain partitions $(MYSQL_QUERY)") > $@)
	@if [ "$(MYSQL_QUERY)" == ";" ]; then \
		echo "Skipping $< (empty query file)"; \
		touch $@; \
	else \
		echo '$(CMD)'; \
		$(CMD); \
	fi;

test/tmp/query/%.summary.csv: test/out/query/%.mysqlslap.csv test/out/query/%.explain.csv
	awk 'FNR > 1' $(word 2,$^) | $(MAKE_SCRIPTS)/cross.py $< - > $@

$(SUMMARY_FILE): test/tmp/query/$(SCHEMA_FILENAME)/explain_header.csv $(SUMMARY_RESULTS) 
	# Ignore files that don't exist because their queries were empty
	@echo "query_file unknown load_type avg_time min_time max_time clients queries_per_client" | sed 's/ /	/g' | paste - $< > $@
	# Sort output by max_time, min_time, avg_time, query_file
	@cat $(SUMMARY_RESULTS) | sort -g -k 6 -k 5 -k 4 -nk 1 -t$$'\t' -r >> $@

test/tmp/query/%explain_header.csv: $(EXPLAIN_QUERY_RESULTS)
	@mkdir -p $(dir $@)
	awk 'FNR == 1' $(EXPLAIN_QUERY_RESULTS) | sort --unique > $@
	@test "`wc -l $@ | awk '{print $$1}'`" = "1" || (echo "Saw different output columns for explain query result files:" && awk 'FNR == 1' $(EXPLAIN_QUERY_RESULTS) | sort --unique && rm $@ && exit 1)

# load test

loadtest: $(SUMMARY_FILE)

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
