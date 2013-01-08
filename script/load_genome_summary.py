#!/usr/bin/env python
import argparsers
import vcf

import MySQLdb
import csv
import fileinput
import re
import warnings

def main():
    parser = argparsers.sql_parser(description="Load a genome summary file from the pipeline into the MySQL cluster database")
    parser.add_argument('genome_summary_file', nargs="*")
    parser.add_argument("--delim", default=",", help="delimiter")
    parser.add_argument("--quote", default='"', help="quote character")
    parser.add_argument("--dry-run", action="store_true", help="skip insertion")
    parser.add_argument("--no-skip-header", action="store_true", help="don't skip the first line (header line)")
    args = parser.parse_args()
    input = fileinput.input(args.genome_summary_file)

    # db = None

    warnings.filterwarnings('error', category=MySQLdb.Warning)

    db = MySQLdb.connect(
            host=args.host,
            port=args.port,
            user=args.user,
            passwd=args.password,
            db=args.db)

    # this script will run properly on InnoDB engine without autocommit; sadly, such is not the case for NDB, where we get 
    # the error:
    # Got temporary error 233 'Out of operation records in transaction coordinator (increase MaxNoOfConcurrentOperations)' from NDBCLUSTER 
    db.autocommit(True)

    load_genome_summary(db, input, delim=args.delim, quote=args.quote, skip_header=not args.no_skip_header)

def load_genome_summary(db, input, delim=",", quote='"', skip_header=True):
    cursor = db.cursor()
    type_to_attr_table = { 
        str: 'vc_attr_str',
        int: 'vc_attr_int',
        float: 'vc_attr_float',
        bool: 'vc_attr_bool',
    }

    input = csv.reader(input, delimiter=delim, quotechar=quote)
    if skip_header:
        try:
            input.next()
        except StopIteration:
            # empty input
            pass
    for row in input:
        row = [None if f == '' else f for f in row] 
        # TODO: insert vc record
        cursor.execute("""
        insert into vc
        ( chromosome
        , start_posn
        , end_posn
        , ref
        , alt
        , alts
        , quality
        , filter
        , dbsnp_id
        ) values ({fields})""".format(fields=', '.join(['%s']*9)), [
            row[22 - 1],
            row[23 - 1],
            row[24 - 1],
            row[25 - 1],
            row[26 - 1],
            row[44 - 1],
            row[45 - 1],
            row[46 - 1],
            row[42 - 1],
            ])

        # TODO: get autoincrement using last_insert_id: http://stackoverflow.com/questions/2548493/in-python-after-i-insert-into-mysqldb-how-do-i-get-the-id
        vc_id = cursor.lastrowid

        # TODO: based on types returned by parse_info, insert each attr into the right table
        for attr_type, attrs in vcf.parse_info(row[47 - 1]).iteritems():
            attr_table = type_to_attr_table[attr_type]  
            for attr, value in attrs:
                cursor.execute("""
                insert into {attr_table}
                ( attr
                , value
                , vc_id 
                ) values ({fields})""".format(attr_table=attr_table, fields=', '.join(['%s']*3)), [
                    attr,
                    value,
                    vc_id,
                    ])

        # TODO: insert annotation record
        cursor.execute("""
                insert into annotation
                ( vc_id

                , func
                , gene
                , exonicfunc
                , aachange
                , conserved
                , 1000g2011may_all
                , dbsnp135
                , ljb_phylop_pred
                , ljb_sift_pred
                , ljb_polyphen2_pred
                , ljb_lrt_pred
                , ljb_mutationtaster_pred
                , otherinfo

                , segdup
                , esp5400_all
                , avsift
                , ljb_phylop
                , ljb_sift
                , ljb_polyphen2
                , ljb_lrt
                , ljb_mutationtaster
                , ljb_gerppp
             
                , zygosity
                , genotype_format
             
                , genotype1
                , genotype2
                , genotype3
                , genotype4
                , genotype5
                , genotype6
                , genotype7
                , genotype8
                , genotype9
                , genotype10
                , genotype11
                , genotype12

                ) values ({fields})""".format(fields=', '.join(['%s']*37)), [
                    vc_id,

                    row[1 - 1],
                    row[2 - 1],
                    row[3 - 1],
                    row[4 - 1],
                    row[5 - 1],
                    row[8 - 1],
                    row[9 - 1],
                    row[12 - 1],
                    row[14 - 1],
                    row[16 - 1],
                    row[18 - 1],
                    row[20 - 1],
                    row[27 - 1],

                    row[6 - 1],
                    row[7 - 1], 
                    row[10 - 1],
                    row[11 - 1],
                    row[13 - 1],
                    row[15 - 1],
                    row[17 - 1],
                    row[19 - 1],
                    row[21 - 1],

                    row[39 - 1],
                    row[48 - 1],

                    row[49 - 1],
                    row[50 - 1],
                    row[51 - 1],
                    row[52 - 1],
                    row[53 - 1],
                    row[54 - 1],
                    row[55 - 1],
                    row[56 - 1],
                    row[57 - 1],
                    row[58 - 1],
                    row[59 - 1],
                    row[60 - 1],

                    ])
    db.commit()
    cursor.close()

if __name__ == '__main__':
    main()
