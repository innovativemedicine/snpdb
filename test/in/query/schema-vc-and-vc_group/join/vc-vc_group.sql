select * from
    vc,
    vc_group
where
    vc.vc_group_id = vc_group.id
