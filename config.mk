MYSQL := mysql

MYSQL_CLUSTERDB_LOCAL_PORT := 5000
MYSQL_CLUSTERDB_LOCAL_USER := root 
MYSQL_CLUSTERDB_LOCAL_HOST := 127.0.0.1
MYSQL_CLUSTERDB_OPTS_LOCAL := --user $(MYSQL_CLUSTERDB_LOCAL_USER) --port $(MYSQL_CLUSTERDB_LOCAL_PORT) --host $(MYSQL_CLUSTERDB_LOCAL_HOST)

MYSQL_CLUSTERDB_REMOTE_PORT := 4000 
MYSQL_CLUSTERDB_REMOTE_USER := root 
MYSQL_CLUSTERDB_REMOTE_HOST := 127.0.0.1
MYSQL_CLUSTERDB_OPTS_REMOTE := --user $(MYSQL_CLUSTERDB_REMOTE_USER) --port $(MYSQL_CLUSTERDB_REMOTE_PORT) --host $(MYSQL_CLUSTERDB_REMOTE_HOST)

MYSQL_CLUSTERDB_OPTS := $(MYSQL_CLUSTERDB_OPTS_LOCAL)

CLUSTERDB_NAME := clusterdb
CLUSTERDB_FILE := PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv
CLUSTERDB_FILE_NAME := $(notdir $(CLUSTERDB_FILE))
CLUSTERDB_SCHEMA := src/sql/schema-vc-and-vc_group.sql
SCHEMA_FILENAME = $(patsubst %.sql,%,$(notdir $(CLUSTERDB_SCHEMA)))
CLUSTERDB_ENGINE := NDB
PYTHON_SRC_FILES=$(shell find . -name "*.py" -path "./src/*")
LOAD_GENOME_SUMMARY_OPTS :=
export MYSQL MYSQL_CLUSTERDB_OPTS MYSQL_CLUSTERDB_OPTS_REMOTE MYSQL_CLUSTERDB_OPTS_LOCAL CLUSTERDB_NAME CLUSTERDB_FILE CLUSTERDB_SCHEMA CLUSTERDB_ENGINE LOAD_GENOME_SUMMARY_OPTS
MYSQL_EXEC = $(MYSQL) $(MYSQL_CLUSTERDB_OPTS) $(CLUSTERDB_NAME)
MYSQL_CSV = $(MYSQL_EXEC) --batch -e $(1)

# Loadtest configuration
# queries to run
export QUERY_INPUT_DIR = test/in/query/$(SCHEMA_FILENAME)
export TEST_QUERIES := $(shell find $(QUERY_INPUT_DIR) -name "*.sql" -o -name "*.jinja" | sed "s/\.jinja//" | sort --unique)
LOAD_TEST_QUERY_RESULTS = $(patsubst %.sql,%.mysqlslap.csv,$(subst test/in,test/out,$(TEST_QUERIES)))
EXPLAIN_QUERY_RESULTS = $(patsubst %.sql,%.explain.csv,$(subst test/in,test/out,$(TEST_QUERIES)))
SUMMARY_RESULTS = $(patsubst %.sql,%.summary.csv,$(subst test/in,test/tmp,$(TEST_QUERIES)))
export SUMMARY_FILE = test/out/query/$(SCHEMA_FILENAME)/summary.csv
# sql template file parameters
export min_strand_bias := 2
export min_read_depth := 20
export chromosome := chr1
export min_start_posn := 14773
export max_start_posn := 249239759
# mysqlslap parameters
export iterations := 10 # Number of times to run the tests
export concurrency := 2 # Number of clients to simulate for query to run 

include innodb_config.mk
include yum_config.mk
include puppet.mk
include hive.mk
