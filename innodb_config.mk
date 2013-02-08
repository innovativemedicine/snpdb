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

stats/%/status.csv: $(INNODB_CONF_FILE)
	@mkdir -p $(dir $@)
	$(call MYSQL_CSV,"show table status") > $@

stats/%/backup.du.csv stats/%/binlog.du.csv stats/%/other.du.csv: $(INNODB_CONF_FILE)
	$(eval STATS_OUT_DIR = stats/$(patsubst conf/%.cnf,%,$^))
	@mkdir -p $(STATS_OUT_DIR)
	$(MAKE_SCRIPTS)/innodb_size.sh $(datadir) $(STATS_OUT_DIR)

# TODO:
# db_size_summary:
# 	input_file
# 	file_size
# 	file_records
# 	datadir_size
# 	backup_size
# 	binlog_size
# 	other_size

# mysql_install_db: $(INIT_MYSQLD)
# .PHONY: mysql_install_db
