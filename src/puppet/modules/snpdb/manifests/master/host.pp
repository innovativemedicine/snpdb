define snpdb::master::host(
    $ip,
    $hostname = $title,
    $host_aliases = ["puppet"]
) {
    host { $hostname:
        ip           => $ip,
        host_aliases => $host_aliases,
    }
}
