select * from
    vc,
    vc_allele
where
    vc_allele.vc_id = vc.id and vc.allele1 = vc_allele.allele
