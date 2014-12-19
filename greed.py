import time
import random
import msvcrt
from selenium import webdriver
from gdb import gdb
class greed():
 
    def __init__(self):
        self.db=gdb()        
        self.driver = webdriver.Firefox()
        self.driver.implicitly_wait(3)
        self.base_url = "http://www.greedgame.com/"
        #self.verificationErrors = []
        #self.accept_next_alert = True
        self.order=[]
        self.have={}        # set in worldbank, 0 added during makeneed
        self.low=True
        self.offered=[]
        self.valua=[]       # those cu not having a player assigned
        self.need={}        # qty needed
        self.want=[]
        self.bought=[]      # key to bought to avoid 
        
    def printSetUp(self):
        print "%s %s ty=%s ord=%d need=%d exc=%d oth=%d act=%d" %(self.myuser,self.mycu,\
            self.mytyp,self.ordqty,self.needqty,self.excqty,self.othqty,self.action)
        
    def setUp(self,user):
        se=self.db.getUserData(user)
        self.myuser=se[0]
        self.mypasswd=se[1]
        self.mycu=se[2]       
        self.mytyp=se[3]    
        self.ordqty=se[4] 
        self.needqty=se[5]
        self.excqty=se[6]
        self.othqty=se[7]        
        self.action=se[8]        
        self.printSetUp()
        self.want=self.db.getWanted(self.mycu)
        self.valua=self.db.getValua()
       
    def evalPlayer(self,x):
        "returns all player "
        x=x.find_elements_by_class_name("player")
        print "eval: %s" %(len(x))
        r=[]
        for z in x:
            r.append(z.text)
        return r
        
    def playerAll(self):
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
        if ret=="more coins":
            self.low=True
            return 1
        bu=d.find_element_by_xpath('/html/body/div/div[3]/div[2]/div[1]/form/button')
        bu.click()       
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
        #print "Login using "+x.text
        d.get(self.base_url)
        d.find_element_by_link_text("Click here to log in").click()
        d.find_element_by_name("username").send_keys(self.myuser)
        d.find_element_by_name("password").send_keys(self.mypasswd)
        d.find_element_by_css_selector("fieldset > button.btn").click()
  
    def addoffered(self,cu):
        if cu not in self.offered: 
            self.offered.append(cu)  
        
    def makeneed(self):
        " those offered minus having"
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
            
    def checkbuy(self):
        try:
            suc=self.driver.find_elements_by_class_name("success")
        except Exception as inst:
            print "trading succ: "+str(inst.args)
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
                    dlt=5
            getnew=gethav+getqty
            givnew=givhav-givqty                
            print "->  %2d  vs %2d " %(getnew,givnew),
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
                    print "buy key "+bou
                    self.bought.append(bou)
                    bu.click()
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
        print "Ordered: ",
        for r in rem:       
            y=r.find_elements_by_tag_name("li")
            #my=y[0].get_attribute("data-coin")
            cu=y[1].get_attribute("data-coin")
            print cu+" ", 
            self.order.append(cu)
        print

        
    def trading(self):
        self.getMyOrders()
        self.checkother()
        return self.checkbuy()
                    
    def neworder(self,qty,givcu,getcu):
        d = self.driver
        d.get(self.base_url+"newoffer")
        x=d.find_element_by_name('M['+givcu+']')
        x.clear()
        print "neworder %d  %s %s" %(qty,givcu,getcu)
        if self.low:
            if qty>2: qty=2
        tmp=str(qty)
        x.send_keys(tmp)
        x=d.find_element_by_name("Y["+getcu+"]")
        x.clear()
        x.send_keys(tmp)
        d.find_element_by_xpath("//button[@type='submit']").click()
        time.sleep(random.randint(10,20))
    
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
            t= 6
        else:
            t=12
        if t>self.ordqty:
            t=self.ordqty
        return t
            
    def addemO(self):
        "order by players Online, return number of orders in book"
        nord=len(self.order)
        curs=(self.getCursOn())    
        for cu in curs:
            if nord >4: 
                return nord 
            if cu==self.mycu:
                continue
            if cu in self.order:
                print "addemO %s already ordered "%cu
                continue
            if cu not in self.want:
                print "addemO %s not wanted "%cu
                continue
            if cu in self.have:
                hav=self.have[cu]
            else:
                hav=0
            print "addemO %s have %3d"  %(cu,hav),
            qty=self.othqty - hav
            if qty <0:
                print "more than needed "+str(self.othqty)
                continue
            qty=self.offqty(hav,qty)
            self.neworderOwn(qty,cu) 
            nord+=1           
        print "addemO terminated with %d" %nord
        return nord
        
    def addem1(self):
        "order strategy by prio"
        nord=len(self.order)
        print "addem "+str(self.need)
        for cu in sorted(self.need, key=self.need.__getitem__,reverse=True):
            if nord >4: return 
            if cu in self.order:
                print "addem1 %s already ordered "%cu
                continue
            if cu not in self.want:
                print "addem1 %s not wanted "%cu
                continue
            if cu in self.have:
                hav=self.have[cu]
            else:
                hav=0
            qty=self.offqty(hav,self.need[cu])
            if self.low:
                qty=2
                if hav >0:
                    print "addem1 %s low have"%cu
                    continue
            self.neworderOwn(qty,cu) 
            nord+=1
 
    def addemTop(self):
        "order from top list, return number of orders in book"
        nord=len(self.order)
        cus=(self.db.getTop())    
        for cu in cus:
            if nord >4: 
                return nord 
            if cu==self.mycu:
                continue
            if cu in self.order:
                print "addemO already ordered "+cu
                continue
            self.neworderOwn(self.ordqty,cu) 
            self.db.delTop(cu)
            nord+=1           
        print "addemO terminated with %d" %nord
        return nord
 
    def addemValua(self):
        "order from top list, return number of orders in book"
        wnt=[]
        giv=[]
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
                            wnt.append(cu)
        print " can buy "+str(wnt)
        if len(giv)==0:
            return
        random.shuffle(wnt)
        random.shuffle(giv)
        
        nord=len(self.order)            
        j=0
        for i in range (0,len(wnt)):
            if nord > 4 :
                return
            tcu=giv[j]   
            j+=1             
            if j>=len(giv):
                j=0
            self.neworder(1,tcu,wnt[i])
            nord+=1
        
        
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

    def onegoTop(self):
        self.getMyOrders()
        gib=self.addemTop()
        self.db.setHave(self.myuser,self.have)
        
                    
    def onego(self):
        self.wobex()
        self.bought=[]
        if self.mytyp=="T":
            self.onegoTop()   
            return
        tmp=1
        cnt=6
        print "onego with cnt %d" %cnt
        if len(self.order)==5:
            ra=random.randint(1,3)
            print "onego checkremove %d"%(ra)            
            if ra==2:
                self.removelastorder()
        while tmp>0:
            cnt-=1
            tmp=self.trading()
            print str(cnt)+" trading returned "+str(tmp)
            if tmp>0: 
                self.wobex()
            if cnt<1: 
                tmp=0
        if self.mytyp=="O":
            oib=self.addemO()
            if oib<5:
                print"onego  not enough online"
                self.wobex()
                self.trading()
                self.addemValua()
        elif self.mytyp=="V":
            oib=self.addemValua()
            if oib<5:
                pass
        else:
            self.addem1()
        self.db.setHave(self.myuser,self.have)
        self.trading()
  

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
        acnt=0
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
                acnt=self.action
            if msvcrt.kbhit():
                tmp= msvcrt.getch()      
                print tmp+"\n"
                self.printSetUp()
                print "orders:"+ str(self.order)
                if tmp=="a":
                    print str(self.getPlayersOn())
                if tmp=="c":
                    print str(self.getCursOn())
                if tmp=="m":
                    self.db.setTop(self.myuser)
                    acnt=0
                if tmp=="n":
                    self.onegoTop()
                if tmp=="o":
                    self.onego()
                    acnt=self.action
                if tmp=="p":
                    print "pause",
                    msvcrt.getch()    
                if tmp=="r":
                    self.removelastorder()
                if tmp=="s":
                    self.setUp(self.myuser)
                if tmp=="t":
                    self.trading()
                if tmp=="v":
                    self.addemValua()
                if tmp=="w":
                    self.want=self.db.getWanted(self.mycu)
                if tmp==" ":
                    print \
                    """ 
   active players
   currencies on
   many orders
   one go
   pause
   remove last order
   setup 
   trading
   wanted refresh   """
                print "?/a/c/m/o/p/r/s/t/w/q>  ",                   
                
        
if __name__ == "__main__":
    g=greed()
    g.setUp(g.db.getUserOn())
    g.login()
    g.doit()
    
    
#
#
#
#    