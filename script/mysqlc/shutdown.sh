#!/bin/bash -x
set -e
mysqladmin --user root --port 5000 --host 127.0.0.1 shutdown
ndb_mgm -e shutdown
