select * from
    vc,
    vc_group,
    vc_group_allele
where
    vc.vc_group_id = vc_group.id and
    vc_group_allele.vc_group_id = vc_group.id and vc.allele1 = vc_group_allele.allele
