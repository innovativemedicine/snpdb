#!/usr/bin/env jython 
from java.lang import *
from java.lang import *
from java.sql import *
from org.apache.hive.jdbc import HiveDataSource, HiveDriver
from java.util import Properties

import os
import tempfile
import threading
from itertools import izip

import argparsers
import vcf
import hive

def main():
    parser = argparsers.sql_parser(description="Load a genome summary file from the pipeline into the snpdb Hive database")
    parser.add_argument('genome_summary_file', nargs="*")
    parser.add_argument("--delim", default=",", help="delimiter")
    parser.add_argument("--quote", default='"', help="quote character")
    parser.add_argument("--dry-run", action="store_true", help="skip insertion")
    parser.add_argument("--no-skip-header", action="store_true", help="don't skip the first line (header line)")
    args = parser.parse_args()

    input = fileinput.FileInput(args.genome_summary_file)
    skip_header = not args.no_skip_header
    if skip_header:
        try:
            input.next()
        except StopIteration:
            # empty input
            pass

    # with HiveConnection("jdbc:hive2://master:10000") as conn:
    # print conn

    # driverName = "org.apache.hadoop.hive.jdbc.HiveDriver";
    # driverName = "org.apache.hive.jdbc.HiveDriver";

    conn = connect("jdbc:hive2://master:10000")

    # ds = HiveDataSource()
    # ds.setServerName("master")
    # ds.setPortNumber(10000)
    # conn = ds.getConnection()

    # com.dbaccess.BasicDataSource ds = new com.dbaccess.BasicDataSource();
    # ds.setServerName("grinder");
    # ds.setDatabaseName("CUSTOMER_ACCOUNTS");
    # ds.setDescription("Customer accounts database for billing");

    # try:
    #     Class.forName(driverName);
    # except Exception, e:
    #     print "Unable to load %s" % driverName
    #     raise
    #     System.exit(1);

    # DriverManager.registerDriver(org.apache.hive.jdbc.HiveDriver)

    # conn = DriverManager.getConnection("jdbc:hive2://master:10000");
    stmt = conn.createStatement();

    # Drop table
    #stmt.executeQuery("DROP TABLE testjython")

    # Create a table
    # res = stmt.executeQuery("CREATE TABLE testjython (key int, value string) ROW FORMAT DELIMITED FIELDS TERMINATED BY ':'")

    # Show tables
    res = stmt.executeQuery("SHOW TABLES")
    print "List of tables:"
    while res.next():
        print res.getString(1)

    load_genome_summary(input, stmt, args.delim, args.quote, args.dry_run)

    conn.close()

def load_genome_summary(table, input, stmt, delim=",", quote='"', dry_run=False):
    tmpdir = tempfile.mkdtemp()
    tmp_loadfile = os.path.join(tmpdir, 'myfifo')
    # print tmp_loadfile
    # try:
    os.mkfifo(tmp_loadfile)
    try:
        # except OSError, e:
        #     print "Failed to create FIFO: %s" % e
        #     return False    
        loadfile_writer = threading.Thread(target=write_snpdb_loadfile, args=(input, tmp_loadfile))
        
        res = stmt.executeQuery("LOAD DATA LOCAL INPATH '%(tmp_loadfile)s' INTO TABLE %(table)s" % { 
            'tmp_loadfile':tmp_loadfile, 'table':table })

        loadfile_writer.join()
    finally:
        os.remove(tmp_loadfile)
        os.rmdir(tmpdir)

def dummy_id_generator():
    i = 1
    while True:
        yield i
        i += 1

