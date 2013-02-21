# Most nodes in the cluster will use this declaration:
class snpdb::worker(
    $master_hostname = $snpdb::params::master_hostname
) inherits snpdb::params {
    class { 'cloudera':
        cm_server_host => $master_hostname,
    }
}

class { 'snpdb::worker': }
