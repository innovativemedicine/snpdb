# The node that will be the CM server may use this declaration:
# This will skip installation of the CDH software as it is not required.

# $master_hostname      = $snpdb::params::master_hostname,
# $master_ip            = $snpdb::params::master_ip,
# $worker_base_ip_addr  = $snpdb::params::worker_base_ip_addr,
# $worker_starting_ip   = $snpdb::params::worker_starting_ip,
# $num_workers          = $snpdb::params::num_workers,
# $worker_id            = $snpdb::params::worker_id,
# $worker_base_hostname = $snpdb::params::worker_base_hostname,
# $worker_hostname      = $snpdb::params::worker_hostname

class snpdb::master(
    $cdh_version = $snpdb::params::cdh_version,
    $cm_version = $snpdb::params::cm_version,
    $hive_metastore_password = $snpdb::params::hive_metastore_password,
    $hive_metastore_db = $snpdb::params::hive_metastore_db,
    $hive_metastore_user = $snpdb::params::hive_metastore_user
) inherits snpdb::params {
    # host { $master_hostname:
    #     ip => $master_ip,
    # } ->
    # file { "/etc/hosts":
    #     owner => root,
    #     group => root,
    #     mode => 644,
    #     content => template("snpdb/hosts.erb"),
    # } ->
    class { 'snpdb::hosts': } ->
    class { 'snpdb::common::disable_selinux': } ->
    class { 'cloudera::repo':

        # from the github repo readme
        # cdh_version => '4.1',
        # cm_version  => '4.1',

        # what i tried orignally
        # cdh_version => '4.1',
        # cm_version  => '4.1.3',

        # newest possible
        # cdh_version => '4.1.3',
        # cm_version  => '4.1.3',

        # what the github repo has 'tested'
        cdh_version => $cdh_version,
        cm_version  => $cm_version,

    } ->
    class { 'cloudera::java': } ->
    class { 'cloudera::cm': } ->
    class { 'cloudera::cm::server': } ->
    class { 'cloudera::cdh::hue': } ->
    package { 'hue-server':
        ensure => 'present',
    } ->
    class { 'mysql::server': 
        config_hash => { 'root_password' => $hive_metastore_password }
    } ->
    class { 'snpdb::master::hive': }
    # class { 'cloudera::cdh::hive::mysql': 
    #     password      => $hive_metastore_password, 
    #     database_name => $hive_metastore_db,
    #     username      => $hive_metastore_user,
    #     # require  => Class['mysql::config'],
    # } ->
    # class { 'snpdb::common::perms': }
}

class { 'snpdb::master': }
