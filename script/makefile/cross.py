#!/usr/bin/env python
import argparse
import itertools
import sys

def main():
    parser = argparse.ArgumentParser(description="Take the cross product of the lines of")
    parser.add_argument('files', nargs='*')
    parser.add_argument('--delim', '-d', default='\t')
    args = parser.parse_args()

    filehandles = [open(f, 'r') if f != '-' else sys.stdin for f in args.files]

    for lines in itertools.product(*filehandles): 
        print args.delim.join(l.rstrip() for l in lines)

    for f in filehandles:
        f.close()

if __name__ == '__main__':
    main()
