-- - maxlen's calculated from PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv
-- - regex constraints are a best guess/approximation based on http://www.1000genomes.org/node/101

-- This is really patient_variant / sample_variant.  A "sample" in this case is synonymous with "a 
-- patient's genome".  We assume patient and sample are 1-to-1, so we neglect have a patient_id in 
-- this table.  If we were to ever have multiple runs for a patient, we'd want to use patient_id's.
-- patient x variant
create table vc (
    id bigint not null auto_increment,

    -- variant
    
    -- fields 22,28,34,40 (22 == Chr, 28,34,40 == unlabeled) were all the same
    chromosome varchar(50), -- maxlen(Chr) == 21, 0 nulls
    -- fields 23,24,29,30,35,36,41 (23 == Start, 24 == End) were all the same
    start_posn integer, -- >= 1 ? 0 nulls
    end_posn integer, -- >= 1 ? 0 nulls
    -- fields 25,31,37,43 (25 == Ref, 31,37,43 == unlabeled) were all the same
    -- the reference allele
    ref varchar(200), -- maxlen(Ref) == 1, 0 nulls, I think [ACGTN]+, arbitrary choice
    -- fields 26,32,38 (26 == Obs, 32,38 == unlabeled) were all the same
    -- alt varchar(200), -- maxlen(Obs) == 1, 0 nulls, I think (([ACGTN]+|<$ID>);)+, arbitrary choice

    quality double, -- field #45, "traditionally people use integer phred scores, this field is permitted to be a floating point to enable higher resolution for low confidence calls if desired" (not defined in summary file for whatever reason)
    filter varchar(60), -- field #46, maxlen() == 27 "traditionally people use integer phred scores, this field is permitted to be a floating point to enable higher resolution for low confidence calls if desired" (not defined in summary file for whatever reason)
    dbsnp_id varchar(200), -- field #42

    -- maybe useful to retain fields that aren't defined in this table... but in that case one 
    -- should consider adding a new vc_group_info_* table, or add desired fields to an existing 
    -- vc_group_info_* table (perhaps this should be of TEXT type?)
    genotype_source varchar(100), -- field #49-60

    -- TODO: below, genotype was defined using the VCF 4.0 standard; we ought to use 4.1 (and add 
    -- fields not founds in 4.1 such as AD)
    -- www.1000genomes.org/wiki/Analysis/Variant Call Format/vcf-variant-call-format-version-41

    -- given:
    -- alt = C,T
    -- genotype_source = 2/2:0,0,5:5:9:128,128,128,9,9,0
    -- genotype_format = GT:AD:DP:GQ:PL

    -- GT:
    -- genotype, encoded as alleles values separated by either of ”/” or “|”, e.g. The allele values 
    -- are 0 for the reference allele (what is in the reference sequence), 1 for the first allele 
    -- listed in ALT, 2 for the second allele list in ALT and so on. For diploid calls examples 
    -- could be 0/1 or 1|0 etc. For haploid calls, e.g. on Y, male X, mitochondrion, only one allele 
    -- value should be given. All samples must have GT call information; if a call cannot be made 
    -- for a sample at a given locus, ”.” must be specified for each missing allele in the GT field 
    -- (for example ./. for a diploid). The meanings of the separators are:
    --     / : genotype unphased
    --     | : genotype phased
    allele1 varchar(200), -- = T
    allele2 varchar(200), -- = T
    -- | => true, / => false
    phased boolean, -- = false
    -- DP:
    -- read depth at this position for this sample (Integer)
    read_depth integer,
    -- FT:
    -- sample genotype filter indicating if this genotype was “called” (similar in concept to the 
    -- FILTER field). Again, use PASS to indicate that all filters have been passed, a 
    -- semi-colon separated list of codes for filters that fail, or ”.” to indicate that filters 
    -- have not been applied. These values should be described in the meta-information in the same 
    -- way as FILTERs (Alphanumeric String)
    genotype_filter varchar(60),
    -- GL:
    -- three floating point log10-scaled likelihoods for AA,AB,BB genotypes where A=ref and B=alt; 
    -- not applicable if site is not biallelic. For example: GT:GL 0/1:-323.03,-99.29,-802.53 
    -- (Numeric)
    genotype_likelihood_aa float,
    genotype_likelihood_ab float,
    genotype_likelihood_bb float,
    -- GQ: genotype quality, encoded as a phred quality -10log_10p(genotype call is wrong) (Numeric) 
    genotype_quality float,
    -- HQ: haplotype qualities, two phred qualities comma separated (Numeric)
    haplotype_quality1 float,
    haplotype_quality2 float,
    -- PL: the phred-scaled genotype likelihoods rounded to the closest integer (and otherwise defined 
    -- precisely as the GL field) (Integers)

    -- unlabelled fields that I've tried to figure out
    zygosity varchar(100), -- field #39

    index (chromosome, start_posn, end_posn, ref, allele1),
    index (chromosome, start_posn, end_posn, ref, allele2),
    primary key(id)
) ENGINE=NDB;

