import time
import random
import msvcrt
import sys
from selenium import webdriver
from gdb import gdb
class greed():
 
    def __init__(self):
        self.db=gdb()        
        self.driver = webdriver.Chrome('C:/greed/chromedriver.exe')
        self.driver.implicitly_wait(5)
        self.base_url = "http://www.greedgame.com/"
        self.order=[]       # my orders
        self.have={}        # set in worldbank, 0s added during makeneed
        self.low=True
        self.offered=[]     # offered by others
        self.valua=[]       # those cu not having a player assigned
        self.dont=[]        # do not order in val
        self.need={}        # qty needed
        self.want=[]        # 
        self.bought=[]      # key to bought to avoid errors
        self.phase="n"      # see desc
        
    def printSetUp(self):
        print "%s %s ty=%s ord=%d need=%d exc=%d oth=%d act=%d odl=%d rem=%d" %(self.myuser,self.mycu,\
            self.mytyp,self.ordqty,self.needqty,self.excqty,self.othqty,self.action,self.orddelt,self.remo)
        
    def setUp(self,user):
        se=self.db.getUserData(user)
        self.myuser=se[0]
        self.mypasswd=se[1]
        self.mycu=se[2]       
        self.mytyp=se[3]    # 
        self.ordqty=   se[4]   # max order qty
        self.needqty=  se[5]   #
        self.excqty=   se[6]   # worldbank if below
        self.othqty=   se[7]   # order if below from other players     
        self.action=   se[8]   # loop      
        self.delay=    se[9]   # wait after order
        self.orddelt= se[10]   # Delta for accepting orders if not low
        self.remo=    se[11]   # p(removing)
        self.printSetUp()
        self.want=self.db.getWanted(self.mycu)
        self.valua=self.db.getValua()
        self.dont=self.db.getDont()
        self.printSetUp()
       
    def sleepOrKey(self,sec):
        print "\b\b>",
        for cnt in range(0,sec):
            if msvcrt.kbhit():
                return msvcrt.getch()
            time.sleep(1)
        return ""
        
    def evalPlayer(self,x):
        "returns all player "
        x=x.find_elements_by_class_name("player")
        r=[]
        for z in x:
            r.append(z.text)
        return r
        
    def getPlayersAll(self):
        d = self.driver
        d.get(self.base_url+"stats") 
        x=d.find_element_by_class_name("row")
        x=x.find_element_by_xpath("//tbody")
        return self.evalPlayer(x)

    def getPlayersOn(self):
        " list of players online"
        d = self.driver
        d.get(self.base_url+"stats") 
        x=d.find_element_by_xpath("/html/body/div/div[3]/div/div[2]/table/tbody/tr[5]/td/ul")
        return self.evalPlayer(x)

    def getCursOn(self):
        "list of currencies online"   
        plr = self.getPlayersOn()
        tmp=self.db.getPlayersCur(plr)
        return tmp

    def worldbank(self):
        d = self.driver
        d.get(self.base_url+"worldbank") 
        self.have={}
        print "Worldbank: ",
        x=d.find_elements_by_xpath("//tr")
        for z in range(1,len(x)): 
            id= x[z].get_attribute("id")
            if id[:6]=="invest":
                q=x[z].find_elements_by_xpath("td")
                cu=id[-2:]
                print q[3].text+" "+cu+", ", 
                self.have[cu]=int(q[3].text)
        print        
 
    def xchange(self):
        "returns 1 if not succ, sets low"
        d = self.driver
        d.get(self.base_url+"worldbank")   
        x=d.find_element_by_id('invest-first-10')
        x.click()
        time.sleep(2)
        x=d.find_element_by_id('invest-to-select')
        ret = x.text[-10:]
        print "ret >%s<"%ret
        if ret=="more coins":
            self.low=True
            return 1
        if ret==" more coin":
            self.low=True
            return 1            
        bu=d.find_element_by_xpath('/html/body/div/div[3]/div[2]/div[1]/form/button')
        bu.click()       
        print "Clicked"
        self.sleepOrKey(2)
        self.low=False
        return 0
        
    def logout(self):
        d = self.driver
        d.get(self.base_url+"logout")  
        
    def login(self):
        d = self.driver
        #d.get("http://www.whatsmyip.de/")
        #x=d.find_element_by_id("content")
        #x=x.find_element_by_tag_name("h3")
        d.get(self.base_url)
        d.find_element_by_link_text("Click here to log in").click()
        d.find_element_by_name("username").send_keys(self.myuser)
        d.find_element_by_name("password").send_keys(self.mypasswd)
        d.find_element_by_css_selector("fieldset > button.btn").click()
        print "Login using %s %s"%(self.myuser,self.mypasswd)
        self.sleepOrKey(2)
        
    def addoffered(self,cu):
        if cu not in self.offered: 
            self.offered.append(cu)  
        
    def makeneed(self):
        " those offered minus having"
        self.need={}
        random.shuffle(self.offered)
        for cu in self.offered:
            try:
                tmp = self.needqty-self.have[cu]  
            except Exception as inst:
                self.have[cu]=0
                tmp=self.needqty
            if tmp<0:
                tmp=0
            self.need[cu]=tmp

    def value(self):
        self.need={}
        for cu in self.offered:
            try:
                tmp = self.needqty-self.have[cu]  
            except Exception as inst:
                self.have[cu]=0
                tmp=self.needqty
            if tmp<0:
                tmp=0
            self.need[cu]=tmp      
            
    def finalize(self):
        self.need={}
        for cu in self.want:
            try:
                tmp = self.needqty-self.have[cu]  
            except Exception as inst:
                self.have[cu]=0
                tmp=self.needqty
            if tmp<0:
                tmp=0
            else:
                tmp=(tmp/5)*5+5
            self.need[cu]=tmp
        print("Final "+str(self.need))  
        cnt=6
        for cu in sorted(self.need, key=self.need.__getitem__,reverse=True):          
            qty=self.need[cu]
            print "%s for %4d"%(cu,qty)
            self.neworderOwn(qty,cu)
            cnt-=1
            if cnt<1:
                return
                
    def checkbuy(self):
        try:
            suc=self.driver.find_elements_by_class_name("success")
        except Exception as inst:
            print "checkbuy exc: "+str(inst.args)
            suc=[]
            return 0
        for r in suc:       
            y=r.find_elements_by_tag_name("li")
            tmp=y[0].text.split()
            getqty=int(tmp[0])
            tmp=y[1].text.split()
            givqty=int(tmp[0])
            getcu=y[0].get_attribute("data-coin")
            self.addoffered(getcu)
            givcu=y[1].get_attribute("data-coin")
            if getcu in self.have:
                gethav= self.have[getcu]
            else:
                gethav=0;
            if givcu in self.have:
                pass
            else:
                self.have[givcu]=0;                
            givhav=self.have[givcu]
            print "canbuy %2d %s (%2d) give %2d %s (%2d) "\
            %(getqty,getcu,gethav,givqty,givcu,givhav),
            if getqty != givqty:
                print "qty mismatch"
                continue
            if givcu==self.mycu:
                dlt=0
            else:
                if gethav==0:
                    dlt=0
                else:
                    dlt=self.orddelt
            getnew=gethav+getqty
            givnew=givhav-givqty    
            diff= givnew - getnew -dlt           
            print "->  %2d  vs %2d D%3d" %(getnew,givnew,diff),
            if givcu in self.valua:
                print "valu ",
                if gethav !=0:
                    print "da"
                    continue
            bou=getcu+givcu+str(getqty)+str(givqty)
            if bou in self.bought:
                print "key already bought "+bou
                continue
            if self.low:
                if gethav > 1:
                    print " Low have"
                    continue
                if getnew > 3:
                    print " Low new"
                    continue
            if givnew > getnew+dlt:
                    bu=r.find_element_by_link_text("buy")
                    bu.click()
                    print "buy key %s "%(bou)
                    # print "buy key %s givnew %d %s getnew %d %s "%(bou,givnew,givcu,getnew,getcu)
                    self.have[givcu]=givnew
                    self.have[getcu]=getnew
                    self.bought.append(bou)
                    time.sleep(1)
                    return getqty
            print
        return 0
            
    def checkother(self):
        try:
            err=self.driver.find_elements_by_class_name("error")
        except Exception as inst:
            print "checkother err: "+str(inst.args)
            err=[]
        try:
            suc=self.driver.find_elements_by_class_name("success")
        except Exception as inst:
            print "checkother suc: "+str(inst.args)
            suc=[]
        suc.extend(err)            
        for r in suc:       
            y=r.find_elements_by_tag_name("li")
            tmp=y[0].text.split()
            getqty=int(tmp[0])
            tmp=y[1].text.split()
            givqty=int(tmp[0])
            getcu=y[0].get_attribute("data-coin")
            self.addoffered(getcu)
            givcu=y[1].get_attribute("data-coin")  
            #print "checkother "+str(getqty)+" "+getcu+" give "+givcu +" "+str(givqty)
        self.makeneed()                
    
    def getMyOrders(self):
        self.driver.get(self.base_url+"tradingplace")
        self.order=[]
        try:
            rem=self.driver.find_elements_by_class_name("info")
        except Exception as inst:
            print "getMyOrders info: "+str(inst.args)
            rem=[]
        print "getmyO: ",
        for r in rem:       
            y=r.find_elements_by_tag_name("li")
            #my=y[0].get_attribute("data-coin")
            cu=y[1].get_attribute("data-coin")
            print cu+" ", 
            self.order.append(cu)
        tmp=len(self.order)
        print "  tot "+str(tmp)
        return tmp
        
    def trading(self):
        self.getMyOrders()
        self.checkother()
        return self.checkbuy()
                    
    def neworder(self,qty,givcu,getcu):
        d = self.driver
        d.get(self.base_url+"newoffer")
        x=d.find_element_by_name('M['+givcu+']')
        x.clear()
        sl=random.randint(8,self.delay)
        print "neworder %d %s %s   sleep %d"%(qty,givcu,getcu,sl)
        if self.low:
            if qty>2: qty=2
        tmp=str(qty)
        x.send_keys(tmp)
        x=d.find_element_by_name("Y["+getcu+"]")
        x.clear()
        x.send_keys(tmp)
        d.find_element_by_xpath("//button[@type='submit']").click()
        self.sleepOrKey(sl)
    
    def neworderOwn(self,qty,cu):
        self.neworder(qty,self.mycu,cu)
            
    def removelastorder(self):
        self.driver.get(self.base_url+"tradingplace")
        try:
            rem=self.driver.find_elements_by_link_text('remove')
        except Exception as inst:
            print "No Orders to remove: "+str(inst.args)
            return 0
        print "remove last, found %d "%len(rem)
        l=len(rem)
        if l== 0: return 0
        rem[l-1].click()
        self.sleepOrKey(3)
        self.getMyOrders()
        return l-1
    
    def removeall(self):
        self.trading()
        while self.removelastorder()!=0:
            print "removed"
    
    def offqty(self,have,need):
        if have <3:
            t= 2
        elif have <8:
            t= 4
        elif have <18:
            t= 5         
        else:
            t=self.ordqty
        if self.low:
            if have>0:
                print "Am Low and Have"
                t=0
            else:
                t=2
        if t>self.ordqty:
            t=self.ordqty
        
        return t
            
    def addemO(self):
        "order for players Online, return number of orders in book"
        mynam="addemO "
        nord=self.getMyOrders()
        curs=(self.getCursOn()) 
        for cu in curs:
            if nord >4: 
                break
            if cu==self.mycu:
                continue
            if cu in self.order:
                print mynam+"%s already ordered "%cu
                continue
            if cu not in self.want:
                print mynam+"%s not wanted "%cu
                continue
            if cu in self.have:
                hav=self.have[cu]
            else:
                hav=0
            print mynam+"%s have %3d"  %(cu,hav),
            qty=self.othqty - hav
            if qty <0:
                print "more than needed "+str(self.othqty)
                continue
            qty=self.offqty(hav,qty)
            if qty>0:
                self.neworderOwn(qty,cu) 
                nord+=1           
        print mynam+"terminated with %d" %nord
        return nord
        
    def addem1(self):
        "order those in self.wanted"
        mynam="addem1 "
        if self.phase=="h":
            print mynam+"skipped for phase >"+self.phase+"<"
            return
        nord=self.getMyOrders()
        print mynam+"need "+str(self.need)
        for cu in sorted(self.need, key=self.need.__getitem__,reverse=True):
            if nord >4:
                break
            if cu in self.order:
                print mynam+"%s already ordered "%cu
                continue
            if cu not in self.want:
                print mynam+"%s not wanted "%cu
                continue
            if cu in self.have:
                hav=self.have[cu]
            else:
                hav=0
            qty=self.othqty - hav
            if qty <0:
                print mynam+"%s more than needed "%cu+str(self.othqty)
                continue
            qty=self.offqty(hav,self.need[cu])
            if qty==0:
                print mynam+"%s qty is zero "%cu
                continue
            self.neworderOwn(qty,cu) 
            nord+=1
        print mynam+"terminated with %d" %nord
        return nord
        
    def addemTop(self):
        "order from top list, return number of orders in book"
        mynam="addemTop "
        nord=self.getMyOrders()
        cus=(self.db.getTop())   
        print "addemTop Entering"
        for cu in cus:
            if nord >4: 
                break
            if cu==self.mycu:
                continue
            if cu in self.order:
                print "addemO already ordered "+cu
                continue
            
            self.neworderOwn(self.ordqty,cu) 
            self.db.delTop(cu)
            nord+=1           
        print "addemTop terminated with %d" %nord
        return nord
 
    def addemValua(self):
        "order valuables"
        mynam="addemV "
        wnt=[]
        giv=[]
        print mynam+"Entering"
        for cu in self.have:
            if self.have[cu]>3:
                if cu in self.valua:
                    print "my valuable: %s %d "%(cu,self.have[cu])
                    giv.append(cu)
                    
            else:
                if cu in self.order:
                    print "already ordered "+cu                    
                else:
                    if self.have[cu]==0:
                        if cu in self.dont:
                            print "not dont "+cu                    
                        else:
                            wnt.append(cu)
        print " can buy "+str(wnt)
        if len(giv)==0:
            return
        random.shuffle(wnt)
        random.shuffle(giv)
        
        nord=self.getMyOrders()            
        j=0
        for i in range (0,len(wnt)):
            if nord > 4 :
                break
            tcu=giv[j]   
            j+=1             
            if j>=len(giv):
                j=0
            self.neworder(1,tcu,wnt[i])
            nord+=1
        print mynam+"terminated with %d" %nord
        return nord
        
    def schluss(self):
        self.driver.quit()
        
    def setOrdqty(self,nums):
        try:
            num=int(nums)
        except Exception as inst:
            print str(inst.args)
            return    
        self.ordqty=num
        print "ordqty now "+str(num)

    def setNeedqty(self,nums):
        try:
            num=int(nums)
        except Exception as inst:
            print str(inst.args)
            return    
        self.needqty=num
        print "needqty now "+str(num)        

    def wobex(self):
        self.worldbank()
        if self.mycu in self.have:
            my=self.have[self.mycu]
        else:
            my=0
            print "No more own coins!"  
        time.sleep(1)   
        if my<self.excqty:
            tmp=self.xchange()
            print "wobex xchange returned "+str(tmp)
            if tmp ==0:
                self.worldbank()
                my=self.have[self.mycu]
                print "after woba2 "+str(my)+" "+self.mycu        
        else:
            self.low=False
    
    def checkremove(self):
        self.getMyOrders()
        if len(self.order)==5:
            ra=random.randint(1,10)
            re=self.remo
            print "checkremove %d p %d"%(ra,re)            
            if ra>re:
                self.removelastorder() 
        else:
            print "checkremove nix"

    def match(self):
        "match all avail orders"
        tmp=1
        cnt=6
        self.wobex()
        while tmp>0:
            cnt-=1
            tmp=self.trading()
            print str(cnt)+" trading returned "+str(tmp)
            if tmp>0: 
                self.wobex()
            if cnt<1: 
                tmp=0
    
    def onegoTop(self):
        self.getMyOrders()
        self.addemTop()
        
    def onegoNor(self):
        self.bought=[]
        self.checkremove()
        mynam="onegNor "
        print mynam+"starting"
        self.match()
        oib=self.getMyOrders()                
        if oib<5:
            self.addemO()
            oib=self.getMyOrders()                               
        if oib<5:       
            if self.mytyp!="I":
                self.addemValua()
                oib=self.getMyOrders() 
        if oib<5:            
            self.addem1()
    
    def onegoVal(self):
        self.bought=[]
        self.checkremove()
        mynam="onegVal "
        print mynam+"starting"
        self.checkremove()
        self.match()
        self.addemValua()
                    
    def onego(self):
        #  phase                  add0   add1  val   upd
        #    auction                                 yes
        #    high  =no waiting  
        #    intraday             
        #    normal
        #  typ
        #    I  no                             No
        try:
            self.wobex()
            self.bought=[]
            if self.mytyp=="T":
                self.onegoTop()   
            elif self.mytyp=="V":
                self.onegoVal()   
            elif self.mytyp=="N":
                self.onegoNor()
            elif self.mytyp=="I":     #intraday
                self.onegoNor()            
            else:
                print "Please set typ T/V/N"
            self.db.setHave(self.myuser,self.have)
            self.trading()
        except Exception as inst:
            print "onego exc: "+str(inst.args)
  
    def doUpOne(self,pl2):
        pl1=self.myuser
        self.db.createSummary()
        t1=self.db.getGivTo(pl1,pl2)
        print pl1+ " gives to " + pl2+ "  "+str(t1)
        t2=self.db.getGivTo(pl2,pl1)
        print pl2+ " gives to " + pl1+ "  "+str(t2)
        num=min(len(t1),len(t2))
        for cnt in range(0,num):
            print "duUp %s %s "%(t1[cnt],t2[cnt])
            self.neworder(1,t1[cnt],t2[cnt])
    
    def doUp(self):
        t=self.getPlayersOn()
        for cnt in range(0,len(t)):
             if t[cnt]==self.myuser:
                 continue
             t1=self.db.getUsersCur(t[cnt])
             if t1==None:
                  continue
             print "try %s"%t[cnt]
             self.doUpOne(t[cnt])
            
            
    def gettask(self):
            for (tid,cmd) in self.db.cst:
                print "Doit: "+str(cmd)+" tid="+str(tid)
                if cmd== "stop":
                    self.db.doneTask(cmd[0])
                    return 1
                elif cmd=="one":
                    self.onego()
                    acnt=0
                elif cmd=="remove":
                    self.removeall()
                    acnt=9999       
                elif cmd[:3]=="oqt":
                    self.setOrdqty(cmd[4:])    
                elif cmd[:3]=="nqt":
                    self.setNeedqty(cmd[4:])                            
                elif cmd=="want":
                    self.want=self.db.getWanted(self.mycu)
                    acnt=9999    
                else:
                    print "unknown"
                self.db.doneTask(tid)                                  
        
    def doit(self):
        acnt=20
        if self.low:
            tmpL="Lo"
        else:
            tmpL="  "
        print "%s %s %s need=%d ord=%d "%(self.myuser,self.db.zeit(),tmpL,self.needqty,self.ordqty)
        while 1:
            self.db.db.commit()
            if acnt>0:
                for cnt in range(0,10):
                    time.sleep(1)
                    if msvcrt.kbhit():
                        break
            acnt-=1
            print "\b\b\b\b%3d"%acnt,
            if acnt<1:
                self.onego()
                self.phase=self.db.getPhase()
                print self.myuser+" phase >"+self.phase+"< ",
                if self.phase=="h":
                    print "HIGH ACT"
                    acnt=5
                else:
                    acnt=self.action
            if msvcrt.kbhit():
                tmp= msvcrt.getch()      
                print tmp+"\n"
                self.printSetUp()
                if tmp=="a":
                    print str(self.getPlayersOn())
                if tmp=="c":
                    print str(self.getCursOn())
                if tmp=="d":
                   self.removeall()   
                if tmp=="f":
                   self.finalize()         
                if tmp=="h":
                    self.db.setHave(self.myuser,self.have)
                if tmp=="n":
                    self.onegoTop()
                if tmp=="o":
                    acnt=0
                if tmp=="p":
                    print "pause",
                    msvcrt.getch()    
                if tmp=="q":
                    self.db.setHave(self.myuser,self.have)
                    self.schluss()
                    sys.exit(0)                      
                if tmp=="r":
                    self.removelastorder()
                if tmp=="s":
                    self.setUp(self.myuser)
                if tmp=="t":
                    self.trading()
                if tmp=="u":
                    self.doUp()
                if tmp=="w":
                    self.want=self.db.getWanted(self.mycu)
                if tmp=="x":
                    self.wobex()
                if tmp=="y":
                    pli=self.getPlayersAll()
                    self.db.setPlayers(pli) 
                    print "Players extracted: %d"%len(pli)
                if tmp=="z":
                    self.db.createSummary()                    
                if tmp=="1":
                    self.addem1()
                if tmp=="2":
                    self.addemO()
                if tmp=="3":
                    self.addemValua()
                if tmp=="4":
                    self.addemTop()
                
                if tmp==" ":
                    print \
                    """ 
   Active players 
   Currencies on
   Delete all Orders
   Finalize
   set Have
   many orders
   One go
   Pause
   Quit
   Remove last order
   setup 
   trading
   doUp
   wanted refresh 
   x wobex
   y players upd
   zummary
   1 addem1
   2 addem Online
   3 addem Valua
   4 addem Top
   """
                print self.myuser+" ?/a/c/m/o/p/r/s/t/w/q>  ",                   
                
        
if __name__ == "__main__":
    g=greed()
    g.setUp(g.db.getUserOn())
    g.login()
    g.doit()
    
    
#
#
#
#    