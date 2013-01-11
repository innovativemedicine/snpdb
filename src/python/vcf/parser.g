parser VCF:
    ignore:      r'\s+'

    token COMMA: r","
    token COLON: r":"
    token SEMICOLON: r";"
    token EQUALS: r"="
    token SLASH: r"/"
    token DOT: r"\."
    token INT: r"[-+]?(?:0|[1-9][0-9]*)"
    token FLOAT: r"[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?"
    token STR: r".*"
    token END: r'$'
    token IDENTIFIER: r"[a-zA-Z][a-zA-Z0-9]*"
    token NUCLEOTIDES: r"[ACGTN]+"

    token INFO_STR: r"[^,;\n]+"

    # Genotype field 
    # (e.g. 0/0:22,2,1:25:59:0,60,715,59,684,681)
    # format is GT:AD:DP:GQ:PL for PBC.121029.hg19_ALL.sites.2011_05_filtered.genome_summary.csv

    rule genotype: 
        (
        DOT {{ allele1 = DOT }} SLASH DOT {{ allele2 = DOT }} {{ return (allele1, allele2) }} |
        GT
        COLON AD
        COLON DP
        COLON GQ
        COLON PL
        {{ return { 'GT':GT, 'AD':AD, 'DP':DP, 'GQ':GQ, 'PL':PL } }}
        )

    rule genotype_format_field: IDENTIFIER {{ return IDENTIFIER }} 

    rule genotype_format:
        {{ e = [] }}
        genotype_format_field {{ e.append(genotype_format_field) }}
        ( COLON genotype_format_field {{ e.append(genotype_format_field) }} ) *
        {{ return e }}

    rule GT: 
        integer {{ allele1 = integer }} SLASH integer {{ allele2 = integer }} {{ return (allele1, allele2) }}

    rule AD: int_list {{ return int_list }}
    rule DP: integer {{ return integer }}
    rule GQ: integer {{ return integer }}
    rule PL: int_list {{ return int_list }}

    # INFO field

    rule info_list:
        {{ e = {} }}
        info {{ e[info[0]] = info[1] }}
        ( SEMICOLON info {{ e[info[0]] = info[1] }} ) *
        {{ return e }}

    rule info:
        genotype_format_field {{ value = True }}
        ( EQUALS info_value {{ value = info_value }} )?
        {{ return (genotype_format_field, value) }}

    rule info_value:
        int_or_int_list {{ return int_or_int_list }}
        | float_or_float_list {{ return float_or_float_list }}
        | INFO_STR {{ return INFO_STR }}

    # REF and ALTS fields

    rule ref: allele {{ return allele }}

    rule alts: 
        {{ e = [] }}
        allele {{ e.append(allele) }}
        ( COMMA allele {{ e.append(allele) }} ) *
        {{ return e }}

    rule allele:
        DOT {{ return DOT }} | NUCLEOTIDES {{ return NUCLEOTIDES }}

    # rule list: 
    #     {{ e = [] }}
    #     number {{ e.append(number) }}
    #     ( COMMA number {{ e.append(number) }} ) *
    #     {{ return e }}

    # Generic values used in various rules above

    rule integer: INT {{ return int(INT) }}
    rule floating: FLOAT {{ return float(FLOAT) }}

    # NOTE: tokens are parsed in the order in which they are defined, not the order in which they 
    # appear in this rule 
    rule scalar: 
        INT  {{ return int(INT) }}
      | FLOAT {{ return float(FLOAT) }}
      | STR  {{ return STR }}

    rule number:
        INT  {{ return int(INT) }}
      | FLOAT {{ return float(FLOAT) }}

    rule int_or_int_list: 
        {{ e = [] }}
        integer {{ e.append(integer) }}
        ( COMMA integer {{ e.append(integer) }} ) *
        {{ return e[0] if len(e) == 1 else e }}

    rule float_or_float_list: 
        {{ e = [] }}
        floating {{ e.append(floating) }}
        ( COMMA floating {{ e.append(floating) }} ) *
        {{ return e[0] if len(e) == 1 else e }}

    rule int_list: 
        {{ e = [] }}
        integer {{ e.append(integer) }}
        ( COMMA integer {{ e.append(integer) }} ) *
        {{ return e }}

    rule float_list: 
        {{ e = [] }}
        FLOAT {{ e.append(FLOAT) }}
        ( COMMA FLOAT {{ e.append(FLOAT) }} ) *
        {{ return e }}
