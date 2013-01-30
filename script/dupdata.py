#!/usr/bin/env python
import argparsers
import re

import MySQLdb
import warnings
param = '%s'

def main():
    parser = argparsers.sql_parser(description="Duplicate data in a database, for load testing purposes")
    parser.add_argument("--chunk", type=int)
    parser.add_argument("--tables", nargs='*', description="Table load order (to satisfy foreign key constraints)")
    parser.add_argument("--schema", nargs='*', description="Define table load order by order of create table statements")
    args = parser.parse_args()

    warnings.filterwarnings('error', category=MySQLdb.Warning)

    db = MySQLdb.connect(
            host=args.host,
            port=args.port,
            user=args.user,
            passwd=args.password,
            db=args.db)
    cursor = db.cursor()

    print autoincrement_fields(cursor)

    # widgets = ['loading data: ', Counter(), '/', str(records), '(', Percentage(), ')', ' ', Bar(marker=RotatingMarker()), ' ', ETA()]
    # pbar = ProgressBar(widgets=widgets, maxval=records).start() if records is not None else None

    # pbar.finish()

    # if pbar is not None:
    #     pbar.update(processed.value)


create_table_re = re.compile('create table `?(?P<table>[\w_]+)`?', re.IGNORECASE)
def tables_in_schema(schema_file):
    tables = []
    with open(schema_file, 'r') as f:
        for line in f:
            result = re.match(create_table_re, line)
            if result:
                tables.append(result.groupdict()['table'])
    return tables

# - the autoincrement field of each table in the given database
def autoincrement_fields(cursor, database=None): 
    query = """
        select TABLE_NAME, COLUMN_NAME from information_schema.`COLUMNS`
        where EXTRA = 'auto_increment'
        and table_schema = {database}
    """
    if database is not None:
        cursor.execute(query.format(database=param), (database,))
    else:
        cursor.execute(query.format(database='database()'))
    return dict(cursor.fetchall())

class Table(object):
    def __init__():
        self.autoincrement

def tables():
    table_to_autoincrement

def dupdata(chunk=None):
    pass
    # need to know:
    # - the autoincrement field of each table in the given database
    # - the column names of every table in the given database
    # - which tables a given table refers to (through an autoincrement field)
    # - for each autoincrement field, which tables reference that key
    # - for each autoincrement field, what the max is
    # - for each autoincrement field, how many rows are <= max
    #
    # need to do:
    # def base_query(table, select_modifiers=''): 
    #     return 
    #         select <table.autoincrement> + <table.max_autoincrement>, 
    #                <auto_fk_field + other_t.max_autoincrement (other_t, auto_fk_field) in table.referes_to>, 
    #                <table.* except table.autoincrement> from <table> where <table.autoincrement> <table.max_autoincrement>
    #         <select_modifiers>
    #         insert into <table> (
    #             <table.autoincrement>, 
    #             <auto_fk_field (other_t, auto_fk_field) in table.referes_to>, 
    #             <table.* except table.autoincrement, table.refers_to.*auto_fk_field>
    #         ) 
    # if chunk is None:
    #     for each table in db:
    #         execute base_query(table)
    # else:
    #     def chunk_query(table, start, end):
    #         return 
    #             base_query(table, 
    #                 select_modifiers=
    #                     order by <table.autoincrement>
    #                     limit <start>, <end>
    #             )
    #     for each table in tables:
    #         start = 1
    #         while start <= table.lt_max_count:
    #             end = min(start + chunk - 1, table.lt_max_count)
    #             execute chunk_query(table, start, end)
    #             start = end + 1

if __name__ == '__main__':
    main()
