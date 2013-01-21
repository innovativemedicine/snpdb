-- Query all the snps in the database.
select distinct chromosome, start_posn, allele1 from vc_group, vc where vc.vc_group_id = vc_group.id
union 
select distinct chromosome, start_posn, allele2 from vc_group, vc where vc.vc_group_id = vc_group.id

