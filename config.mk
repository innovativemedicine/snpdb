MYSQL := mysql
MYSQL_CLUSTERDB_OPTS_REMOTE := --user root --port 3308 --host 127.0.0.1
MYSQL_CLUSTERDB_OPTS_LOCAL := --user root
MYSQL_CLUSTERDB_OPTS := $(MYSQL_CLUSTERDB_OPTS_REMOTE)
CLUSTERDB_NAME := clusterdb
CLUSTERDB_FILE := PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv.head.5
CLUSTERDB_SCHEMA := src/sql/schema-vc-and-vc_group.sql
SCHEMA_FILENAME = $(patsubst %.sql,%,$(notdir $(CLUSTERDB_SCHEMA)))
CLUSTERDB_ENGINE := NDB
PYTHON_SRC_FILES=$(shell find . -name '*.py' -path "./src/*")
LOAD_GENOME_SUMMARY_OPTS := 
export MYSQL MYSQL_CLUSTERDB_OPTS_REMOTE MYSQL_CLUSTERDB_OPTS_LOCAL CLUSTERDB_NAME CLUSTERDB_FILE CLUSTERDB_SCHEMA CLUSTERDB_ENGINE LOAD_GENOME_SUMMARY_OPTS

# Loadtest configuration
# queries to run
export LOAD_TEST_INPUT_DIR = test/in/query/$(SCHEMA_FILENAME)
export LOAD_TEST_QUERIES := $(shell find $(LOAD_TEST_INPUT_DIR) -name '*.sql' -o -name '*.jinja' | sed 's/\.jinja//' | sort --unique)
LOAD_TEST_QUERY_RESULTS = $(patsubst %.sql,%.mysqlslap.csv,$(subst test/in,test/out,$(LOAD_TEST_QUERIES)))
export MYSQLSLAP_SUMMARY_FILE = test/out/query/$(SCHEMA_FILENAME)/summary.csv
# sql template file parameters
export min_strand_bias := 2
export min_read_depth := 20
export chromosome := chr1
export min_start_posn := 14773
export max_start_posn := 249239759
# mysqlslap parameters
export iterations := 10 # Number of times to run the tests
export concurrency := 2 # Number of clients to simulate for query to run 

# export LOAD_TEST_QUERIES strand_bias iterations concurrency
