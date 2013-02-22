define snpdb::worker::host(
    $ip,
    $hostname = $title,
    $host_aliases = []
) {
    host { $hostname:
        ip           => $ip,
        host_aliases => $host_aliases,
    }
}
