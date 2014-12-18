# -*- coding: utf-8 -*-
import MySQLdb as mdb
import sys
import requests
import codecs
import re
import msvcrt
from warnings import filterwarnings
filterwarnings('ignore', category = mdb.Warning)

ll=""

class wdb():
    def __init__(self,proc):
        self.db = mdb.connect('127.0.0.1', 'root', '', 'word',use_unicode=True)
        self.cs = self.db.cursor()
        self.db.set_character_set('utf8')
        #self.cs.execute('SET NAMES utf8;') 
        #self.cs.execute('SET CHARACTER SET utf8;')
        #self.cs.execute('SET character_set_connection=utf8;')
        #self.db.commit()
        self.wordFile = 'C:/greed/word'+proc+'.txt'
        self.linkFile = 'C:/greed/link'+proc+'.txt'
        self.links = {}
        self.rex = re.compile("[^A-Za-zäöüÄÖÜß]")
        
    def comm(self):
        self.db.commit()

    def loadWord(self):
        print "Loading Wordfile"
        tmp=k.cs.execute("load data infile '%s' ignore into table words CHARACTER SET 'utf8' LINES TERMINATED BY '\r\n'" %self.wordFile)        
        self.comm()

    def loadLink(self):
        print "Loading Linkfile"
        tmp=k.cs.execute("load data infile '%s' ignore into table links CHARACTER SET 'utf8'  LINES TERMINATED BY '\r\n'  " %self.linkFile)        
        self.comm()        
        
    def checkLink(self,s):
        if s[1] !='['     : return
        if len(s)<5       : return
        if s[2].isdigit() : return
        if s[2] in ('"')  : return
        t=s.find(":")
        if t>0: return
        te=s.find("]]")
        if te>0: 
            t=s.find("|")
            if t>0:
               te=t
            t=s.find("#")
            if t>0:
               te=t 
            self.addLink(s[2:te])
       
    def addLink(self,s):
        #print "NewLink:"+s+"<",
        if s not in self.links:
            self.links[s]='1'

        
    def appendWordFile(self, co):
        writ=0
        for c in co:
            try:
                if c[0] in('['):
                    self.checkLink(c)
                    continue
                if c[0] in('('):            
                    c=c[1:]
                if c[-1] in('.',',',':',')',']',';'):
                    c=c[:-1]
                if self.rex.search(c):
                #print "rex "+c
                    continue
                self.wofo.write(str(c)+"\n")
                writ+=1
            except Exception as inst:
                print "Exception Word: "+str(type(inst)) + " for "+ str(c)
        print "Word  %d all, written %d " %(len(co),writ)

    def writeLinkFile(self):
        fo = open(self.linkFile, "w")
        writ=0
        for c in self.links:
            fo.write(str(c)+"\n")
            writ+=1
        fo.close()
        print "Links written %d to %s" %(writ,self.linkFile)
        self.links = {}        

    def doOne(self,lnk):
        global ll
        ll=codecs.encode(lnk,'utf-8')
        print ll
        r=requests.get('http://de.wikipedia.org/wiki/Spezial:Exportieren/'+ll)
        c=r.content.split()
        self.appendWordFile(c)
    
    def prep(self):
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
        try:
            print "%d for %s ->" %(idi,lnk),
            self.db.commit()
            self.doOne(lnk)
            tmp=self.cs.execute(s1+"x"+s2)
            self.db.commit()    
        except Exception as inst:
            print "Exception info: "+str(type(inst))
            tmp=self.cs.execute(s1+"E"+s2)
            self.db.commit()
        return 1
        #tmp=raw_input("weiter")
    
    def doiter(self,num):
        self.wofo = open(self.wordFile, "w")        
        stop=False
        while num>0:
            if self.prep() == 0: num=0         
            if msvcrt.kbhit():
                stop=True
                num=0
            num-=1
        self.wofo.close()        
        self.writeLinkFile()
        self.loadWord()
        self.loadLink()
        return(stop)

if __name__ == "__main__":
    if len(sys.argv)>1:
        proc=sys.argv[1]
    else:
        proc='A'
    k=wdb(proc)
    while not k.doiter(50):
        print "Press Key to tstop" 
    print "Hit was"+msvcrt.getch()        
    
 