# -*- coding: utf-8 -*-
import MySQLdb as mdb
import sys
import requests
import codecs
import re
import msvcrt
import HTMLParser
from warnings import filterwarnings
filterwarnings('ignore', category = mdb.Warning)


class MyParse(HTMLParser.HTMLParser):

    def __init__(self):   
        HTMLParser.HTMLParser.__init__(self)
        self.eval=False
        self.links={}
        self.rechts={}

    def reset(self):
        HTMLParser.HTMLParser.reset(self)
        self.links={}
        self.rechts={}
        print "---------- RESET "
        
    def handle_starttag(self, tag, attrs):
#        print "Starttag >"+tag+"<",
        for a in attrs:
            if a[0] == 'href':
                 if self.eval:
                     t=a[1].find('/rechtschreibung/')
                     if t<0:
                         self.links[a[1]]='1'
                         print "href "+a[1]
                     else:
                         w=a[1].split('/rechtschreibung/')
                         w=w[1]
                         self.rechts[w]='1'
                         #print "word "+w
            elif a[0] == 'class':
                if a[1] =='atoz first':
                    print "---------- START "+ str(a)
                    self.eval=True
                if self.eval:                         
                    print 'class >'+a[1]+"<"
                    if a[1]=='panel-pane atoz-mostread':
                        print "---------- STOP "+ str(a)
                        self.eval=False
 #           print str(a),        

    def mylinks(self):
        return self.links

    def myrechts(self):
        return self.rechts
        
class duden():
    def __init__(self,proc):
        self.db = mdb.connect('127.0.0.1', 'root', '', 'duden',use_unicode=True)
        self.cs = self.db.cursor()
        self.db.set_character_set('utf8')
        self.parser = MyParse() 
        self.linkFile = 'C:/greed/link'+proc+'.txt'
        self.wordFile = 'C:/greed/word'+proc+'.txt'
        
    def comm(self):
        self.db.commit()

    def loadLink(self):
        print "Loading Linkfile"
        tmp=self.cs.execute("load data infile '%s' ignore into table links CHARACTER SET 'utf8'  LINES TERMINATED BY '\r\n'  " %self.linkFile)        
        self.comm()    
        
    def loadWord(self):
        print "Loading Wordfile"
        tmp=self.cs.execute("load data infile '%s' ignore into table words CHARACTER SET 'utf8'  LINES TERMINATED BY '\r\n'  " %self.wordFile)        
        self.comm()  

    def writeLinkFile(self):
        fo = open(self.linkFile, "w")
        writ=0
        for c in self.parser.mylinks():
            fo.write(str(c)+"\n")
            writ+=1
        fo.close()
        print "Links written %d to %s" %(writ,self.linkFile)

    def writeWordFile(self):
        fo = open(self.wordFile, "w")
        writ=0
        for c in self.parser.myrechts():
            fo.write(str(c)+"\n")
            writ+=1
        fo.close()
        print "words written %d to %s" %(writ,self.wordFile)
        
    def doOne(self):
        s1="update links set proc = '"
        tmp=self.cs.execute("LOCK TABLES links WRITE")
        tmp=self.cs.execute("select idlink,link from links where proc='t' limit 1")
        if tmp==0:
            tmp=self.cs.execute("select idlink,link from links where proc='' limit 1")
        if tmp==0:
            print "Nothing Found"
            tmp=self.cs.execute("UNLOCK TABLES")
            return 0
        (idi,lnk)=self.cs.fetchone()
        s2="' where idlink="+str(idi)
        tmp=self.cs.execute(s1+"p"+s2)
        tmp=self.cs.execute("UNLOCK TABLES")
        lnk='http://www.duden.de'+lnk
        print "Processing "+lnk
        r=requests.get(lnk)
        self.parser.feed(r.content)
        self.parser.close()
        tmp=self.cs.execute(s1+"x"+s2)
        
    def doiter(self,num):
        #self.wofo = open(self.wordFile, "w")        
        stop=False
        while num>0:
            self.doOne()
            if msvcrt.kbhit():
                stop=True
                num=0
            num-=1
        self.writeLinkFile()
        self.writeWordFile()
        self.loadLink()
        self.loadWord()
        self.parser.reset()
        return(stop)

if __name__ == "__main__":
    if len(sys.argv)>1:
        proc=sys.argv[1]
    else:
        proc='A'
    d=duden(proc)
#    d.doOne()
    while not d.doiter(50):
        print "Press Key to tstop" 
    print "Hit was"+msvcrt.getch()     
    
   
 