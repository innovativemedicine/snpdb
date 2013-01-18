select * from
    vc_group,
    vc_group_allele
where
    vc_group_allele.vc_group_id = vc_group.id
