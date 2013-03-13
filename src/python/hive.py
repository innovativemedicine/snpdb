def write_loadfile(data, filename=None, stream=None, close=True, sort=False):
    depth = 0
    if stream is None:
        stream = open(filename, 'wb')
    write_each(stream, data, depth, lambda d: write_ld(stream, d, depth + 1, sort))
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
                stream.write(k)
                write_depth(stream, depth + 1)
                write_ld(stream, data[k], depth + 2, sort)
            write_each(stream, keys, depth, write_key_value)
    else:
        stream.write(data)

def write_depth(stream, depth):
    stream.write(chr(depth))

def write_each(stream, iterable, depth, f):
    all_but_last(iterable, f, lambda i: write_depth(stream, depth))

def all_but_last(xs, f, g):
    if len(xs) > 0:
        for x in xs[0:len(xs)-1]:
            f(x)
            g(x)
        f(xs[-1])
