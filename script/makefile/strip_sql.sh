#!/usr/bin/env bash
# Given a list of sql files, or a input stream of sql, strip newlines and comments, and end it with a semicolon if it 
# doesn't already have one.
# perl -p -e '/^\s*--/d;s/\s*--.*//' "$@"
sed -e '/^\s*--/d' \
    -e 's/\s*--.*//' "$@" \
    | perl -e '$f = do { local $/; <STDIN>; }; $f =~ s/\s*\n\s*/ /g; $f =~ s/;?\s*$/;/; print "$f\n"'
