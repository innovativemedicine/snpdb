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

        result = cursor.execute(self._get_insert_many_query(fields), values)
        # not sure if this will work for tables without autoincrement...
        self.lastrowid = cursor.lastrowid
        return result

    def _get_attr(self, attr):
        value = getattr(self, attr)
        if value is None:
            raise RuntimeError("Need {attr} for inserting into {name}".format(attr=attr, name=self.name))
        return value 

    def _get_insert_many_query(self, fields):
        sql_params = ', '.join([self._param]*len(fields))
        return """insert into {table} ({fields}) values ({values})""".format(table=self.name, fields=', '.join(fields), values=sql_params)

class MySQLdb(Table):
    _param = '%s'
    def __init__(self, name, cursor=None, fields=None):
        super(MySQLdb, self).__init__(name, cursor, fields)

class oursql(Table):
    _param = '?'
    def __init__(self, name, cursor=None, fields=None):
        super(oursql, self).__init__(name, cursor, fields)
        if fields is not None:
            # prepare stmt
            # pass
            self._insert_many_query = self._get_insert_many_query(fields)

    # def insert(self, dic=None, fields=None, values=None, cursor=None):
    #     pass

    def insert_many(self, dics=None, fields=None, values=None, cursor=None):
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
