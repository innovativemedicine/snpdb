ROOT := .
export ROOT
SCRIPTS := $(ROOT)/script
TESTS := $(ROOT)/test
3RDPARTY_SCRIPTS := $(ROOT)/3rdparty/script
PYTHON := python
export PYTHON

.PHONY: all testparse

all: src/python/vcf/vcfparser.py

src/python/vcf/vcfparser.py: src/python/vcf/vcfparser.g
	$(3RDPARTY_SCRIPTS)/yapps2.py $<
	chmod +x $@

testparse: src/python/vcf/vcfparser.py
	$(TESTS)/testparse.sh

# documentation, maybe use this later
# include Makefile.sphinx
