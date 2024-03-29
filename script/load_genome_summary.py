#!/usr/bin/env python
# TODO: bulk insert other stuff even more to see if executemany sucks less
import argparsers
import vcf
import sql

import sys
import inspect
# import MySQLdb
import oursql
import csv
import fileinput
import re
# import warnings
from progressbar import ProgressBar, Counter, Percentage, Bar, RotatingMarker, ETA
from multiprocessing import Process, Queue, Lock, Value

def main():
    parser = argparsers.sql_parser(description="Load a genome summary file from the pipeline into the MySQL cluster database")
    parser.add_argument('genome_summary_file', nargs="*")
    parser.add_argument("--delim", default=",", help="delimiter")
    parser.add_argument("--quote", default='"', help="quote character")
    parser.add_argument("--dry-run", action="store_true", help="skip insertion")
    parser.add_argument("--quiet", action="store_true", help="don't print insertions when --dry-run is set")
    parser.add_argument("--no-progress", action="store_true", help="don't show a progress bar (skips line counting input files at the beginning, which could take a while)")
    parser.add_argument("--records", type=int, help="skip line counting input files, and use --records as the total number of lines in the input files")
    parser.add_argument("--threads", type=int, default=1, help="split input into --threads chunks")
    parser.add_argument("--no-skip-header", action="store_true", help="don't skip the first line (header line)")
    parser.add_argument("--buffer", type=int, required=False, help="size of the buffer for dividing input amongst threads (lower this if you're thrashing; if left to the default, it is multiplied by --threads)")
    parser.add_argument("--profile", help="run yappi and output profiling results to --profile")
    parser.add_argument("--autocommit", action="store_true", help="SET autocommit = 1 (good for ndb, bad for innodb)")
    args = parser.parse_args()
    thread_buffer_default = 1000
    args.buffer = thread_buffer_default * min(1, args.threads)

    if args.profile is not None:
        import yappi
        yappi.start()

    records = args.records
    if records is None and not args.no_progress and len(args.genome_summary_file) != 0 and '-' not in args.genome_summary_file:
        records = sum(file_len(f) for f in args.genome_summary_file)
    input = fileinput.FileInput(args.genome_summary_file)

    # warnings.filterwarnings('error', category=MySQLdb.Warning)

    widgets = ['loading data: ', Counter(), '/', str(records), '(', Percentage(), ')', ' ', Bar(marker=RotatingMarker()), ' ', ETA()]
    pbar = ProgressBar(widgets=widgets, maxval=records).start() if records is not None else None

    skip_header = not args.no_skip_header
    if skip_header:
        try:
            input.next()
        except StopIteration:
            # empty input
            pass


    if args.threads > 1:
        load_genome_summary_parallel(input, records, pbar, args)
    else:
        processed = [0]
        def sequential_input():
            for line in input:
                if records != None:
                    processed[0] += 1
                    if pbar is not None:
                        pbar.update(processed[0])
                yield line
        load_genome_summary(
                connect(args), 
                sequential_input(),
                **lgs_kwargs(args))

    pbar.finish()

    if args.profile is not None:
        yappi.stop()
        with open(args.profile, 'w') as f:
            yappi.print_stats(out=f)

def connect(args):
    # return MySQLdb.connect(
    #         host=args.host,
    #         port=args.port,
    #         user=args.user,
    #         passwd=args.password,
    #         db=args.db)
    return oursql.connect(
            args.host,
            args.user,
            args.password,
            port=args.port,
            db=args.db,
            raise_on_warnings=False)

# args that are kwargs to load_genome_summary
def lgs_kwargs(args):
    spec = inspect.getargspec(load_genome_summary)
    return dict((k, getattr(args, k)) for k in spec.args[len(spec.args)-len(spec.defaults):])

def load_genome_summary_parallel(input, records, pbar, args):
    queues = [Queue(args.buffer) if args.buffer is not None else Queue() for i in xrange(args.threads)]
    l = Lock()
    processed = Value('i', 0, lock=False)
    def queue_input(queue):
        while True:
            line = queue.get()
            if line is None:
                break
            if records != None:
                l.acquire()
                processed.value += 1
                if pbar is not None:
                    pbar.update(processed.value)
                l.release()
            yield line

    processes = [
            Process(target=load_genome_summary, 
                    args=(connect(args), 
                          queue_input(q)), 
                    kwargs=lgs_kwargs(args))
                    for q in queues]

    for p in processes:
        p.start()

    i = 0
    # j = 0
    for line in input:
        queues[i].put(line)
        i = (i + 1) % len(queues)
        # j += 1
        # if j % 100 == 0:
        #     print j 
    for q in queues:
        q.put(None)

    for p in processes:
        p.join()

