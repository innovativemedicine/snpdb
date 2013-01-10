-- Schema description:
--
-- tables:
--     vc
--     vc_group
--     vc_group_info
--     vc_group_info_allele
--     vc_group_allele
--     vc_group_genotype
--     annovar
--
-- We separate a group of variant calls (vc_group) from the variant calls themselves (vc) (i.e. not 
-- denormalized across that relationship), and permit a variant call to belong to multiple 
-- groups (in case this happens in the future).  vc_group is split into vc_group and vc_group_info, 
-- in case vcf files in the future use a different set of fields (in which case one would add a new 
-- vc_group_info table). The vc_group_info_allele, vc_group_allele, and vc_group_genotype tables 
-- are needed since denormalization would force us to store numerial fields as string values. 

-- - maxlen's calculated from PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv
-- - regex constraints are a best guess/approximation based on http://www.1000genomes.org/node/101

-- This is really patient_variant / sample_variant.  A "sample" in this case is synonymous with "a 
-- patient's genome".  We assume patient and sample are 1-to-1, so we neglect have a patient_id in 
-- this table.  If we were to ever have multiple runs for a patient, we'd want to use patient_id's.
-- patient x variant_site x variant
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

    -- vcf 4.0 fields

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
    -- FILTER field). Again, use PASS to indicate that all filters have been passed, a semi-colon 
    -- separated list of codes for filters that fail, or ”.” to indicate that filters have not been 
    -- applied. These values should be described in the meta-information in the same way as FILTERs 
    -- (String, no white-space or semi-colons permitted)
    genotype_filter varchar(60),

    -- Deprecated 4.0 vcf specifications

    -- GL:
    -- three floating point log10-scaled likelihoods for AA,AB,BB genotypes where A=ref and B=alt; 
    -- not applicable if site is not biallelic. For example: GT:GL 0/1:-323.03,-99.29,-802.53 
    -- (Numeric)
    --
    -- NOTE: not all genes are biallelic, however if most genes are, it may make sense in the future to 
    -- cache their values in this table to avoid a join
    -- genotype_likelihood_aa float,
    -- genotype_likelihood_ab float,
    -- genotype_likelihood_bb float,

    -- GQ: genotype quality, encoded as a phred quality -10log_10p(genotype call is wrong) (Numeric) 
    -- GQ:
    -- conditional genotype quality, encoded as a phred quality -10log_10p(genotype call is wrong, 
    -- conditioned on the site's being variant) (Integer)
    genotype_quality float,
    -- HQ: haplotype qualities, two phred qualities comma separated (Numeric)
    haplotype_quality1 float,
    haplotype_quality2 float,

    -- vcf 4.1 fields

    -- vcf 4.1 fields to be added later when needed

    -- GLE:
    -- genotype likelihoods of heterogeneous ploidy, used in presence of uncertain copy number. For 
    -- example: GLE=0:-75.22,1:-223.42,0/0:-323.03,1/0:-99.29,1/1:-802.53 (String)

    -- GP:
    -- the phred-scaled genotype posterior probabilities (and otherwise defined precisely as the GL 
    -- field); intended to store imputed genotype probabilities (Floats)

    -- HQ:
    -- haplotype qualities, two comma separated phred qualities (Integers)

    -- PS:
    -- phase set.  A phase set is defined as a set of phased genotypes to which this genotype 
    -- belongs.  Phased genotypes for an individual that are on the same chromosome and have the same PS 
    -- value are in the same phased set.  A phase set specifies multi-marker haplotypes for the phased 
    -- genotypes in the set.  All phased genotypes that do not contain a PS subfield are assumed to 
    -- belong to the same phased set.  If the genotype in the GT field is unphased, the corresponding PS 
    -- field is ignored.  The recommended convention is to use the position of the first variant in the 
    -- set as the PS identifier (although this is not required). (Non-negative 32-bit Integer)

    -- PQ:
    -- phasing quality, the phred-scaled probability that alleles are ordered incorrectly in a 
    -- heterozygote (against all other members in the phase set).  We note that we have not yet included 
    -- the specific measure for precisely defining "phasing quality"; our intention for now is simply to 
    -- reserve the PQ tag for future use as a measure of phasing quality. (Integer)

    -- EC:
    -- comma separated list of expected alternate allele counts for each alternate allele in the 
    -- same order as listed in the ALT field (typically used in association analyses) (Integers)

    -- MQ:
    -- RMS mapping quality, similar to the version in the INFO field. (Integer) 

    -- unlabelled fields that I've tried to figure out
    zygosity varchar(100), -- field #39

    index (chromosome, start_posn, end_posn, ref, allele1),
    index (chromosome, start_posn, end_posn, ref, allele2),
    primary key(id)
) ENGINE=NDB;

