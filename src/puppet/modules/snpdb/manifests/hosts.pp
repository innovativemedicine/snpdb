class snpdb::hosts {
    file { "/etc/hosts":
        owner => root,
        group => root,
        mode => 644,
        content => template("snpdb/hosts.erb"),
    }
}
