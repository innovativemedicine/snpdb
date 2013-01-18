-- Join all the tables together, which is something that would have to be done if say, a user wanted 
-- to output the original vcf file from which data was inserted.
select * from
    vc,
    vc_allele,
    vc_group,
    vc_group_allele,
    vc_genotype
where
    vc.vc_group_id = vc_group.id and
    vc_group_allele.vc_group_id = vc.vc_group_id and (vc_group_allele.allele = vc.allele1 or vc_group_allele.allele = vc.allele2) and
    (vc_allele.vc_id = vc.id and vc.allele1 = vc_allele.allele or vc_allele.vc_id = vc.id and vc.allele2) and
    vc_genotype.allele1 = vc_genotype.allele1 and vc_genotype.allele2 = vc_genotype.allele2
