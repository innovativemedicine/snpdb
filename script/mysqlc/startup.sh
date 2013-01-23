#!/bin/bash -x
set -e
ndb_mgmd -f conf/config.ini --initial --configdir=`readlink -f conf/`
ndbd -c localhost:1186
ndbd -c localhost:1186
mysqld --defaults-file=conf/my.cnf
