class snpdb::params {

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
