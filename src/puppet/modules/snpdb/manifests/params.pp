class snpdb::params {
    $hive_metastore_db = 'metastore'
    $hive_metastore_user = 'hive'
    $hive_metastore_password = '1000anag3r'

    $hdfs_user = 'hdfs'
    $hdfs_group = $hdfs_user
    $jbod_root = '/data'

    $cdh_version = '4.1.3'
    $cm_version = '4.1.2'
    # $cm_version = $cdh_version

    if $environment == 'development' {
        $master_hostname = 'master'
        $master_ip = '192.168.56.102'

        $worker_hostnames = [
            'worker0',
        ]

        $worker_ips = [ 
            $master_ip,
        ]
    }

}
