#!/usr/bin/env python
from os import environ as e
import textwrap

def main():
    width = 90
    # import pdb; pdb.set_trace()
    def mk_clusterdb_help(connectstring_var, engine=None):
            
        return 'create a {CLUSTERDB_NAME} database using {MAKE_SCRIPTS}/mk_clusterdb.sh with connect string '.format(**e) + \
            '"{connectstring_var}"{engine}'.format(
                    connectstring_var=e[connectstring_var], 
                    engine=' ' + engine if engine is not None else '')
    target_help = {
        e['CLUSTERDB_NAME']                   : mk_clusterdb_help('MYSQL_CLUSTERDB_OPTS_REMOTE'),
        e['CLUSTERDB_NAME'] + '_innodb'       : mk_clusterdb_help('MYSQL_CLUSTERDB_OPTS_REMOTE', "(InnoDB engine)"),
        e['CLUSTERDB_NAME'] + '_local'        : mk_clusterdb_help('MYSQL_CLUSTERDB_OPTS_LOCAL'),
        e['CLUSTERDB_NAME'] + '_innodb_local' : mk_clusterdb_help('MYSQL_CLUSTERDB_OPTS_LOCAL', "(InnoDB engine)"),
        'loadtest' : ("use mysqlslap to execute queries in {QUERY_INPUT_DIR}, and merge that result with EXPLAIN PARTITIONS," 
            " recording it in {SUMMARY_FILE}").format(**e),
    }
    help_wrapper = textwrap.TextWrapper(width=width, initial_indent="    ", subsequent_indent="    ")
    print 'Useful targets:\n'
    for target, help in target_help.iteritems():
        print target + ':'
        print help_wrapper.fill(help), '\n'

if __name__ == '__main__':
    main()
