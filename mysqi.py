# -*- coding: utf-8 -*-
import MySQLdb as mdb
import sys
from greed import greed

class kcon():
    
    def setUp(self):
        self.db = mdb.connect('127.0.0.1', 'root', '', 'greed')
        self.cs= self.db.cursor()

    def getTask(self):
        self.cs.execute("SELECT * from task")
        result = self.cs.fetchone()
        print "answer: %s" % str(result)
    
    def getUser(self):
        self.cs.execute("SELECT * from user")
        result = self.cs.fetchone()    
        print "answer: %s" % str(result)
        self.user=result[0]
        self.cur=result[1]
        print " running: %s  %s" % (self.user,self.cur)
        return result
        
if __name__ == "__main__":
    k=kcon()
    k.setUp()
    se=k.getUser()
    g=greed()
    g.setUp(se)
#   g.login()
#    g.onego()
    
#