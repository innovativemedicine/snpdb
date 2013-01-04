import argparse

def sql_option_parser(description=None):
    """
    Return a arugment parser with the typical database options (minus database name positional argument).
    """
    parser = argparse.ArgumentParser(description=description, formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--host', help='database hostname', default='localhost')
    parser.add_argument('--port', type=int, help='database port', default='3306')
    parser.add_argument('--user', help='database user', default='root')
    parser.add_argument('--password', help='database password', default='')
    return parser
 
def sql_parser(description=None):
    """
    Return a arugment parser with the typical database arguments.
    """
    parser = sql_option_parser(description=description)
    parser.add_argument('db', help='database name')
    return parser
