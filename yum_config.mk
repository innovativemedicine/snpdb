export YUM_REPO_RELATIVE_DOCUMENT_ROOT := yum/repo/CentOS/6.3
export YUM_REPO_DOCUMENT_ROOT := $(HOME)/$(YUM_REPO_RELATIVE_DOCUMENT_ROOT)
export YUM_REPO_PORT := 45454
export YUM_REPO_HOSTNAME := 127.0.0.1
export YUM_SYSTEM_REPO_CONF_DIR := /etc/yum.repos.d

export LIGHTTPD_CONF := conf/common/lighttpd/lighttpd.conf
export IMPALA_REPO_CONF := conf/common/yum/impala.repo
export SYSTEM_IMPALA_REPO_CONF := $(YUM_SYSTEM_REPO_CONF_DIR)/$(notdir $(IMPALA_REPO_CONF))

RPM := 
RPM_BASEARCH = $(shell sed 's/.*\.\([^\.]\+\).rpm/\1/' <<<"$(RPM)")

%: %.jinja yum_config.mk
	$(RENDER) $<

$(SYSTEM_IMPALA_REPO_CONF): $(IMPALA_REPO_CONF)
	sudo cp $< $@

reposerver: $(LIGHTTPD_CONF) $(SYSTEM_IMPALA_REPO_CONF)
	lighttpd -D -f $(LIGHTTPD_CONF)
.PHONY: reposerver

addrpm:
	# test -f $(RPM) || echo "Must provide an rpm to add in RPM" && exit 1
	mkdir -p $(YUM_REPO_DOCUMENT_ROOT)/$(RPM_BASEARCH)
	mv $(RPM) $(YUM_REPO_DOCUMENT_ROOT)/$(RPM_BASEARCH)
	$(MAKE_SCRIPTS)/update_yum_repo.sh
.PHONY: addrpm

updaterepo:
	createrepo $(YUM_REPO_DOCUMENT_ROOT)
.PHONY: updaterepo


# generic rule for importing a cloudera repository (i.e. cloudera-cdh4, cloudera-impala.repo)
# $1 - rule name to create
# $2 - repository name
# $3 - url of repo (minus trailing $reponame.repo)
define IMPORT_CLOUDERA_REPO_VARS
export $2_REPO_FILE_URL := $3/$2.repo
export $2_REPO_FILE := $(YUM_SYSTEM_REPO_CONF_DIR)/$2.repo
endef

define IMPORT_CLOUDERA_REPO
$1:
	sudo wget "$$($(2)_REPO_FILE_URL)" -O $$($(2)_REPO_FILE)
	reposync --download_path=$(YUM_REPO_DOCUMENT_ROOT) -r $2
	sudo rm $$($(2)_REPO_FILE)
	createrepo $(YUM_REPO_DOCUMENT_ROOT)

.PHONY $1

endef


# export cloudera-cdh4_REPO_FILE_URL := http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/cloudera-cdh4.repo
# export cloudera-cdh4_REPO_FILE := /etc/yum.repos.d/cloudera-cdh4.repo
# import_cdh4_repo:
# 	echo $(cloudera-cdh4_REPO_FILE_URL) 
# 	echo $(cloudera-cdh4_REPO_FILE)
# 	sudo wget "$(cloudera-cdh4_REPO_FILE_URL)" -O $(cloudera-cdh4_REPO_FILE)
# 	reposync --download_path=/home/james/yum/repo/CentOS/6.3 -r cloudera-cdh4
# 	sudo rm $(cloudera-cdh4_REPO_FILE)
# 	createrepo /home/james/yum/repo/CentOS/6.3

# $(info $(call IMPORT_CLOUDERA_REPO,import_cdh4_repo,cloudera-cdh4,http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh))

$(eval $(call IMPORT_CLOUDERA_REPO_VARS,import_cdh4_repo,cloudera-cdh4,http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh))
$(eval $(call IMPORT_CLOUDERA_REPO,import_cdh4_repo,cloudera-cdh4,http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh))

# 
# $(eval $(call IMPORT_CLOUDERA_REPO,import_impala_repo,cloudera-impala,http://beta.cloudera.com/impala/redhat/6/x86_64/impala/cloudera-impala.repo))

import_cloudera_repos: import_cdh4_repo import_impala_repo
.PHONY: import_cloudera_repos

# export CDH4_REPO := http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/cloudera-cdh4.repo
# export CDH4_REPO_FILE := $(YUM_SYSTEM_REPO_CONF_DIR)/cloudera-cdh4.repo
# import_cloudera_repo:
# 	sudo wget "$(CDH4_REPO)" -O $(CDH4_REPO_FILE)
# 	reposync --download_path=$(YUM_REPO_DOCUMENT_ROOT) -r cloudera-cdh4
# 	sudo rm $(CDH4_REPO_FILE)
# 	createrepo $(YUM_REPO_DOCUMENT_ROOT)
# 
# 	http://beta.cloudera.com/impala/redhat/6/x86_64/impala/cloudera-impala.repo
# .PHONY: import_cloudera_repo
