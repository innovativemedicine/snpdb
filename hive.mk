export HIVE_SNPDB_LOADFILES := $(abspath $(shell find data -name '*.hld'))
export HIVE_SNPDB_PARTITIONS := $(patsubst %.hld,%,$(notdir $(HIVE_SNPDB_LOADFILES)))
export HIVE_SNPDB_TABLE := variant
HIVE_DDL = $(shell $(MAKE_SCRIPTS)/strip_sql.sh $1)

export HIVE_1_HIVE_TABLE_DDL := $(call HIVE_DDL,src/hive/schema/snpdb.hql)
export HIVE_PARTITIONED_HIVE_TABLE_DDL := $(call HIVE_DDL,src/hive/schema/snpdb_partitioned.hql)
