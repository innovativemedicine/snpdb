import sys

class Table(object):
    def __init__(self, name, cursor=None, fields=None):
        self.name = name
        self.cursor = cursor 
        self.fields = fields
        self.lastrowid = None

    # insert(cursor, table, dict={ 'x':1, 'y':2 })
    # insert(cursor, table, fields={..}, values={..})
    def insert(self, dic=None, fields=None, values=None, cursor=None):
        """Insert data into this table"""

        if cursor is None:
            cursor = self._get_attr('cursor')
        if fields is None and dic is None:
            fields = self._get_attr('fields')
            raise RuntimeError("Must provide either a lists of fields and values, or a dictionary for insertion into {name}".format(name=self.name))
        if fields is not None and dic is not None:
            raise RuntimeError("Must provide only one of lists of fields and values, or a dictionary for insertion into {name}".format(name=self.name))
        if dic is not None:
            # usage was insert(cursor, table, dict={ 'x':1, 'y':2 })
            fields = dic.keys()
            values = dic.values()
            # usage was insert(cursor, table, fields={..}, values={..})
        if len(fields) != len(values):
            raise RuntimeError("Number of fields didn't match number of values for insert into {name}".format(name=self.name))

        return self._do_insert(cursor, self._get_insert_many_query(fields), fields, values)

    def _get_attr(self, attr):
        value = getattr(self, attr)
        if value is None:
            raise RuntimeError("Need {attr} for inserting into {name}".format(attr=attr, name=self.name))
        return value 

    def _get_insert_many_query(self, fields):
        sql_params = ', '.join([self._param]*len(fields))
        return """insert into {table} ({fields}) values ({values})""".format(table=self.name, fields=', '.join(fields), values=sql_params)

    def _get_insert_params(self, dic=None, fields=None, values=None, cursor=None):

        if cursor is None:
            cursor = self._get_attr('cursor')

        # def values_from_dic():
        #     if values is None:
        #         values = [dic[f] for f in fields]
        if self.fields is not None:
            fields = self.fields
            if values is None:
                values = [dic[f] for f in fields]
        elif fields is not None:
            if values is None:
                values = [dic[f] for f in fields]
        else:
            fields = dic.keys()
            values = dic.values()

        if len(fields) != len(values):
            raise RuntimeError("Number of fields didn't match number of values for insert into {name}".format(name=self.name))

        return (fields, values, cursor)

    def _do_insert(self, cursor, query, fields, values):
        result = cursor.execute(self._get_insert_many_query(fields), values)
        # not sure if this will work for tables without autoincrement...
        self.lastrowid = cursor.lastrowid
        return result

class MySQLdb(Table):
    _param = '%s'
    def __init__(self, name, cursor=None, fields=None):
        super(MySQLdb, self).__init__(name, cursor, fields)

class oursql(Table):
    _param = '?'
    def __init__(self, name, cursor=None, fields=None, buffer_maxsize=4 * 1024*1024):
        super(oursql, self).__init__(name, cursor, fields)
        if fields is not None:
            # prepare stmt
            # pass
            self.buffer_maxsize = buffer_maxsize
            self.buffer = []
            self._flush_handlers = []
            self._insert_many_query = self._get_insert_many_query(fields)
        else:
            self.buffer = None

    def after_flush(do):
        self._flush_handlers.append(do)

    def insert(self, dic=None, fields=None, values=None, cursor=None):
        # if self.name in ['vc_group_allele', 'vc_genotype', 'vc_allele']:
        #     import pdb; pdb.set_trace()
        fields, values, cursor = self._get_insert_params(dic, fields, values, cursor)

        if self.buffer is not None:
            self.buffer.append(values)
            self._check_buffer()
        else:
            return self._do_insert(cursor, self._get_insert_many_query(fields), fields, values)

    def _check_buffer(self):
        if not self.buffer_maxsize or self._buffer_size() > self.buffer_maxsize:
            return self.flush_buffer()

    def flush_buffer(self):
        result = self._insert_many(values=self.buffer)
        self.buffer = []
        for handler in self._flush_handlers:
            handler(self)
        return result

    def _buffer_size(self):
        return sys.getsizeof(self.buffer)

    def _insert_many(self, dics=None, fields=None, values=None, cursor=None):
        insert_many_query = None
        if cursor is None:
            cursor = self._get_attr('cursor')
        if dics is not None:
            if fields is None:
                if self.fields is None:
                    fields = dics[0].keys()
                    insert_many_query = self._get_insert_many_query(fields)
                else:
                    fields = self.fields
                    insert_many_query = self._insert_many_query
            values = [[d[f] for f in fields] for d in dics]
        else:
            if fields is None:
                insert_many_query = self._insert_many_query
            else:
                insert_many_query = self._get_insert_many_query(fields)
        return self.cursor.executemany(insert_many_query, values)

    def insert_many(self, dics=None, fields=None, values=None, cursor=None):
        if self.buffer is not None:
            self.buffer.extend(values)
            return self._check_buffer()
        else:
            return self._insert_many(dics, fields, values, cursor)
