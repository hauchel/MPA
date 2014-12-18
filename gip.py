# -*- coding: utf-8 -*-
from gdb import gdb
import time
import sys
import urllib2

 
def getIp():
    f = urllib2.urlopen('http://wtfismyip.com/').read()
    x=f.split("Your fucking IP address is:</h2></center><center><p>")
    x=x[1].split("</center>",1)
    return x[0]
    
if __name__ == "__main__":
    db=gdb()
    ip=getIp()
    print "my IP >"+ip+"<"
    result = db.existIp(ip)
    print result
    if len(sys.argv)>1:
        ich=sys.argv[1]
    else:
        ich ="not set"
    zeit=time.strftime("%Y %b %d  %H:%M:%S", time.localtime())
    if result==None:
        db.insertIp(ip,ich,zeit)
        print "inserted with "+zeit
        db.setUserOn(ich)
        
    else:
        print "<----------------------"
   
    
#