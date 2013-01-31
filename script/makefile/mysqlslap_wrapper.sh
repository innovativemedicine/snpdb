#!/usr/bin/env bash
# mysqlslap doesn't return non-zero exit status on failing to execute a query (e.g. syntax errors).  Copy the output, but 
# exit with proper status if we see "ERROR".
status=0
mysqlslap $MYSQL_CLUSTERDB_OPTS "$@" 2>&1 | ( 
    while read line; do
        echo "$line"
        if [[ "$line" =~ ^mysqlslap:\ .*ERROR ]]; then 
            echo "$line" 1>&2
            status=1
        fi
    done
    # Note: the pipe create a subshell, so we need to exit this subshell with $status to pass it back to our parent
    exit $status
)
