# Most nodes in the cluster will use this declaration:

# $master_ip            = $snpdb::params::master_ip,
# $worker_base_ip_addr  = $snpdb::params::worker_base_ip_addr,
# $worker_starting_ip   = $snpdb::params::worker_starting_ip,
# $num_workers          = $snpdb::params::num_workers,
# $worker_id            = $snpdb::params::worker_id,
# $worker_base_hostname = $snpdb::params::worker_base_hostname,
# $worker_hostname      = $snpdb::params::worker_hostname

class snpdb::worker(
    $master_hostname      = $snpdb::params::master_hostname
) inherits snpdb::params {
    # host { $master_hostname:
    #     ip           => $master_ip,
    #     host_aliases => ["puppet"],
    # } ->
    # file { "/etc/hosts":
    #     owner => root,
    #     group => root,
    #     mode => 644,
    #     content => template("snpdb/hosts.erb"),
    # } ->
    class { 'snpdb::hosts': } ->
    class { 'cloudera':
        cm_server_host => $master_hostname,
    }
}

class { 'snpdb::worker': }
