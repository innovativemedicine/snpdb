#!/bin/bash
set -e

main() {
    local datadir="$1"
    local outdir="$2"

    # http://dev.mysql.com/doc/refman/5.0/en/innodb-backup.html
    # If you are able to shut down your MySQL server, you can make a binary backup that consists of all files used by InnoDB to manage its tables. Use the following procedure:
    # 1. Shut down the MySQL server and make sure that it stops without errors.
    # 2. Copy all InnoDB data files (ibdata files and .ibd files) into a safe place.
    # 3. Copy all the .frm files for InnoDB tables to a safe place.
    # 4. Copy all InnoDB log files (ib_logfile files) to a safe place.
    # 5. Copy your my.cnf configuration file or files to a safe place. 

    do_du() {
        xargs du -b -c
    }
    # so, files required to perform a binary backup (i.e. minimal files needed for the db to exist):
    local backup=( ibdata* *.ibd *.frm ib_logfile* )

    # binary log files (can be removed via PURGE):
    # http://dev.mysql.com/doc/refman/5.0/en/purge-binary-logs.html
    local binlog=( mysql-bin* )


    # alias find_files="find . -type f"
    find_files() {
        find . -type f "$@"
    }

    find_patterns() {
        let i=0
        for pattern in "$@"; do
            let i+=1
            if [ "$i" -gt 1 ]; then
                echo -n "-o "
            fi
            echo -n "-name '$pattern' "
        done
    }
    # echo $(find_patterns ${backup[@]})

    local str="`find_patterns ${backup[@]}`"
    set -x
    eval find "$datadir" -type f \\\( $(find_patterns ${backup[@]}) \\\) | do_du > $outdir/backup.du.csv
    eval find "$datadir" -type f \\\( $(find_patterns ${binlog[@]}) \\\) | do_du > $outdir/binlog.du.csv
    eval find "$datadir" -type f \\\! \\\( $(find_patterns ${backup[@]} ${binlog[@]}) \\\) | do_du > $outdir/other.du.csv
}

main "$@"
