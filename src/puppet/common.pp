# stuff to be applied on master and workers
class disable_selinux {
    augeas { "disable_selinux_file":
        context => "/files/etc/sysconfig/selinux",
        changes => [ "set SELINUX disabled" ],
    }
    exec { "disable_selinux_runtime":
        command => "/usr/sbin/setenforce 0"
        onlyif  => "/usr/sbin/selinuxenabled"
    }
}
