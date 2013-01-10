class Table:
    def __init__(self, name, cursor=None, fields=None):
        self.name = name
        self.cursor = cursor 
        self.fields = fields

    # insert(cursor, table, dict={ 'x':1, 'y':2 })
    # insert(cursor, table, fields={..}, values={..})
    def insert(self, fields=None, values=None, dic=None, cursor=None):
        """Insert data into this table"""
        if cursor is None:
            cursor = self._get_attr('cursor')
        if fields is None and dic is None:
            field = self._get_attr('fields')
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
        sql_params = ', '.join(['%s']*len(fields))
        return cursor.execute("""insert into {table} ({fields}) values ({values})""".format(table=self.name, fields=', '.join(fields), values=sql_params), values)

    def _get_attr(self, attr):
        value = getattr(self, attr)
        if value is None:
            raise RuntimeError("Need {attr} for inserting into {name}".format(attr=attr, name=self.name))
        return value 

