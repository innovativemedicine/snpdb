#!/usr/bin/env python
import argparsers

import MySQLdb

def main():
    parser = argparsers.sql_parser(description="Duplicate data in a database, for load testing purposes")
    parser.add_argument("--chunk", type=int)
    args = parser.parse_args()

    warnings.filterwarnings('error', category=MySQLdb.Warning)

    # widgets = ['loading data: ', Counter(), '/', str(records), '(', Percentage(), ')', ' ', Bar(marker=RotatingMarker()), ' ', ETA()]
    # pbar = ProgressBar(widgets=widgets, maxval=records).start() if records is not None else None

    # pbar.finish()

    # if pbar is not None:
    #     pbar.update(processed.value)

def dupdata(chunk=None):
    pass
    # need to know:
    # - the autoincrement field of each table in the given database
    # - the column names of every table in the given database
    # - for each autoincrement field, which tables reference that key
    # - for each autoincrement field, what the max is
    # - for each autoincrement field, how many rows are <= max
    #
    # need to do:
    # def base_query(table, select_modifiers=''): 
    #     return 
    #         select <table.autoincrement> + <table.max_autoincrement>, <table.* except table.autoincrement> from <table> where <table.autoincrement> <table.max_autoincrement>
    #         <select_modifiers>
    #         insert into <table> (<table.autoincrement>, <table.* except table.autoincrement>) 
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
    #     for each table in db:
    #         start = 1
    #         while start <= table.lt_max_count:
    #             end = min(start + chunk - 1, table.lt_max_count)
    #             execute chunk_query(table, start, end)
    #             start = end + 1

if __name__ == '__main__':
    main()
