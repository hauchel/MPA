# -*- coding: utf-8 -*-
import MySQLdb as mdb
import time

class gdb():
    
    def __init__(self):
        self.db = mdb.connect('127.0.0.1', 'root', '', 'greed')
        self.cs= self.db.cursor()
        self.cst= self.db.cursor() # task needs seperate
        self.verbose=False
       # self.verbose=True
        
    def zeit(self):
        return time.strftime("'%Y %b %d  %H:%M:%S'", time.localtime())
        
    def say(self,s):
        if self.verbose:
            print str(s)

    def fetch1(self,query):
        self.say ("Fetch1: "+query)     
        self.cs.execute(query)
        result = self.cs.fetchone()
        self.say ("answer: %s" % str(result))
        self.db.commit()
        return result

    def fetch99(self,query):
        self.say ("Fetch99: "+query)     
        self.cs.execute(query)
        result = self.cs.fetchall()
        self.say ("answer: %s" % str(result))
        self.db.commit()
        return result

    def execc(self,query):
        self.say ("execc: "+query)     
        self.cs.execute(query)
        self.db.commit()

    def existIp(self,ip):
        return self.fetch1("SELECT * from ip where ip='"+ip+"'")
            
    def insertIp(self,ip,user,zeit):
        self.execc("insert into ip values ('"+ip+"','"+user+"','"+zeit+"');")
        
    def getUserOn(self):
        tmp= self.fetch1("SELECT user from userOn")
        return tmp[0]

    def getUserData(self,user):
        return self.fetch1("SELECT * from users where user='%s'" %user)        
  
    def getWanted(self,ex):
        tmp=self.fetch99("SELECT cur from wanted order by prio")
        w=[]
        for t in tmp:
            ts=str(t[0])
            if ts != ex:
                w.append(ts)
        return w
  
    def doneTask(self,id):
        self.execc("update task set done="+self.zeit()+" where id="+str(id))
 
    def setUserOn(self,user):
        self.execc("Delete from useron")
        zeit=time.strftime("%Y %b %d  %H:%M:%S", time.localtime())
        self.execc("INSERT INTO useron values ('%s','%s')" %(user,zeit) )

        
    def setPlayers(self,plis):
        tmp="INSERT IGNORE INTO players (name) VALUES "
        for t in plis: 
            tmp=tmp+"('"+t+"'),"
        tmp=tmp[:-1]
        self.execc(tmp)
                    
    def setHave(self,user,have):
        self.execc("Delete from have where user='"+user+"'")
        tmp = "insert into have values "
        t1="('"+user+"','"
        for h in have:
            tmp=tmp+t1+str(h)+"',"+str(have[h])+"),"
        tmp=tmp[:-1]
        self.execc(tmp)  
    
    def getPlayersCur(self,plis):
        r=[]
        for t in plis: 
            tmp=self.fetch1("select cur from players where name='%s'" %t)
            if tmp==None:
                print "Player not known for "+t
                continue
            if tmp[0]==None:
                print "Currency not known for "+t
                continue
            if tmp[0] not in r:
                r.append(tmp[0])
        return r
    
    def testUp(self,user):
        se=self.getUserData(user)
        self.myuser=se[0]
        self.mypasswd=se[1]
        self.mycu=se[2]       
        self.mytyp=se[3]    
        self.ordqty=se[4] 
        self.needqty=se[5]
        self.excqty=se[6]        

if __name__ == "__main__":
    k=gdb()  

    if 1:
        print k.getPlayersCur([u'greed', u'capelca', u'Bleech', u'R2D2', u'Reb Rote'])
    if 0:
        usr=k.getUserOn()
        k.testUp(usr)
    if 0:
        k.setUserOn('xxx')
        
    #tmp=k.getUserData(usr)
    #t=k.getWanted('EC')