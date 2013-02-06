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

# mysql_install_db: $(INIT_MYSQLD)
# .PHONY: mysql_install_db
