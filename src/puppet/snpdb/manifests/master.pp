# The node that will be the CM server may use this declaration:
# This will skip installation of the CDH software as it is not required.

class snpdb::master {
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
        cdh_version => '4.1.2',
        cm_version  => '4.1.2',

    } ->
    class { 'cloudera::java': } ->
    class { 'cloudera::cm': } ->
    class { 'cloudera::cm::server': }
}

class { 'snpdb::master': }
