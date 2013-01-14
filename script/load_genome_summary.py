#!/usr/bin/env python
import argparsers
import vcf
import sql

import sys
import MySQLdb
import csv
import fileinput
import re
import warnings
from progressbar import ProgressBar, Counter, Percentage, Bar, RotatingMarker, ETA

def main():
    parser = argparsers.sql_parser(description="Load a genome summary file from the pipeline into the MySQL cluster database")
    parser.add_argument('genome_summary_file', nargs="*")
    parser.add_argument("--delim", default=",", help="delimiter")
    parser.add_argument("--quote", default='"', help="quote character")
    parser.add_argument("--dry-run", action="store_true", help="skip insertion")
    parser.add_argument("--no-skip-header", action="store_true", help="don't skip the first line (header line)")
    args = parser.parse_args()
    records = None
    if len(args.genome_summary_file) != 0 and '-' not in args.genome_summary_file:
        records = sum(file_len(f) for f in args.genome_summary_file)
    input = fileinput.FileInput(args.genome_summary_file)

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

    load_genome_summary(db, input, delim=args.delim, quote=args.quote, skip_header=not args.no_skip_header, dry_run=args.dry_run, records=records)

def load_genome_summary(db, input, delim=",", quote='"', skip_header=True, dry_run=False, records=None):
    widgets = ['loading data: ', Counter(), '/', str(records), '(', Percentage(), ')', ' ', Bar(marker=RotatingMarker()), ' ', ETA()]

    def insert(table, dic):
        if not dry_run:
            return table.insert(dic=dic)
        print "insert into {table} {dic}".format(table=table.name, dic=dic)

    c = db.cursor()

    csv_input = csv.reader(input, delimiter=delim, quotechar=quote)
    if skip_header:
        try:
            input.next()
        except StopIteration:
            # empty input
            pass

    vc_group_table          = sql.Table('vc_group', cursor=c)              
    vc_group_allele_table   = sql.Table('vc_group_allele', cursor=c)       
    vc_group_genotype_table = sql.Table('vc_group_genotype', cursor=c)     
    vc_table                = sql.Table('vc', cursor=c)                    

    pbar = ProgressBar(widgets=widgets, maxval=records).start() if records is not None else None
    for row in csv_input:
        if pbar is not None:
            pbar.update(input.lineno())

        row = [None if f == '' else f for f in row] 

        info = vcf.parse('info', row[47 - 1])
        vc_group_columns = {
            'genotype_format' : row[48 - 1],
            'quality'         : row[45 - 1],
            'filter'          : row[46 - 1],

            # annovar columns
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

            # vc_group_info columns
            # 'info_source'       : row[48 - 1],
            'ds'                : info.get('DS', False),
            'inbreeding_coeff'  : info.get('InbreedingCoeff'),
            'base_q_rank_sum'   : info.get('BaseQRankSum'),
            'mq_rank_sum'       : info.get('MQRankSum'),
            'read_pos_rank_sum' : info.get('ReadPosRankSum'),
            'dels'              : info.get('Dels'),
            'fs'                : info.get('FS'),
            'haplotype_score'   : info.get('HaplotypeScore'),
            'mq'                : info.get('MQ'),
            'qd'                : info.get('QD'),
            'sb'                : info.get('SB'),
            'vqslod'            : info.get('VQSLOD'),
            'an'                : info.get('AN'),
            'dp'                : info.get('DP'),
            'mq0'               : info.get('MQ0'),
            'culprit'           : info.get('culprit'),
        }
        insert(vc_group_table, vc_group_columns)

        vc_columns = {
            'vc_group_id' : vc_group_table.lastrowid,
            'chromosome'  : row[22 - 1],
            'start_posn'  : row[23 - 1],
            'end_posn'    : row[24 - 1],
            'ref'         : vcf.parse('ref', row[25 - 1]),
            'dbsnp_id'    : vcf.parse('dbsnp_id', row[42 - 1]),
            'zygosity'    : row[39 - 1],
        }

        alts = vcf.parse('alts', row[44 - 1])
        ref_and_alts = as_list(vc_columns['ref']) + alts
        first_gf = 49 - 1
        last_gf = 60 - 1
        genotype_fields = xrange(first_gf, last_gf + 1)
        genotypes = [vcf.parse('genotype', row[gf]) for gf in genotype_fields]

        for gf in genotype_fields:
            # vc_columns['genotype_source'] = row[gf]
            genotype = genotypes[last_gf-gf]

            vc_group_genotype_columns = {
                'vc_group_id'      : vc_group_table.lastrowid,
            }

            if genotype != ('.', '.'):
                ((allele1_idx, allele2_idx), vc_columns['phased']) = genotype.get('GT') 
                vc_columns['allele1'] = ref_and_alts[allele1_idx]
                vc_columns['allele2'] = ref_and_alts[allele2_idx]
                vc_columns['read_depth'] = genotype.get('DP')
                vc_columns['genotype_quality'] = genotype.get('GQ')
                vc_group_genotype_columns['allele1'] = vc_columns.get('allele1'),
                vc_group_genotype_columns['allele2'] = vc_columns.get('allele2'),
                vc_group_genotype_columns['phred_likelihood'] = genotype.get('PL'),
                alleles = filter(lambda x: x is not None, [vc_columns.get('allele1'), vc_columns.get('allele2')])
                allele_fields = [
                    alleles,
                    # vc_group_allele
                    get_list(genotype, 'AD'),
                    # vc_group_allele_info
                    get_list(info, 'AF'),
                    get_list(info, 'MLEAF'),
                    get_list(info, 'AC'),
                    get_list(info, 'MLEAC'),
                ]
                if not all(len(f) == len(alleles) for f in allele_fields):
                    print >> sys.stderr, "Number of vc_group_allele / vc_group_allele_info columns don't all match the number of alleles; skipping insertion into vc_group_allele / vc_group_allele_info".format(lineno=input.lineno())
                else:
                    for allele, allelic_depth, af, mle_af, ac, mle_ac in zip(*allele_fields):
                        vc_group_allele_columns = {
                            'vc_group_id'   : vc_group_table.lastrowid,
                            'allele'        : allele,
                            'allelic_depth' : allelic_depth,

                            # vc_group_allele_info columns
                            'allele'      : allele,
                            'af'          : af,
                            'mle_af'      : mle_af,
                            'ac'          : ac,
                            'mle_ac'      : mle_ac,
                        }
                        insert(vc_group_allele_table, vc_group_allele_columns)
            insert(vc_group_genotype_table, vc_group_genotype_columns)
            insert(vc_table, vc_columns)
    pbar.finish()
    db.commit()
    c.close()

def as_list(x):
    return [x] if type(x) != list else x

def get_list(dic, attr):
    return as_list(dic.get(attr, []))

def file_len(fname):
    with open(fname) as f:
        for i, l in enumerate(f):
            pass
    return i + 1

if __name__ == '__main__':
    main()