def load_genome_summary(db, input, delim=",", quote='"', dry_run=False, records=None, quiet=False, autocommit=False):
    # this script will run properly on InnoDB engine without autocommit; sadly, such is not the case for NDB, where we get 
    # the error:
    # Got temporary error 233 'Out of operation records in transaction coordinator (increase MaxNoOfConcurrentOperations)' from NDBCLUSTER 
    # db.autocommit(True)

    def insert_wrapper(table, dic_or_dics, do_insert):
        if not dry_run:
            # try:
            return do_insert(dic_or_dics)
            # except Exception as e:
            #     msg = e.message if e.message else e.__str__()
                # raise type(e)(msg + " at line {lineno}".format(lineno=1))
        if not quiet:
            print "insert into {table} {dic_or_dics}".format(table=table.name, dic_or_dics=dic_or_dics)
    def insert_many(table, values):
        insert_wrapper(table, values, lambda vs: table.insert_many(values=vs))
    def insert(table, dic):
        insert_wrapper(table, dic, lambda d: table.insert(d))

    def arity_zip(args, error=None, table=None, key=None):
        if error is None:
            error = "Number of {table} columns don't all match the number of {key}; " + \
                    "skipping insertion into {table} at line {lineno}"
        return check_arity_zip(args, error.format(lineno=1, table=table.name, key=key))

    c = db.cursor()
    if autocommit:
        c.execute("""SET autocommit = 1;""")
    else:
        c.execute("""SET autocommit = 0;""")

    csv_input = csv.reader(input, delimiter=delim, quotechar=quote)

    vc_group_table = sql.table.oursql('vc_group', cursor=c)
    vc_table = sql.table.oursql('vc', cursor=c)                             
    patient_table = sql.table.oursql('patient', cursor=c)

    # table we can batch insert (i.e. tables whose lastrowid's we do not need)
    vc_group_allele_table = sql.table.oursql('vc_group_allele', cursor=c, fields=['vc_group_id', 'allele', 'af', 'mle_af', 'ac', 'mle_ac'])                
    vc_genotype_table = sql.table.oursql('vc_genotype', cursor=c, fields=['vc_id', 'allele1', 'allele2', 'phred_likelihood'])                    
    vc_allele_table = sql.table.oursql('vc_allele', cursor=c, fields=['vc_id', 'allele', 'allelic_depth'])

    # for each vc_group
    for row in csv_input:

        row = [None if f == '' else f for f in row] 

        info = vcf.parse('info', row[35 - 1])
        vc_group_columns = {
            'chromosome'  : row[22 - 1],
            'start_posn'  : row[23 - 1],
            'end_posn'    : row[24 - 1],
            'ref'         : vcf.parse('ref', row[25 - 1]),
            'dbsnp_id'    : vcf.parse('dbsnp_id', row[30 - 1]),

            # 'genotype_format' : row[36 - 1],
            'quality'         : row[33 - 1],
            'filter'          : row[34 - 1],

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
            # 'info_source'       : row[36 - 1],
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

        alts = vcf.parse('alts', row[32 - 1])

        # for each vc_group_allele in (vc x alt alleles in vc_group)
        vc_group_allele_fields = [
            alts,
            # vc_group_allele_info
            get_list(info, 'AF'),
            get_list(info, 'MLEAF'),
            get_list(info, 'AC'),
            get_list(info, 'MLEAC'),
        ]
        insert_many(vc_group_allele_table, values=[[ vc_group_table.lastrowid, allele, af, mle_af, ac, mle_ac ] 
            for allele, af, mle_af, ac, mle_ac in arity_zip(vc_group_allele_fields, table=vc_group_table, key="alt alleles in vc_group")])

        vc_columns = {
            'vc_group_id' : vc_group_table.lastrowid,
            'zygosity'    : row[27 - 1],
        }

        ref_and_alts = as_list(vc_group_columns['ref']) + alts

        # for each vc in vc_group
        for genotype in [vcf.parse('genotype', row[gf]) for gf in xrange(37 - 1, 48)]:
            # vc_columns['genotype_source'] = row[gf]

            patient_columns = {
            }
            insert(patient_table, patient_columns)

            vc_columns['patient_id'] = patient_table.lastrowid
            if not (type(genotype) == tuple and genotype[0] == (None, None)):
                ((allele1_idx, allele2_idx), vc_columns['phased']) = genotype['GT'] 
                vc_columns['allele1'] = ref_and_alts[allele1_idx]
                vc_columns['allele2'] = ref_and_alts[allele2_idx]
                vc_columns['read_depth'] = genotype.get('DP')
                vc_columns['genotype_quality'] = genotype.get('GQ')
                insert(vc_table, vc_columns)
                
                # for each vc_genotype in (alleles in vc_group x alleles in vc_group x vc)
                vc_genotype_fields = [
                    vcf.ordered_alleles(vc_group_columns['ref'], alts), 
                    as_list(genotype.get('PL')),
                ]
                insert_many(vc_genotype_table, values=[[vc_table.lastrowid, vc_genotype_allele1, vc_genotype_allele2, phred_likelihood]
                    for (vc_genotype_allele1, vc_genotype_allele2), phred_likelihood in arity_zip(vc_genotype_fields, table=vc_genotype_table, key="biallelic genotypes in vc_group")])

                # for each vc_allele in (vc x alleles in ref, alts)
                vc_allele_fields = [
                    ref_and_alts,
                    get_list(genotype, 'AD'),
                ]
                insert_many(vc_allele_table, values=[[vc_table.lastrowid, allele, allelic_depth]
                    for allele, allelic_depth in arity_zip(vc_allele_fields, table=vc_allele_table, key="ref and alt alleles in vc_group")])

    vc_group_allele_table.flush_buffer()
    vc_genotype_table.flush_buffer()
    vc_allele_table.flush_buffer()
    db.commit()
    c.close()

def as_list(x):
    return [x] if type(x) != list else x

def get_list(dic, attr):
    return as_list(dic.get(attr, []))

def check_arity_zip(args, error=None):
    if not all(len(f) == len(args[0]) for f in args):
        if error is not None:
            print >> sys.stderr, error
        return []
    return zip(*args)

def file_len(fname):
    i = 0
    with open(fname) as f:
        for i, l in enumerate(f):
            pass
    return i + 1

if __name__ == '__main__':
    main()
