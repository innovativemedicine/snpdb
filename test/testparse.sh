#!/usr/bin/env bash
echo -n "Enter a rule to parse: "
read rule
echo -n "Enter some input: "
read input
$PYTHON $VCFPARSER "$rule" <<<"$input"
