-- - maxlen's calculated from PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv
-- - regex constraints are a best guess/approximation based on http://www.1000genomes.org/node/101

create table vc (
    id bigint not null auto_increment,
    -- columns 22,28,34,40 (22 == Chr, 28,34,40 == unlabeled) were all the same
    chromosome varchar(50), -- maxlen(Chr) == 21, 0 nulls
    -- columns 23,24,29,30,35,36,41 (23 == Start, 24 == End) were all the same
    start_posn integer, -- >= 1 ? 0 nulls
    end_posn integer, -- >= 1 ? 0 nulls
    -- columns 25,31,37,43 (25 == Ref, 31,37,43 == unlabeled) were all the same
    ref varchar(200), -- maxlen(Ref) == 1, 0 nulls, I think [ACGTN]+, arbitrary choice
    -- columns 26,32,38 (26 == Obs, 32,38 == unlabeled) were all the same
    alt varchar(200), -- maxlen(Obs) == 1, 0 nulls, I think (([ACGTN]+|<$ID>);)+, arbitrary choice
    alts varchar(200), -- field #44, looks like alt for single character, but can be comma separated...
    quality double, -- field #45, "traditionally people use integer phred scores, this field is permitted to be a floating point to enable higher resolution for low confidence calls if desired" (not defined in summary file for whatever reason)
    filter varchar(60), -- field #46, maxlen() == 27 "traditionally people use integer phred scores, this field is permitted to be a floating point to enable higher resolution for low confidence calls if desired" (not defined in summary file for whatever reason)
    dbsnp_id varchar(200), -- field #42
    primary key(id)
) ENGINE=NDB;

create table annotation (
    id bigint not null auto_increment,
    vc_id bigint not null,

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

    -- unlabelled fields that I've tried to figure out
    zygosity varchar(100), -- field #39
    genotype_format varchar(256), -- field #48

    -- unlabelled fields that I can't figure out
    genotype1 varchar(100), -- field #49
    genotype2 varchar(100), -- field #50
    genotype3 varchar(100), -- field #51
    genotype4 varchar(100), -- field #52
    genotype5 varchar(100), -- field #53
    genotype6 varchar(100), -- field #54
    genotype7 varchar(100), -- field #55
    genotype8 varchar(100), -- field #56
    genotype9 varchar(100), -- field #57
    genotype10 varchar(100), -- field #58
    genotype11 varchar(100), -- field #59
    genotype12 varchar(100), -- field #60

    primary key (id)
    -- foreign key (vc_id) references vc(id)
) ENGINE=NDB;

-- INFO fields are stored here based on type (field #47)

create table vc_attr_bool (
    attr varchar(50), -- maxlen(attribute names) == 15, arbitrary choice
    value bool,
    vc_id bigint not null
    -- constraint `vc_attr_bool_fk` foreign key (vc_id) references vc(id)
) ENGINE=ndb;

create table vc_attr_float (
    attr varchar(50), -- maxlen(attribute names) == 15, arbitrary choice
    value float,
    vc_id bigint not null
    -- constraint `vc_attr_float_fk` foreign key (vc_id) references vc(id)
) ENGINE=ndb;

create table vc_attr_int (
    attr varchar(50), -- maxlen(attribute names) == 15, arbitrary choice
    value int,
    vc_id bigint not null
    -- constraint `vc_attr_int_fk` foreign key (vc_id) references vc(id)
) ENGINE=ndb;

create table vc_attr_str (
    attr varchar(50), -- maxlen(attribute names) == 15, arbitrary choice
    value varchar(256), -- arbitrary choice
    vc_id bigint not null
    -- constraint `vc_attr_str_fk` foreign key (vc_id) references vc(id)
) ENGINE=ndb;

