MYSQL := mysql
MYSQL_CLUSTERDB_OPTS_REMOTE := --user root --port 3308 --host 127.0.0.1
MYSQL_CLUSTERDB_OPTS_LOCAL := --user root
CLUSTERDB_NAME := clusterdb
CLUSTERDB_FILE := PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv.head.5
CLUSTERDB_SCHEMA := src/sql/schema-vc-and-vc_group.sql
SCHEMA_FILENAME = $(patsubst %.sql,%,$(notdir CLUSTERDB_SCHEMA))
CLUSTERDB_ENGINE := NDB
PYTHON_SRC_FILES=$(shell find . -name '*.py' -path "./src/*")
LOAD_GENOME_SUMMARY_OPTS := 
export MYSQL MYSQL_CLUSTERDB_OPTS_REMOTE MYSQL_CLUSTERDB_OPTS_LOCAL CLUSTERDB_NAME CLUSTERDB_FILE CLUSTERDB_SCHEMA CLUSTERDB_ENGINE LOAD_GENOME_SUMMARY_OPTS


# Loadtest configuration
# queries to run
LOAD_TEST_QUERIES := $(patsubst %.sql.jinja,%.sql,$(wildcard test/query/$(SCHEMA_FILENAME)/*))
# sql template file parameters
strand_bias := 2
# mysqlslap parameters
iterations := 10 # Number of times to run the tests
concurrency := 2 # Number of clients to simulate for query to run 
export LOAD_TEST_QUERIES strand_bias iterations concurrency