-- vc_group (= patient x variant) specific (i.e. primary key is set of patient_id, chr, pos, alt, group_id) (assume only ever 1 run)
create table vc_group (
    id bigint not null auto_increment,
    -- we want to refer to vc, to allow for the possibility in the future of a patient being part of multiple "groups"
    vc_id bigint not null,
    genotype_format varchar(256), -- field #48
    alts varchar(200), -- field #44, looks like alt for single character, but can be comma separated...
    index (vc_id),
    primary key (id)
) ENGINE=NDB;

-- annotations generated by the annovar tool (i.e. fields 1-27).  According to http://www.openbioinformatics.org/annovar/annovar_input.html:
-- ANNOVAR takes text-based input files, where each line corresponds to one variant. On each line, 
-- the first five space- or tab- delimited columns represent chromosome, start position, end 
-- position, the reference nucleotides and the observed nucleotides. Additional columns can be 
-- supplied and will be printed out in identical form.
-- 
-- So, annovar is a SNP annotater, where it's annotations are deteremined by the key
-- (chromosome, start position, end position, reference nucleotides, observed [a.k.a. alt] nucleotides)
create table annovar (
    -- id bigint not null auto_increment,

    -- field 22
    chromosome varchar(50), -- maxlen(Chr) == 21, 0 nulls
    -- field 23
    start_posn integer, -- >= 1 ? 0 nulls
    -- field 24
    end_posn integer, -- >= 1 ? 0 nulls
    -- field 25
    ref varchar(200), -- maxlen(Ref) == 1, 0 nulls, I think [ACGTN]+, arbitrary choice
    -- field 26
    obs varchar(200), -- maxlen(Obs) == 1, 0 nulls, I think (([ACGTN]+|<$ID>);)+, arbitrary choice

    -- strings
    func varchar(38), -- maxlen(Func) == 19, 0 nulls
    gene varchar(368), -- maxlen(Gene) == 184, 0 nulls
    exonicfunc varchar(34), -- maxlen(ExonicFunc) == 17, 66012 nulls
    aachange varchar(62), -- maxlen(AAChange) == 31, 66012 nulls
    conserved varchar(36), -- maxlen(Conserved) == 18, 61461 nulls
    1000g2011may_all varchar(256), -- 70732 nulls
    dbsnp135 varchar(256), -- 70732 nulls
    ljb_phylop_pred varchar(2), -- maxlen(LJB_PhyloP_Pred) == 1, 68762 nulls
    ljb_sift_pred varchar(4), -- maxlen(LJB_SIFT_Pred) == 2, 68762 nulls
    ljb_polyphen2_pred varchar(4), -- maxlen(LJB_PolyPhen2_Pred) == 2, 68762 nulls
    ljb_lrt_pred varchar(4), -- maxlen(LJB_LRT_Pred) == 2, 68762 nulls
    ljb_mutationtaster_pred varchar(4), -- maxlen(LJB_MutationTaster_Pred) == 2, 68762 nulls
    -- columns 27,33 (27 == Otherinfo, 33 unlabeled) were all the same
    otherinfo varchar(14), -- maxlen(Otherinfo) == 7, 0 nulls

    -- floats
    segdup float, -- maxlen(SegDup) == 4, 46354 nulls
    esp5400_all float, -- maxlen(ESP5400_ALL) == 8, 66454 nulls
    avsift float, -- maxlen(AVSIFT) == 4, 67160 nulls
    ljb_phylop float, -- maxlen(LJB_PhyloP) == 8, 68762 nulls
    ljb_sift float, -- maxlen(LJB_SIFT) == 8, 68762 nulls
    ljb_polyphen2 float, -- maxlen(LJB_PolyPhen2) == 8, 68762 nulls
    ljb_lrt float, -- maxlen(LJB_LRT) == 8, 68762 nulls
    ljb_mutationtaster float, -- maxlen(LJB_MutationTaster) == 8, 68762 nulls
    ljb_gerppp float, -- maxlen(LJB_GERP++) == 8, 68762 nulls

    -- primary key (id)
    primary key (chromosome, start_posn, end_posn, ref, obs)
    -- foreign key (vc_id) references vc(id)
) ENGINE=NDB;

