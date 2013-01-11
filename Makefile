ROOT := .
export ROOT
SCRIPTS := $(ROOT)/script
TESTS := $(ROOT)/test
3RDPARTY_SCRIPTS := $(ROOT)/3rdparty/script
PYTHON := python
export PYTHON

.PHONY: all testparse

all: src/python/vcf/parser.py

src/python/vcf/parser.py: src/python/vcf/parser.g
	$(3RDPARTY_SCRIPTS)/yapps2.py $<
	chmod +x $@

testparse: src/python/vcf/parser.py
	$(TESTS)/testparse.sh

# documentation, maybe use this later
# include Makefile.sphinx
