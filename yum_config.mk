#
# Cloudera Impala local yum repository setup
#

export YUM_REPO_RELATIVE_DOCUMENT_ROOT := yum/repo/CentOS/6.3
export YUM_REPO_DOCUMENT_ROOT := $(HOME)/$(YUM_REPO_RELATIVE_DOCUMENT_ROOT)
# initialize directories if they don't already exist
$(eval $(shell mkdir -p $(YUM_REPO_DOCUMENT_ROOT)/repodata))

export RPM_BINARY_DIRS := $(shell find $(YUM_REPO_DOCUMENT_ROOT) -name '*.rpm' | xargs -n 1 dirname | sort --unique)
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

%:: %.jinja yum_config.mk
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

export CURRENT_HOSTNAME := $(shell hostname -f)

install_master: install_namenode install_jobtracker 

install_worker: install_datanode

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

## Master/worker configuration

export DFS_NAME_DIRS := /data/1/dfs/nn
# TODO: "Cloudera recommends that you specify at least two directories. One of these should be 
# located on an NFS mount point, unless you will be using a High Availability (HA) 
# configuration." (e.g. /data/1/dfs/nn,/nfsmount/dfs/nn)
export HDFS_DFS_NAME_DIR = $(subst $(space),$(comma),$(DFS_NAME_DIRS))
export HDFS_DFS_PERMISSIONS_SUPERUSERGROUP := hadoop
export HDFS_USER := hdfs
# NOTE:  "Cloudera recommends that you configure the disks on the DataNode in a JBOD 
# configuration, mounted at /data/1/ through /data/N, and configure dfs.data.dir or 
# dfs.datanode.data.dir to specify /data/1/dfs/dn through /data/N/dfs/dn/."
export HDFS_NUM_DFS_DATA_DIRS := 3

# Return the the dfs data directories, separated by a delimeter
# $1 - the delimiter to use
DFS_NAME_DIR_PREFIX := /data
DELIMITED_DFS_DATA_DIRS = $(shell python -c 'print "$(1)".join("$(DFS_NAME_DIR_PREFIX)/%s/dfs/dn" % (i+1) for i in range($(HDFS_NUM_DFS_DATA_DIRS)))')

export HDFS_DFS_DATA_DIR := $(call DELIMITED_DFS_DATA_DIRS,$(comma))
DFS_DATA_DIRS = $(call DELIMITED_DFS_DATA_DIRS,$(space))
define DEPLOY_HDFS
	sudo cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.my_cluster
	sudo alternatives --verbose --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50
	sudo alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster
endef

define MK_HDFS_DIR
	sudo mkdir -p $@
	sudo chown -R $(HDFS_USER):$(HDFS_USER) $@
	sudo chmod go-rx $@
endef
$(DFS_NAME_DIR_PREFIX) $(DFS_NAME_DIRS): configure_master
	$(call MK_HDFS_DIR)
$(DFS_DATA_DIRS): configure_worker
	$(call MK_HDFS_DIR)

# Apply a list of patch files, checking that they all patch sucessfully first
# $1 - space separated patch files
define PATCH_SYSFILE 
	# check that the patch will succeed before we actually go ahead applying it
	cat $(addprefix $(PATCH_DIR)/,$(1)) | patch -p0 --dry-run
	# ok, apply the patch
	cat $(addprefix $(PATCH_DIR)/,$(1)) | sudo patch -p0
endef

# $1 - suffix
define PATCH_RULE
%$1.patch: %.old %$1.new
	diff -c -B $$*.old $$*$1.new -L $$($$(shell perl -pe 's/.*?([^\/]+$1).new$$$$/\U\1_SYSFILE/; s/-/_/g' <<<"$$*$1.new")) > $$@ || test $$$$? = 1
endef

$(eval $(call PATCH_RULE,))
$(eval $(call PATCH_RULE,_master))
$(eval $(call PATCH_RULE,_worker))

%_master.new: %_master.new.jinja yum_config.mk %_common.new.jinja 
	$(RENDER) $<

%_worker.new: %_worker.new.jinja yum_config.mk %_common.new.jinja 
	$(RENDER) $<

# system files to patch; these are used by the %.patch patterns
export NETWORK_SYSFILE := /etc/sysconfig/network
export HOSTS_SYSFILE := /etc/hosts
export HDFS_CONF_DIR := /etc/hadoop/conf.my_cluster
export HDFS_SITE_SYSFILE := $(HDFS_CONF_DIR)/hdfs-site.xml
export HDFS_SITE_WORKER_SYSFILE := $(HDFS_SITE_SYSFILE)
export HDFS_SITE_MASTER_SYSFILE := $(HDFS_SITE_SYSFILE)
export CORE_SITE_SYSFILE := $(HDFS_CONF_DIR)/core-site.xml
SHARED_PATCHES := hosts.patch hdfs/core-site.patch 
NODE_SPECIFIC_PATCHES := network.patch hdfs/hdfs-site.patch

export MASTER_IP_ADDR := 192.168.1.112
export MASTER_BASE_HOSTNAME := master
export MASTER_HOSTNAME := $(MASTER_BASE_HOSTNAME)
MASTER_PATCHES = $(patsubst %.patch,%_master.patch,$(NODE_SPECIFIC_PATCHES)) $(SHARED_PATCHES)

configure_master: install_master $(addprefix $(PATCH_DIR)/,$(MASTER_PATCHES))
	sudo hostname $(MASTER_HOSTNAME)
	# deploy hdfs
	$(call DEPLOY_HDFS)
	$(call PATCH_SYSFILE,$(MASTER_PATCHES))
	# format hdfs namenode
	sudo -u $(HDFS_USER) hadoop namenode -format

export WORKER_BASE_IP_ADDR := 192.168.1
export WORKER_STARTING_IP := 112
export NUM_WORKERS := 1
export WORKER_ID := 0
export WORKER_BASE_HOSTNAME := worker
export WORKER_HOSTNAME := $(WORKER_BASE_HOSTNAME)$(WORKER_ID)
WORKER_PATCHES = $(patsubst %.patch,%_worker.patch,$(NODE_SPECIFIC_PATCHES)) $(SHARED_PATCHES)

configure_worker: install_worker $(PATCH_DIR)/network_worker.patch $(addprefix $(PATCH_DIR)/,$(WORKER_PATCHES))
	sudo hostname $(WORKER_HOSTNAME)
	# deploy hdfs
	$(call DEPLOY_HDFS)
	$(call PATCH_SYSFILE,$(WORKER_PATCHES))

## Convenience rules for starting the master/work setup process

setup_worker: $(DFS_DATA_DIRS)
setup_master: $(DFS_NAME_DIR_PREFIX) $(DFS_NAME_DIRS)
