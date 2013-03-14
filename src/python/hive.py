def write_loadfile(data, filename=None, stream=None, close=True, sort=False):
    depth = 0
    if stream is None:
        stream = open(filename, 'wb')
    for d in data:
        write_ld(stream, d, depth + 1, sort)
        # default row delimiter
        stream.write('\n')
    if close:
        stream.close()

def write_ld(stream, data, depth, sort=False):
    if type(data) in [tuple, list]:
        write_each(stream, data, depth, lambda d: write_ld(stream, d, depth + 1, sort))
    elif type(data) == dict:
        keys = data.keys()
        if sort:
            keys.sort()
        if len(keys) > 0:
            def write_key_value(k):
                write_prim(stream, k)
                write_depth(stream, depth + 1)
                write_ld(stream, data[k], depth + 2, sort)
            write_each(stream, keys, depth, write_key_value)
    else:
        write_prim(stream, data)

def write_prim(stream, prim):
    assert type(prim) not in [list, dict, tuple]
    val = prim
    if val is None:
        val = 'null'
    elif type(val) == bool:
        val = 'true' if val else 'false'
    else:
        val = str(val)
    stream.write(val)

def write_depth(stream, depth):
    stream.write(chr(depth))

def write_each(stream, iterable, depth, f):
    all_but_last(iterable, f, lambda i: write_depth(stream, depth))

def all_but_last(xs, f, g):
    last = None
    at_least_one = False
    try:
        i = iter(xs)
        last = i.next()
        at_least_one = True
        while True:
            x = i.next()
            f(last)
            g(last)
            last = x
    except StopIteration:
        if at_least_one: 
            f(last)
