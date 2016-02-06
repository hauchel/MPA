# -*- coding: utf-8 -*-
import MySQLdb as mdb
import time

class gdb():
    
    def __init__(self):
        self.db = mdb.connect('127.0.0.1', 'root', '', 'greed')
        self.cs= self.db.cursor()
        self.verbose=False
        #self.verbose=True
        
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
        tmp=self.cs.execute(query)
        self.db.commit()
        return tmp

    def getManyOne(self,query):
        "returns on col as list"
        tmp=self.fetch99(query)
        w=[]
        for t in tmp:
            ts=str(t[0])
            w.append(ts)
        return w

    def existIp(self,ip):
        return self.fetch1("SELECT * from ip where ip='"+ip+"'")
            
    def insertIp(self,ip,user,zeit):
        self.execc("insert into ip values ('"+ip+"','"+user+"','"+zeit+"');")
        
    def getUserOn(self):
        tmp= self.fetch1("SELECT user from userOn")
        return tmp[0]

    def getUserData(self,user):
        return self.fetch1("SELECT * from users where user='%s'" %user)        
  
    def getPhase(self):
        tmp=self.fetch1("SELECT level from phase")
        return tmp[0]
        
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
        self.execc("Delete from have where qty=0;")
        print "setHave done"
    
    def setTop(self,user,cur):
        self.execc("Delete from top")
        tmp="where user ='%s' and cur !='%s'" %(user,cur)
        self.execc("insert into top (cur) select cur from have "+tmp+" order by qty desc limit 9")
        
    def getTop(self):
        return self.getManyOne("select cur from top")
    
    def delTop(self,cu):
        self.execc("delete from top where cur='%s'"%cu)
        
    def getValua(self):
        plr= self.getManyOne("select distinct cur from players")
        print " Players: "+str(plr)
        val= self.getManyOne("select cur from coins") 
        for cu in plr:
            try:
                val.remove(cu)
            except ValueError:
                print "please check players currency "+str(cu)
        print  "Valuable: "+str(val)
        return val
        
    def getDont(self):
        val= self.getManyOne("select cur from notorder;") 
        print  "Do not: "+str(val)
        return val        
        
    def createSummary(self):
        self.execc("delete from summary;")
        self.execc("insert into summary (cur) select distinct cur from have;")
        tot = "update summary set total= "
        for user in self.getManyOne("select user from users"):
            tmp=" update summary, have set summary."+user+" = have.qty where have.user='"
            tmp+= user +"' and have.cur=summary.cur"
            tot+=user+"+"
            self.execc(tmp)
        tot=tot[:-1]
        self.execc(tot)
        self.execc("update summary,players set summary.player=players.name where summary.cur=players.cur")
        self.execc("update summary,coins set summary.curLong=coins.curLong where summary.cur=coins.cur")
        print "createSummary done"
        
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

    def getUsersCur(self,usr):
        tmp=self.fetch1("select cur from users where user='%s'" %usr)
        if tmp==None:
            print "User not known "+usr
            return None
        return tmp[0]
            
    def getGivTo(self,pl1,pl2):
        # returns all thos which pl1 could give to pl2
        que="select cur from summary where "+pl2+"=0 and "+pl1+" >1 order by "+pl1+" desc;"
        return self.getManyOne(que)
  
  
  
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
    pl1="R2D2"
    pl2="greed"
    if 0:
        t1=k.getUsersCur('greed')
        print " is "+str(t1)
    if 1:
        t1=k.getDont()
        print " is "+str(t1)
        

    if 0:
        print k.getPlayersCur([u'greed', u'capelca', u'Bleech', u'R2D2', u'Reb Rote'])
    if 0:
        usr=k.getUserOn()
        k.testUp(usr)
    if 0:
        k.setUserOn('xxx')
    if 0:
        k.setTop('R2D2','AR')
        print k.getTop()
    if 0:
        k.createSummary()        
    #tmp=k.getUserData(usr)
    #t=k.getWanted('EC')