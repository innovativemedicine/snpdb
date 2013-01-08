#!/usr/bin/env python 
import vcf
import argparsers

import argparse
import fileinput
import re
import sys
import collections
import csv

class InfoField:
    def __init__(self):
        self.count = 0
        self.attr_type = None
        self.is_list = False
        self.maxlen = 0

def main():
    parser = argparse.ArgumentParser(description="Figure out what info fields are used in a vcf file (their name, types, length, etc.)", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    argparsers.add_genome_summary_options(parser)
    parser.add_argument("--info", help="index of info field", default=47)
    args = parser.parse_args()

    input = csv.reader(fileinput.input(), delimiter=args.delim, quotechar=args.quote)
    if not args.no_skip_header:
        try:
            input.next()
        except StopIteration:
            # empty input
            pass

    field_count = collections.defaultdict(InfoField)
    n = 0
    for row in input:
        print row
        for attr in row[args.info-1].split(r";"):
            (name, value) = vcf.parse_info_attr(attr)
            attr_type = type(value)
            name_value_pair = attr.split('=')
            if re.match(r"^\s*$", name):
                print >> sys.stderr, "field name for row {lineno} was blank, skipping: {row}".format(lineno=input.lineno(), row=row)
                continue
            n += 1
            field = field_count[name] 
            if attr_type == list:
                field.is_list = True
                attr_type = type(value[0])
            if attr_type in vcf.typeable_as[field.attr_type]:
                field.attr_type = attr_type
                if field.attr_type is str:
                    field.maxlen = max(field.maxlen, len(value)) 
            field.count += 1
    
    print n, "rows"
    print '\t'.join(['INFO_name', 'type', 'is_list', 'non_nulls', 'percent_non_nulls', 'maxlen'])
    for name, field in field_count.iteritems():
        print '\t'.join(map(str, [name, field.attr_type, field.is_list, field.count, (field.count*100)/n, field.maxlen]))

if __name__ == '__main__':
    main()
