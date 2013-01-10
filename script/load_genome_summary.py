#!/usr/bin/env python
import argparsers
import vcf
import sql

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
    input = fileinput.FileInput(args.genome_summary_file)
    # input = fileinput.input(args.genome_summary_file)

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
    c = db.cursor()

    input = csv.reader(input, delimiter=delim, quotechar=quote)
    if skip_header:
        try:
            input.next()
        except StopIteration:
            # empty input
            pass
    vc_table = sql.Table('vc', cursor=c)
    annovar_table = sql.Table('annovar', cursor=c)
    for row in input:
        row = [None if f == '' else f for f in row] 
        # TODO: insert vc record
        vc_table.insert(dic={
            'dbsnp_id'   : row[42 - 1],
            'chromosome' : row[22 - 1],
            'start_posn' : row[23 - 1],
            'end_posn'   : row[24 - 1],
            'ref'        : row[25 - 1],
            'alt'        : row[26 - 1],
            'alts'       : row[44 - 1],
            'quality'    : row[45 - 1],
            'filter'     : row[46 - 1],
        })

        vc_id = c.lastrowid

        annovar_table.insert(dic={
            'vc_id'                   : vc_id,

            'otherinfo'               : row[27 - 1],
            'func'                    : row[1 - 1],
            'gene'                    : row[2 - 1],
            'exonicfunc'              : row[3 - 1],
            'aachange'                : row[4 - 1],
            'conserved'               : row[5 - 1],
            '1000g2011may_all'        : row[8 - 1],
            'dbsnp135'                : row[9 - 1],
            'ljb_phylop_pred'         : row[12 - 1],
            'ljb_sift_pred'           : row[14 - 1],
            'ljb_polyphen2_pred'      : row[16 - 1],
            'ljb_lrt_pred'            : row[18 - 1],
            'ljb_mutationtaster_pred' : row[20 - 1],

            'ljb_gerppp'              : row[21 - 1],
            'segdup'                  : row[6 - 1],
            'esp5400_all'             : row[7 - 1],
            'avsift'                  : row[10 - 1],
            'ljb_phylop'              : row[11 - 1],
            'ljb_sift'                : row[13 - 1],
            'ljb_polyphen2'           : row[15 - 1],
            'ljb_lrt'                 : row[17 - 1],
            'ljb_mutationtaster'      : row[19 - 1],

            'zygosity'                : row[39 - 1],
            'genotype_format'         : row[48 - 1],

            'genotype1'               : row[49 - 1],
            'genotype2'               : row[50 - 1],
            'genotype3'               : row[51 - 1],
            'genotype4'               : row[52 - 1],
            'genotype5'               : row[53 - 1],
            'genotype6'               : row[54 - 1],
            'genotype7'               : row[55 - 1],
            'genotype8'               : row[56 - 1],
            'genotype9'               : row[57 - 1],
            'genotype10'              : row[58 - 1],
            'genotype11'              : row[59 - 1],
            'genotype12'              : row[60 - 1],
        })
    db.commit()
    c.close()

if __name__ == '__main__':
    main()
