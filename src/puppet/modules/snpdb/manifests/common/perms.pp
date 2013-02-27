class snpdb::common::perms (
    $jbod_root = $snpdb::params::jbod_root,
    $hdfs_user = $snpdb::params::hdfs_user,
    $hdfs_group = $snpdb::params::hdfs_group
) inherits snpdb::params {
    snpdb::check_perms { "$jbod_root":
        mode  => '755',
        user  => $hdfs_user,
        group => $hdfs_group,
    }
}
