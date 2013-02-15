export YUM_REPO_RELATIVE_DOCUMENT_ROOT := yum/repo/CentOS/6.3
export YUM_REPO_DOCUMENT_ROOT := $(HOME)/$(YUM_REPO_RELATIVE_DOCUMENT_ROOT)
# initialize directories if they don't already exist
$(eval $(shell mkdir -p $(YUM_REPO_DOCUMENT_ROOT)/repodata))

export RPM_BINARY_DIRS := $(shell find $(YUM_REPO_DOCUMENT_ROOT) -name '*.rpm' | xargs -d '\n' -n 1 dirname | sort --unique)
export REPO_DIRS := $(addprefix $(YUM_REPO_DOCUMENT_ROOT)/,cloudera-cdh4 cloudera-impala)
export YUM_REPODATA_FILES := $(addprefix $(YUM_REPO_DOCUMENT_ROOT)/repodata/,filelists.xml.gz other.xml.gz primary.xml.gz repomd.xml)
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

reposerver: $(LIGHTTPD_CONF) $(SYSTEM_IMPALA_REPO_CONF) $(YUM_REPODATA_FILES)
	lighttpd -D -f $(LIGHTTPD_CONF)
.PHONY: reposerver

updaterepo: $(YUM_REPODATA_FILES)
.PHONY: updaterepo

$(YUM_REPO_DOCUMENT_ROOT)/repodata/%: $(RPM_BINARY_DIRS) $(REPO_DIRS)
	createrepo $(YUM_REPO_DOCUMENT_ROOT)

$(RPM_BINARY_DIRS) $(REPO_DIRS): import_cloudera_repos

# generic rule for importing a cloudera repository (i.e. cloudera-cdh4, cloudera-impala.repo)
# $1 - rule name to create
# $2 - repository name
# $3 - url of repo (minus trailing $reponame.repo)
# define IMPORT_CLOUDERA_REPO_VARS
# endef
define IMPORT_CLOUDERA_REPO
$(eval export $2_REPO_FILE_URL := $3/$2.repo)
$(eval export $2_REPO_FILE := $(YUM_SYSTEM_REPO_CONF_DIR)/$2.repo)
$1:
	sudo wget "$($2_REPO_FILE_URL)" -O $($2_REPO_FILE)
	reposync --download_path=$(YUM_REPO_DOCUMENT_ROOT) -r $2
	sudo rm $($2_REPO_FILE)
.PHONY: $1
endef

$(eval $(call IMPORT_CLOUDERA_REPO,import_cdh4_repo,cloudera-cdh4,http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh))
$(eval $(call IMPORT_CLOUDERA_REPO,import_impala_repo,cloudera-impala,http://beta.cloudera.com/impala/redhat/6/x86_64/impala))

import_cloudera_repos: import_cdh4_repo import_impala_repo
.PHONY: import_cloudera_repos
