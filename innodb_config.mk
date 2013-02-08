SHELL := /bin/bash
# configuration options for mars/innodb plain mysqld 
export datadir := $(abspath tmp/mars/innodb/data)
export socket := $(datadir)/mysql.sock
export basedir := $(abspath $(shell dirname $$(dirname $$(which mysqld))))
export port := $(MYSQL_CLUSTERDB_LOCAL_PORT)

export INNODB_CONF_FILE := conf/mars/innodb/mysqld/my-innodb-heavy-4G.cnf

INIT_MYSQLD = $(datadir)/mysql_install_db.txt

$(INNODB_CONF_FILE): $(INNODB_CONF_FILE).jinja innodb_config.mk 
	$(RENDER) $<

$(datadir):
	mkdir -p $@

mysqld_innodb_start: $(INNODB_CONF_FILE) $(datadir) $(INIT_MYSQLD)
	cd $(basedir); \
		bin/mysqld_safe --defaults-file=$(abspath $(INNODB_CONF_FILE)) --basedir=$(basedir)
.PHONY: mysqld_innodb_start

$(INIT_MYSQLD): $(INNODB_CONF_FILE) $(datadir)
	$(basedir)/scripts/mysql_install_db --defaults-file=$(abspath $(INNODB_CONF_FILE)) --basedir=$(basedir)
	touch $@

mysqld_innodb_shutdown:
	mysqladmin --defaults-file=$(abspath $(INNODB_CONF_FILE)) $(MYSQL_CLUSTERDB_OPTS_LOCAL) shutdown
.PHONY: mysqld_innodb_shutdown 

stats/%/status.csv:
	@mkdir -p $(dir $@)
	$(call MYSQL_CSV,"show table status") > $@

stats/%/backup.du.csv stats/%/binlog.du.csv stats/%/other.du.csv:
	$(eval STATS_OUT_DIR = stats/$(patsubst conf/%.cnf,%,$^))
	@mkdir -p $(STATS_OUT_DIR)
	$(MAKE_SCRIPTS)/innodb_size.sh $(datadir) $(STATS_OUT_DIR)

GET_TOTAL_SIZE = $(shell awk 'END { print $$1 }' $(1))
stats/%/$(CLUSTERDB_FILE_NAME)/db_size_summary.csv: \
	stats/%/$(CLUSTERDB_FILE_NAME)/backup.du.csv \
	stats/%/$(CLUSTERDB_FILE_NAME)/binlog.du.csv \
	stats/%/$(CLUSTERDB_FILE_NAME)/other.du.csv \
	stats/%/$(CLUSTERDB_FILE_NAME)/status.csv
	$(eval BACKUP_FILE = $(word 1,$^))
	$(eval BINLOG_FILE = $(word 2,$^))
	$(eval OTHER_FILE = $(word 3,$^))
	$(eval STATUS_FILE = $(word 4,$^))
	paste \
		<(echo input_file; echo $(CLUSTERDB_FILE_NAME)) \
		<(echo file_size; du -b -c $(CLUSTERDB_FILE) | awk 'END { print $$1 }') \
		<(echo file_records; tail -n +2 $(CLUSTERDB_FILE) | wc -l | awk '{ print $$1 }') \
		<(echo datadir_size; echo $$(( $(call GET_TOTAL_SIZE,$(BACKUP_FILE)) + $(call GET_TOTAL_SIZE,$(BINLOG_FILE)) + $(call GET_TOTAL_SIZE,$(OTHER_FILE)) )) ) \
		<(echo backup_size; echo $(call GET_TOTAL_SIZE,$(BACKUP_FILE))) \
		<(echo binlog_size; echo $(call GET_TOTAL_SIZE,$(BINLOG_FILE))) \
		<(echo other_size; echo $(call GET_TOTAL_SIZE,$(OTHER_FILE))) \
		> $@

# mysql_install_db: $(INIT_MYSQLD)
# .PHONY: mysql_install_db
