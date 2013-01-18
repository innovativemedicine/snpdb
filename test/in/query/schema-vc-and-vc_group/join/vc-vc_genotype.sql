select * from
    vc,
    vc_genotype
where
    vc_genotype.vc_id = vc.id and vc_genotype.allele1 = vc_genotype.allele1 and vc_genotype.allele2 = vc_genotype.allele2
