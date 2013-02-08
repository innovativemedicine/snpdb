#!/usr/bin/env python
import argparse
import csv
import fileinput
import sys

def main():
    parser = argparse.ArgumentParser(description="count the number of blank/null fields in the columns of a delimiter separated file")
    parser.add_argument('--delim', '-d', default="\t")
    parser.add_argument('--out-delim', default="\t")
    parser.add_argument('--no-skip-header', action="store_true")
    parser.add_argument('--totals', action="store_true", help="print totals instead of percentage")
    parser.add_argument('--non-null', action="store_true", help="print non-nulls instead of nulls")
    parser.add_argument('files', nargs='*')
    args = parser.parse_args()

    input = csv.reader(fileinput.input(args.files), delimiter=args.delim)
    output = csv.writer(sys.stdout, delimiter=args.out_delim, quotechar='"', quoting=csv.QUOTE_MINIMAL)

    num_lines = 0
    if not args.no_skip_header:
        try:
            input.next()
        except StopIteration:
            pass
    num_cols = 0
    try:
        row = input.next()
        num_lines += 1
        num_cols = len(row)
        counts = [0 for i in xrange(num_cols)]
        while True:
            for i in xrange(len(row)):
                if row[i] == '' and not args.non_null or row[i] != '' and args.non_null:
                    counts[i] += 1
            row = input.next()
            num_lines += 1
    except StopIteration:
        if num_cols > 0:
            output.writerow(xrange(1, num_cols + 1))
            if args.totals:
                output.writerow(counts)
            else:
                output.writerow([round(n / float(num_lines), 2) for n in counts])
         

if __name__ == '__main__':
    main()