-- INFO fields are stored here based on type (field #47)
-- relationship between (variant_site [1], variant [n], patient [n])
--
-- Since vcf files can define arbitrary INFO fields in their header, hopefully it's the case that 
-- many vcf files use the same set of fields, and if a bunch of vcf files use a different set of 
-- fields, we could create another vc_group_info_* table.
create table vc_group_info (
    id bigint not null auto_increment,
    -- we want to refer to vc, to allow for the possibility in the future of a patient being part of multiple "groups"
    vc_id bigint not null,

    -- maybe useful to retain fields that aren't defined in this table... but in that case one 
    -- should consider adding a new vc_group_info_* table, or add desired fields to an existing 
    -- vc_group_info_* table (perhaps this should be of TEXT type?)
    info_source varchar(256), -- field #48

    -- variant specific for reference (i.e. primary key is chr, pos, ref)
    -- DB
    -- Description: dbSNP Membership
    db boolean,

    -- variant specific for alt (i.e. primary key is chr, pos, alt)

    -- DS
    -- Description: Were any of the samples downsampled?
    ds boolean,
    -- InbreedingCoeff
    -- Description: Inbreeding coefficient as estimated from the genotype likelihoods per-sample when compared against the Hardy-Weinberg expectation
    inbreeding_coeff float,
    -- BaseQRankSum
    -- Description: Z-score from Wilcoxon rank sum test of Alt Vs. Ref base qualities
    base_q_rank_sum float,
    -- MQRankSum
    -- Description: Z-score From Wilcoxon rank sum test of Alt vs. Ref read mapping qualities
    mq_rank_sum float,
    -- ReadPosRankSum
    -- Description: Z-score from Wilcoxon rank sum test of Alt vs. Ref read position bias
    read_pos_rank_sum float,
    -- Dels
    -- Description: Fraction of Reads Containing Spanning Deletions
    dels float,
    -- FS
    -- Description: Phred-scaled p-value using Fisher's exact test to detect strand bias
    fs float,
    -- HaplotypeScore
    -- Description: Consistency of the site with at most two segregating haplotypes
    haplotype_score float,
    -- MQ
    -- Description: RMS Mapping Quality
    mq float,
    -- QD
    -- Description: Variant Confidence/Quality by Depth
    qd float,
    -- SB
    -- Description: Strand Bias
    sb float,
    -- VQSLOD
    -- Description: Log odds ratio of being a true variant versus being false under the trained gaussian mixture model
    vqslod float,
    -- AN
    -- Description: Total number of alleles in called genotypes
    an integer,
    -- DP
    -- Description: Approximate read depth; some reads may have been filtered
    dp integer,
    -- MQ0
    -- Description: Total Mapping Quality Zero Reads
    mq0 integer,
    -- culprit
    -- Description: The annotation which was the worst performing in the Gaussian mixture model, likely the reason why the variant was filtered out
    -- maxlen == 15
    culprit varchar(30),

    primary key (id),
    index (vc_id)
) ENGINE=NDB;

-- (patient x variant x group) x variant specific (i.e. primary key is set patient_id, vc_group_info_id, chr, pos, alt) (assume only ever 1 run)
create table vc_group_info_variant (
    id bigint not null auto_increment,
    vc_group_info_id bigint not null,

    -- AF
    -- Description: Allele Frequency, for each ALT allele, in the same order as listed
    allele1_af float,
    allele2_af float,
    -- MLEAF
    -- Description: Maximum likelihood expectation (MLE) for the allele frequency (not necessarily the same as the AF), for each ALT allele, in the same order as listed
    allele1_mle_af float,
    allele2_mle_af float,
    -- AC
    -- Description: Allele count in genotypes, for each ALT allele, in the same order as listed
    allele1_ac integer,
    allele2_ac integer,
    -- MLEAC
    -- Description: Maximum likelihood expectation (MLE) for the allele counts (not necessarily the same as the AC), for each ALT allele, in the same order as listed
    allele1_mle_ac integer,
    allele2_mle_ac integer,

    primary key (id),
    index (vc_group_info_id)
) ENGINE=NDB;
