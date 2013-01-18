-- Query all the snps in the database.
select distinct chromosome, start_posn, allele1 from vc
union 
select distinct chromosome, start_posn, allele2 from vc
