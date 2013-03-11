#!/usr/bin/env jython.py 
from java.lang import *
from java.lang import *
from java.sql import *
from org.apache.hive.jdbc import HiveDataSource, HiveDriver
from java.util import Properties

# "with" statement is not implemented in jython 2.2.1
# class HiveConnection:
#     def __enter__(self, url):
#         self.url = url
#         self.driver = HiveDriver()
#         self.connection = self.driver.connect("jdbc:hive2://master:10000", Properties())
#         return self.connection
# 
#     def __exit__(self, type, value, traceback):
#         self.connection.close()

def connect(url):
    url = url
    driver = HiveDriver()
    connection = driver.connect("jdbc:hive2://master:10000", Properties())
    return connection

def main():
    # with HiveConnection("jdbc:hive2://master:10000") as conn:
    #     print conn

    # driverName = "org.apache.hadoop.hive.jdbc.HiveDriver";
    # driverName = "org.apache.hive.jdbc.HiveDriver";

    conn = connect("jdbc:hive2://master:10000")

    # ds = HiveDataSource()
    # ds.setServerName("master")
    # ds.setPortNumber(10000)
    # conn = ds.getConnection()

    # com.dbaccess.BasicDataSource ds = new com.dbaccess.BasicDataSource();
    # ds.setServerName("grinder");
    # ds.setDatabaseName("CUSTOMER_ACCOUNTS");
    # ds.setDescription("Customer accounts database for billing");

    # try:
    #     Class.forName(driverName);
    # except Exception, e:
    #     print "Unable to load %s" % driverName
    #     raise
    #     System.exit(1);

    # DriverManager.registerDriver(org.apache.hive.jdbc.HiveDriver)

    # conn = DriverManager.getConnection("jdbc:hive2://master:10000");
    stmt = conn.createStatement();

    # Drop table
    #stmt.executeQuery("DROP TABLE testjython")

    # Create a table
    # res = stmt.executeQuery("CREATE TABLE testjython (key int, value string) ROW FORMAT DELIMITED FIELDS TERMINATED BY ':'")

    # Show tables
    res = stmt.executeQuery("SHOW TABLES")
    print "List of tables:"
    while res.next():
        print res.getString(1)

    conn.close()

if __name__ == '__main__':
    main()
