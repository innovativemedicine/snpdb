#!/usr/bin/env python
import hive
import unittest
from StringIO import StringIO

def write_loadfile(data):
    stream = StringIO()
    hive.write_loadfile(data, stream=stream, close=False, sort=True)
    stream.seek(0)
    return stream.read()

class TestHive(unittest.TestCase):

    def setUp(self):
        self.test_complex_data = [
            (
                ('s1.name', 's1.age'),
                [('a1[0].x', 'a2[0].y'), ('a1[1].x', 'a2[1].y')],
                {   
                    'b1.key1':['b1.value1[0]', 'b1.value1[1]'],
                    'b1.key2':['b1.value2[0]', 'b1.value2[1]'],
                },
            ),
        ]
        self.test_complex_expect = "\x01".join([
            "s1.name\x02s1.age",  
            "a1[0].x\x03a2[0].y\x02a1[1].x\x03a2[1].y",
            "b1.key1\x03b1.value1[0]\x04b1.value1[1]\x02b1.key2\x03b1.value2[0]\x04b1.value2[1]",
        ]) + "\n"

        self.test_complex_2_rows_data = self.test_complex_data * 2
        self.test_complex_2_rows_expect = ''.join([self.test_complex_expect, self.test_complex_expect])

    # http://osdir.com/ml/hive-user-hadoop-apache/2010-03/msg00127.html
    # CREATE TABLE nested (   
    #     s1 STRUCT<name:STRING, age: INT>,
    #     a1 ARRAY<STRUCT<x:INT, y:INT>>,
    #     b1 MAP<STRING, ARRAY<INT>>
    # )
    def test_complex(self):
        got = write_loadfile(self.test_complex_data)
        self.assertEqual(got, self.test_complex_expect)

    def test_complex_2_rows(self):
        got = write_loadfile(self.test_complex_2_rows_data)
        self.assertEqual(got, self.test_complex_2_rows_expect)

if __name__ == '__main__':
    unittest.main()