-- patient x variant_site x group
-- (i.e. primary key is set of patient_id, chr, pos, group_id) (assume only ever 1 run)
create table vc_group (
    id bigint not null auto_increment,
    -- we want to refer to vc, to allow for the possibility in the future of a patient being part of multiple "groups"
    vc_id bigint not null,
    genotype_format varchar(256), -- field #48
    -- alts varchar(200), -- field #44, looks like alt for single character, but can be comma separated...
    index (vc_id, id),
    primary key (id)
) ENGINE=NDB;

-- INFO fields are stored here based on type (field #47)
-- relationship between (variant_site [1], variant [n], patient [n])
--
-- Since vcf files can define arbitrary INFO fields in their header, hopefully it's the case that 
-- many vcf files use the same set of fields, and if a bunch of vcf files use a different set of 
-- fields, we could create another vc_group_info_* table.
-- patient x variant_site x group
create table vc_group_info (
    vc_group_id bigint not null,
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

    primary key (vc_group_id),
    index (vc_id, vc_group_id)
) ENGINE=NDB;

-- patient x variant_site x group x variant x allele
-- (i.e. primary key is set patient_id, chr, pos, group_id, allele) (assume only ever 1 run)
create table vc_group_info_allele (
    vc_group_id bigint not null,
    allele varchar(200),

    -- non-standard vcf info fields (from vcf Project_PBC.121113.recal.filtered.snps.vcf)

    -- AF:
    -- Allele Frequency, for each ALT allele, in the same order as listed
    af float,
    -- MLEAF:
    -- Maximum likelihood expectation (MLE) for the allele frequency (not necessarily the same as 
    -- the AF), for each ALT allele, in the same order as listed
    mle_af float,
    -- AC:
    -- Allele count in genotypes, for each ALT allele, in the same order as listed
    ac integer,
    -- MLEAC:
    -- Maximum likelihood expectation (MLE) for the allele counts (not necessarily the same as the 
    -- AC), for each ALT allele, in the same order as listed
    mle_ac integer,

    primary key (vc_group_id, allele)
) ENGINE=NDB;

-- patient x variant_site x group x allele
-- (i.e. primary key is set of patient_id, chr, pos, group_id, allele) (assume only ever 1 run)
create table vc_group_allele (
    -- id bigint not null auto_increment,
    vc_id bigint not null,
    -- allow for the possibility in the future of a patient being part of multiple "groups"
    vc_group_id bigint not null,
    allele varchar(200),

    -- vcf 4.1 genotype fields

    -- AD (from vcf Project_PBC.121113.recal.filtered.snps.vcf):
    -- ##FORMAT=<ID=AD,Number=.,Type=Integer,Description="Allelic depths for the ref and alt alleles in the order listed">
    allelic_depth integer,
    primary key (vc_id, vc_group_id, allele)
) ENGINE=NDB;

-- patient x variant_site x group x genotype (= allele x allele)
-- (i.e. primary key is set of patient_id, chr, pos, group_id, allele1, allele2) (assume only ever 1 run)
create table vc_group_genotype (
    vc_id bigint not null,
    -- allow for the possibility in the future of a patient being part of multiple "groups"
    vc_group_id bigint not null,
    allele1 varchar(200),
    allele2 varchar(200),

    -- vcf 4.1 genotype fields

    -- PL:
    -- the phred-scaled genotype likelihoods rounded to the closest integer (and otherwise defined 
    -- precisely as the GL field) (Integers)
    phred_likelihood integer,

    -- vcf 4.1 genotype fields to be added later when needed

    -- GL:
    -- genotype likelihoods comprised of comma separated floating point log10-scaled likelihoods for 
    -- all possible genotypes given the set of alleles defined in the REF and ALT fields. In presence of 
    -- the GT field the same ploidy is expected and the canonical order is used; without GT field, 
    -- diploidy is assumed. If A is the allele in REF and B,C,... are the alleles as ordered in ALT, the 
    -- ordering of genotypes for the likelihoods is given by: F(j/k) = (k*(k+1)/2)+j.  In other words, 
    -- for biallelic sites the ordering is: AA,AB,BB; for triallelic sites the ordering is: 
    -- AA,AB,BB,AC,BC,CC, etc.  For example: GT:GL 0/1:-323.03,-99.29,-802.53 (Floats)
    -- genotype_likelihood float,

    primary key (vc_id, vc_group_id, allele1, allele2)
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

    primary key (chromosome, start_posn, end_posn, ref, obs)
    -- foreign key (vc_id) references vc(id)
) ENGINE=NDB;
