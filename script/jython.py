#!/usr/bin/env python
import argparse
import subprocess
from os import environ as env

def main():
    parser = argparse.ArgumentParser(description="Wrapper for jython 2.2.1 on CentOS that properly uses JYTHONPATH (not implemented until jython 2.5)")
    # parser.add_argument('--madeup')
    args, extra_args = parser.parse_known_args()
    jython_args = []
    if 'JYTHONPATH' in env:
        jython_args.append("-Dpython.path=" + env['JYTHONPATH'])
    # /usr/bin/jython -Dpython.path=$JYTHONPATH
    subprocess.check_call(["jython"] + jython_args + extra_args)

if __name__ == '__main__':
    main()
