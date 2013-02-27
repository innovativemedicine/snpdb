# This is a workaround instead of using cloudera::cdh::hive::mysql for installing the Hive Metastore for impala; I believe 
# there's a bug in puppetlabs-mysql that causes it not to work (I filed a bug report in the meantime):
# https://projects.puppetlabs.com/issues/19491
class snpdb::master::hive (
    $hive_metastore_password = $snpdb::params::hive_metastore_password, 
    $hive_metastore_db = $snpdb::params::hive_metastore_db,
    $hive_metastore_user = $snpdb::params::hive_metastore_user,
    $hive_metastore_host = $snpdb::params::hive_metastore_host,
    $impala_statestore_host = $snpdb::params::impala_statestore_host,
    $hive_version = '0.9.0'
) inherits snpdb::params {
    include mysql::java
    $sql = "/usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-${hive_version}.mysql.sql"

    file { '/usr/lib/hive/lib/mysql-connector-java.jar':
        ensure => link,
        target => '/usr/share/java/mysql-connector-java.jar',
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

}
