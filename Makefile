# NOTE: run "make help" for basic usage info
ROOT := .
SCRIPTS := $(ROOT)/script
TESTS := $(ROOT)/test
3RDPARTY_SCRIPTS := $(ROOT)/3rdparty/script
PYTHON := python

export PYTHON ROOT

MYSQL := mysql
MYSQL_CLUSTERDB_OPTS_REMOTE := --user root --port 3308 --host 127.0.0.1
MYSQL_CLUSTERDB_OPTS_LOCAL := --user root
CLUSTERDB_NAME := clusterdb
CLUSTERDB_FILE := PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv.head.5
CLUSTERDB_SCHEMA := src/sql/schema-vc-and-vc_group.sql
CLUSTERDB_ENGINE := NDB

export MYSQL MYSQL_CLUSTERDB_OPTS_REMOTE MYSQL_CLUSTERDB_OPTS_LOCAL CLUSTERDB_NAME CLUSTERDB_FILE CLUSTERDB_SCHEMA CLUSTERDB_ENGINE

PYTHON_SRC_FILES=$(shell find . -name '*.py' -path "./src/*")

.PHONY: all testparse

all: src/python/vcf/vcfparser.py

help:
	@echo "USAGE:"
	@echo "clusterdb              create a $(CLUSTERDB_NAME) database using $(SCRIPTS)/mk_clusterdb.sh with connect string \"$(MYSQL_CLUSTERDB_OPTS_REMOTE)\""
	@echo "clusterdb_innodb       create a $(CLUSTERDB_NAME) database using $(SCRIPTS)/mk_clusterdb.sh with connect string \"$(MYSQL_CLUSTERDB_OPTS_REMOTE)\" (InnoDB engine)"
	@echo "clusterdb_local        create a $(CLUSTERDB_NAME) database using $(SCRIPTS)/mk_clusterdb.sh with connect string \"$(MYSQL_CLUSTERDB_OPTS_LOCAL)\""
	@echo "clusterdb_local_innodb create a $(CLUSTERDB_NAME) database using $(SCRIPTS)/mk_clusterdb.sh with connect string \"$(MYSQL_CLUSTERDB_OPTS_LOCAL)\" (InnoDB engine)"

src/python/vcf/vcfparser.py: src/python/vcf/vcfparser.g
	$(3RDPARTY_SCRIPTS)/yapps2.py $<
	chmod +x $@

testparse: src/python/vcf/vcfparser.py
	$(TESTS)/testparse.sh

# fill clusterdb

CLUSTERDB_DEPENDENCIES := $(SCRIPTS)/load_genome_summary.py $(PYTHON_SRC_FILES) $(CLUSTERDB_SCHEMA)

define MK_CLUSTERDB 
$(CLUSTERDB_NAME)$(1): $(CLUSTERDB_DEPENDENCIES)
	MYSQL_CLUSTERDB_OPTS="$(3)" CLUSTERDB_ENGINE="$(2)" $(SCRIPTS)/mk_clusterdb.sh $(2)
.PHONY: $(CLUSTERDB_NAME)$(1)
endef

# creates clusterdb_local target
$(eval $(call MK_CLUSTERDB,_local,NDB,$(MYSQL_CLUSTERDB_OPTS_LOCAL)))
# creates clusterdb_local_innodb target
$(eval $(call MK_CLUSTERDB,_local_innodb,InnoDB,$(MYSQL_CLUSTERDB_OPTS_LOCAL)))
# creates clusterdb (remote) target
$(eval $(call MK_CLUSTERDB,,NDB,$(MYSQL_CLUSTERDB_OPTS_REMOTE)))
# creates clusterdb_innodb (remote) target
$(eval $(call MK_CLUSTERDB,_innodb,InnoDB,$(MYSQL_CLUSTERDB_OPTS_REMOTE)))

# documentation, maybe use this later
# include Makefile.sphinx
