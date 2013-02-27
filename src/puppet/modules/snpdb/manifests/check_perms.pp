# http://projects.puppetlabs.com/projects/1/wiki/File_Permission_Check_Patterns
define snpdb::check_perms($mode, $user, $path = $title, $group = $user, $format = '%U %G %a') {
    exec { "/bin/chown -R ${user}:${group} $path && /bin/chmod -R $mode $path":
        unless => "/bin/sh -c '[ \"$(/usr/bin/stat -c \"$format\" $path)\" == \"$user $group $mode\" ]'",
    }
}
