#
# Cloudera Impala local yum repository setup
#

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
	# test that our lighttpd configuration is ok
	lighttpd -t -f $(LIGHTTPD_CONF)
	lighttpd -f $(LIGHTTPD_CONF)
.PHONY: reposerver

updaterepo: $(YUM_REPODATA_FILES) $(SYSTEM_IMPALA_REPO_CONF)
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

#
# Impala installation
#

# Notes on configuring computers in a cluster :
# 1. The NameNode and JobTracker run on the the same "master" host unless the cluster is large (more than a few tens of
#    nodes), and the master host (or hosts) should not run the Secondary NameNode (if used), DataNode or TaskTracker
#    services.
# 2. In a large cluster, it is especially important that the Secondary NameNode (if used) runs on a separate machine from
#    the NameNode.
# 3. Each node in the cluster except the master host(s) should run the DataNode and TaskTracker services.
#
# (https://ccp.cloudera.com/display/CDH4DOC/CDH4+Installation#CDH4Installation-Step2)

## Group install daemon packages, aliased by their role in the cluster (implements the note above)

export SYSTEM_NETWORK_FILE := /etc/sysconfig/network
export CURRENT_HOSTNAME := $(shell hostname -f)

export MASTER_HOSTNAME_SUFFIX := 
export MASTER_HOSTNAME := master$(MASTER_HOSTNAME_SUFFIX)
install_master: install_namenode install_jobtracker $(PATCH_DIR)/network_master.patch
	sudo hostname $(MASTER_HOSTNAME)
	sudo patch -p0 -i $(PATCH_DIR)/network_master.patch

export WORKER_HOSTNAME_SUFFIX := 
export WORKER_HOSTNAME := worker$(WORKER_HOSTNAME_SUFFIX)
install_worker: install_datanode $(PATCH_DIR)/network_worker.patch
	sudo hostname $(WORKER_HOSTNAME)
	sudo patch -p0 -i $(PATCH_DIR)/network_worker.patch

## Daemon packages

install_jobtracker:
	sudo yum install hadoop-0.20-mapreduce-jobtracker

install_namenode:
	sudo yum install hadoop-hdfs-namenode 

# (if used)
# NOTE: I think this is for high availability, but the only thing that might suggest otherwise is when it says "If you 
# configure [HA for the NameNode], do not install hadoop-hdfs-secondarynamenode."
install_secondary_namenode:
	sudo yum install hadoop-hdfs-secondarynamenode 

# All cluster hosts except the JobTracker, NameNode, and Secondary (or Standby) NameNode hosts, running
install_datanode:
	sudo yum install hadoop-0.20-mapreduce-tasktracker hadoop-hdfs-datanode

## Client package

install_client:
	sudo yum install hadoop-0.20-mapreduce-tasktracker hadoop-hdfs-datanode 
