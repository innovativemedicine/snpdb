# http://www.regular-expressions.info/floatingpoint.html
import vcfparser
import re
import yapps

# same as the default parse function generated in vcfparser.py, but also re-raises the exception
def parse(rule, text): 
    parser = vcfparser.VCF(vcfparser.VCFScanner(text))
    def _wrap_error_reporter(rule, *args,**kw):
        try:
            return getattr(parser, rule)(*args,**kw)
        except yapps.runtime.SyntaxError, e:
            yapps.runtime.print_error(e, parser._scanner)
            raise e
        except yapps.runtime.NoMoreTokens, e:
            print >>sys.stderr, 'Could not complete parsing; stopped around here:'
            print >>sys.stderr, parser._scanner
            raise e
    return _wrap_error_reporter(rule)

float_restr = r"[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?"
int_restr = "[-+]?(?:0|[1-9][0-9]*)"

def attr_restr(value_restr):
    return "(?P<attr>{attr_restr})(?:=(?P<value>{value_restr}))?".format(attr_str=r"[a-zA-Z]+", value_restr=value_restr)

def anchor(restr):
    return "^" + restr + "$"

float_re = re.compile(anchor(float_restr))
int_re = re.compile(anchor(int_restr))

typeable_as = {
        None: frozenset([int, float, bool, str]),
        int: frozenset([int, float, str]),
        float: frozenset([float, str]),
        str: frozenset([str]),
        bool: frozenset([bool]),
        }

def parse_info_attr(attr):
    attr_value = attr.split('=')
    attr = attr_value[0]
    if len(attr_value) == 2:
        return (attr, parse_value(attr_value[1]))
    else:
        return (attr, True)

def parse_scalar_value(value):
    result = int_re.match(value)
    if result is not None:
        return int(value)
    result = float_re.match(value)
    if result is not None:
        return float(value)
    # return a str
    return value

def base_type(values, default=None):
    if len(values) == 0:
        return default
    types = frozenset([type(v) for v in values])
    i = iter(types)
    common_types = set(typeable_as[i.next()])
    for t in i:
        common_types.intersection_update(typeable_as[t])
    if len(common_types) == 1:
        return iter(common_types).next()
    common_types.intersection_update(types)
    if len(common_types) == 1:
        return iter(common_types).next()
    return default

def parse_value(value):
    values = value.split(',')
    if len(values) != 1:
        parsed_values = [parse_scalar_value(v) for v in values]
        btype = base_type(parsed_values, default=str)
        return [btype(v) for v in parsed_values]
    return parse_scalar_value(value)

def parse_info(info):
    attrs_by_type = {
        str: [],
        int: [],
        float: [],
        bool: [],
    }
    for attr_str in info.split(';'):
        attr_pair = parse_info_attr(attr_str)  
        attrs_by_type[type(attr_pair[1])].append(attr_pair)
    return attrs_by_type

def ordered_alleles(ref, alts):
    if type(alts) == str:
        alts = alts.split(',')
    genotypes = []
    alleles = []
    last_alleles = [ref]
    last_alleles.extend(alts)
    for x in last_alleles:
        alleles.append(x)
        for y in alleles:
            genotypes.append((y, x))
    return genotypes
