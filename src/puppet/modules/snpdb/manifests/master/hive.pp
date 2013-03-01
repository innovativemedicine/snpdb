# This is a workaround instead of using cloudera::cdh::hive::mysql for installing the Hive Metastore for impala; I believe 
# there's a bug in puppetlabs-mysql that causes it not to work (I filed a bug report in the meantime):
# https://projects.puppetlabs.com/issues/19491
class snpdb::master::hive (
    $hive_metastore_password = $snpdb::params::hive_metastore_password, 
    $hive_metastore_db = $snpdb::params::hive_metastore_db,
    $hive_metastore_user = $snpdb::params::hive_metastore_user,
    $hive_metastore_host = $snpdb::params::hive_metastore_host,
    $hive_metastore_thrift_port = $snpdb::params::hive_metastore_thrift_port,
    $impala_statestore_host = $snpdb::params::impala_statestore_host,
    $zookeeper_hosts = $snpdb::params::zookeeper_hosts,
    $master_hostname = $snpdb::params::master_hostname,
    $master_ip = $snpdb::params::master_ip,
    $hive_version = '0.9.0'
) inherits snpdb::params {
    require cloudera::cdh::hive


    # hive init scripts have a bug where it they return 0 exit status when service is stopped
    define hive_service($service = $title, $package = $title) { 
        package { $service:
            ensure => present,
        } ->
        service { $service:
            ensure     => running,
            enable     => true,
            hasstatus  => true,
            hasrestart => true,
            status     => "/sbin/service $service status | grep OK --quiet",
            require    => Package[$package],
        }       
    }
    hive_service { 'hive-metastore': } ->
    hive_service { 'hive-server2': }


    # require cloudera::cdh::hive::metastore
    # I think there's a bug because cloudera::cdh::hive::metastore redeclares a mysql-connector file resource...

    # package { 'hive-metastore':
    #     ensure => present,
    # } ->
    # service { 'hive-metastore':
    #     ensure     => running,
    #     enable     => true,
    #     hasstatus  => true,
    #     hasrestart => true,
    #     # init script has a bug where it returns 0 exit status when service is stopped
    #     status     => "/sbin/service hive-metastore status | grep OK --quiet",
    #     require    => Package['hive-metastore'],
    # } ->

    # class { 'cloudera::cdh::hive::server2': }

    # require cloudera::cdh::hive::server2
    # Class['snpdb::master::hive'] -> Class['cloudera::cdh::hive'] -> Class['cloudera::cdh::hive::metastore'] -> Class['cloudera::cdh::hive::server2']

    # require Class["cloudera::cdh::hive"]
    include mysql::java
    $sql = "/usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-${hive_version}.mysql.sql"

    file { '/usr/lib/hive/lib/mysql-connector-java.jar':
        ensure => link,
        target => '/usr/share/java/mysql-connector-java.jar',
    }

    class { 'mysql::server': 
        config_hash => { 
            'root_password' => $hive_metastore_password,
            'bind_address' => '0.0.0.0'
        }
    }

    mysql::db { $hive_metastore_db:
        user     => $hive_metastore_user,
        password => $hive_metastore_password,
        host     => $impala_statestore_host,
        # grant    => ['all'],
        grant  => [ 'select_priv', 'insert_priv', 'update_priv', 'delete_priv', ],
        # sql    => "/usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-${hive_version}.mysql.sql",
        require  => Class['mysql::config'],
    } 

    # augeas { '/etc/my.cnf':
    #     notify  => Service["mysqld"],
    #     changes => "set /files/etc/my.cnf/target[*]/bind-address 0.0.0.0",
    #     # require => Class['mysql::server'],
    # }

    define hive_grant($host = $title) {
        database_user { "$hive_metastore_user@$host":
            password_hash => mysql_password($hive_metastore_password)
        } ->
        database_grant { "$hive_metastore_user@$host/$hive_metastore_db":
            privileges => [ 'select_priv', 'insert_priv', 'update_priv', 'delete_priv', ],
            # Or specify individual privileges with columns from the mysql.db table:
            # privileges => ['Select_priv', 'Insert_priv', 'Update_priv', 'Delete_priv']
            require  => Mysql::Db[$hive_metastore_db],
        }
    }
    hive_grant { '%': }
    # hive_grant { $master_hostname: }
    # hive_grant { $worker_hostnames: }

    # hive_grant { "$master_ip": }
    # if $hive_metastore_host != 'localhost' {
    #     hive_grant { "$hive_metastore_host": }
    # }
    # hive_grant { 'localhost': }

    # database_grant { "$hive_metastore_user@$impala_statestore_host/$hive_metastore_db":
    #     privileges => [ 'select_priv', 'insert_priv', 'update_priv', 'delete_priv', ],
    #     # Or specify individual privileges with columns from the mysql.db table:
    #     # privileges => ['Select_priv', 'Insert_priv', 'Update_priv', 'Delete_priv']
    #     require  => Mysql::Db[$hive_metastore_db],
    # }

    exec { "${hive_metastore_db}-import":
        command     => "/usr/bin/mysql --defaults-file=/root/.my.cnf ${hive_metastore_db} < ${sql}",
        logoutput   => true,
        refreshonly => true,
        # require     => Database_grant["${hive_metastore_user}@${hive_metastore_host}/${hive_metastore_db}"],
        subscribe   => Mysql::Db[$hive_metastore_db],
        # refreshonly => $refresh,
        # require     => Database_grant["${hive_metastore_user}@${hive_metastore_host}/${hive_metastore_db}"],
        # subscribe   => Database[$hive_metastore_db],
    }

    $hive_changes = set_hive_properties(
        # as per "Step 4: Configure the Metastore Service to Communicate with the MySQL Database" of https://ccp.cloudera.com/display/CDH4DOC/Hive+Installation#HiveInstallation-ConfiguringaremoteMySQLdatabasefortheHiveMetastore
        "javax.jdo.option.ConnectionURL", "jdbc:mysql://${hive_metastore_host}/${hive_metastore_db}",
        "javax.jdo.option.ConnectionDriverName", "com.mysql.jdbc.Driver",
        "javax.jdo.option.ConnectionUserName", "${hive_metastore_user}",
        "javax.jdo.option.ConnectionPassword", "${hive_metastore_password}",
        "datanucleus.autoCreateSchema", "false",
        "datanucleus.fixedDatastore", "true",
        "hive.metastore.uris", "thrift://${hive_metastore_host}:${hive_metastore_thrift_port}",
        # https://ccp.cloudera.com/display/CDH4DOC/Hive+Installation#HiveInstallation-ConfiguringHiveServer2
        "hive.support.concurrency", "true",
        "hive.zookeeper.quorum", join($zookeeper_hosts, ",")
    ) 

    # define print() {
    #    notice("The value is: '${name}'")
    # }
    # print { $hive_changes: }

    augeas { '/etc/hive/conf/hive-site.xml':
        lens    => 'Xml.lns',
        incl    => '/etc/hive/conf/hive-site.xml',
        changes => $hive_changes,
        # changes => [
        #     set_hive_property("javax.jdo.option.ConnectionURL", "jdbc:mysql://${hive_metastore_host}/${hive_metastore_db}"),
        #     set_hive_property("javax.jdo.option.ConnectionDriverName", "com.mysql.jdbc.Driver"),
        #     set_hive_property("javax.jdo.option.ConnectionUserName", "${hive_metastore_user}"),
        #     set_hive_property("javax.jdo.option.ConnectionPassword", "${hive_metastore_password}"),
        #     set_hive_property("datanucleus.autoCreateSchema", "false"),
        #     set_hive_property("datanucleus.fixedDatastore", "true"),
        #     set_hive_property("hive.metastore.uris", "thrift://${hive_metastore_host}:9083"),
        # ],
        # require => Class['cloudera::cdh::hive'],
    }

}