def snpdb_load_data(input):

    patient_id_generator = dummy_id_generator()
    vc_id_generator = dummy_id_generator()
    vc_group_id_generator = dummy_id_generator()

    for vc_group, vc_group_id in izip(vcf.vcf_file(input=input), vc_group_id_generator):
        # CREATE TABLE variant (
        #     id bigint, 
        #     chromosome string, 
        #     start_posn int, 
        #     end_posn int, 
        #     ref string, 
        #     alt_alleles array<string>, 
        #     dbsnp_id string, 
        #     quality double, 
        #     filter string, 
        #     ds boolean,
        #     inbreeding_coeff float,
        #     base_q_rank_sum float,
        #     mq_rank_sum float,
        #     read_pos_rank_sum float,
        #     dels float,
        #     fs float,
        #     haplotype_score float,
        #     mq float,
        #     qd float,
        #     sb float,
        #     vqslod float,
        #     an int,
        #     dp int,
        #     mq0 int,
        #     culprit string,
        #     func string, 
        #     gene string, 
        #     exonicfunc string, 
        #     aachange string, 
        #     conserved string, 
        #     1000g2011may_all string, 
        #     dbsnp135 string, 
        #     ljb_phylop_pred string, 
        #     ljb_sift_pred string, 
        #     ljb_polyphen2_pred string, 
        #     ljb_lrt_pred string, 
        #     ljb_mutationtaster_pred string, 
        #     otherinfo string, 
        #     segdup float, 
        #     esp5400_all float, 
        #     avsift float, 
        #     ljb_phylop float, 
        #     ljb_sift float, 
        #     ljb_polyphen2 float, 
        #     ljb_lrt float, 
        #     ljb_mutationtaster float, 
        #     ljb_gerppp float, 
        #     vc map<bigint, 
        #         struct<
        #             id: bigint, 
        #             patient_id: bigint, 
        #             allele1: string, 
        #             allele2: string, 
        #             phased: boolean, 
        #             read_depth: int,
        #             genotype_quality: int,
        #             zygosity: string 
        #         >
        #     >,
        #     alleles array<
        #         struct<
        #             allele: string,
        #             allelic_depth: int
        #         >
        #     >,
        #     genotypes array<
        #         struct<
        #             allele1: string,
        #             allele2: string,
        #             phred_likelihood: int
        #         >
        #     >,
        #     ref_and_alt_alleles array<
        #         struct<
        #             af: float,
        #             mle_af: float,
        #             ac: int,
        #             mle_ac: int
        #         >
        #     >
        # ); 

        yield (
            # vc_group.columns['id'], 
            vc_group_id,
            vc_group.columns['chromosome'], 
            vc_group.columns['start_posn'], 
            vc_group.columns['end_posn'], 
            vc_group.columns['ref'], 
            vc_group.columns['alt_alleles'], 
            vc_group.columns['dbsnp_id'], 
            vc_group.columns['quality'], 
            vc_group.columns['filter'], 
            vc_group.columns['ds'],
            vc_group.columns['inbreeding_coeff'],
            vc_group.columns['base_q_rank_sum'],
            vc_group.columns['mq_rank_sum'],
            vc_group.columns['read_pos_rank_sum'],
            vc_group.columns['dels'],
            vc_group.columns['fs'],
            vc_group.columns['haplotype_score'],
            vc_group.columns['mq'],
            vc_group.columns['qd'],
            vc_group.columns['sb'],
            vc_group.columns['vqslod'],
            vc_group.columns['an'],
            vc_group.columns['dp'],
            vc_group.columns['mq0'],
            vc_group.columns['culprit'],
            vc_group.columns['func'], 
            vc_group.columns['gene'], 
            vc_group.columns['exonicfunc'], 
            vc_group.columns['aachange'], 
            vc_group.columns['conserved'], 
            vc_group.columns['1000g2011may_all'], 
            vc_group.columns['dbsnp135'], 
            vc_group.columns['ljb_phylop_pred'], 
            vc_group.columns['ljb_sift_pred'], 
            vc_group.columns['ljb_polyphen2_pred'], 
            vc_group.columns['ljb_lrt_pred'], 
            vc_group.columns['ljb_mutationtaster_pred'], 
            vc_group.columns['otherinfo'], 
            vc_group.columns['segdup'], 
            vc_group.columns['esp5400_all'], 
            vc_group.columns['avsift'], 
            vc_group.columns['ljb_phylop'], 
            vc_group.columns['ljb_sift'], 
            vc_group.columns['ljb_polyphen2'], 
            vc_group.columns['ljb_lrt'], 
            vc_group.columns['ljb_mutationtaster'], 
            vc_group.columns['ljb_gerppp'], 
            # vc map<bigint, 
            #     struct<
            #     >
            dict([(patient_id_generator.next(), ( 
                # vc.columns['id'], 
                vc_id,
                # vc.columns['patient_id'], 
                patient_id,
                vc.columns['allele1'], 
                vc.columns['allele2'], 
                vc.columns['phased'], 
                vc.columns['read_depth'],
                vc.columns['genotype_quality'],
                vc.columns['zygosity'], 
                # alleles array<
                #     struct<
                #     >
                # >,
                [(
                    vc_allele.columns['allele'],
                    vc_allele.columns['allelic_depth'],
                ) for vc_allele in vc.vc_allele], 
                # genotypes array<
                #     struct<
                #     >
                # >,
                [(
                    vc_genotype.columns['allele1'],
                    vc_genotype.columns['allele2'],
                    vc_genotype.columns['phred_likelihood'],
                ) for vc_genotype in vc.vc_genotype],
            )) for (vc, vc_id, patient_id) in izip(vc_group.vc, vc_id_generator, patient_id_generator)]),
            # ref_and_alt_alleles array<
            #     struct<
            #     >
            # >
            [(
                vc_group_allele.columns['af'],
                vc_group_allele.columns['mle_af'],
                vc_group_allele.columns['ac'],
                vc_group_allele.columns['mle_ac'],
            ) for vc_group_allele in vc_group.vc_group_allele], 
        )

def write_snpdb_loadfile(input, filename):
    hive.write_loadfile(snpdb_load_data, filename)

# "with" statement is not implemented in jython 2.2.1
# class HiveConnection:
#     def __enter__(self, url):
#         self.url = url
#         self.driver = HiveDriver()
#         self.connection = self.driver.connect("jdbc:hive2://master:10000", Properties())
#         return self.connection
# 
#     def __exit__(self, type, value, traceback):
#         self.connection.close()

def connect(url):
    url = url
    driver = HiveDriver()
    connection = driver.connect("jdbc:hive2://master:10000", Properties())
    return connection

if __name__ == '__main__':
    main()
