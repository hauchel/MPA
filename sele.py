import time
from selenium import webdriver
# "C:\Program Files (x86)\Java\jre7\bin\java" -jar  selenium-server-standalone-2.44.0.jar
class greed():
 
    def setUp(self):
        self.driver = webdriver.Firefox()
        self.driver.implicitly_wait(3)
        self.base_url = "http://www.greedgame.com/"
        self.verificationErrors = []
        self.accept_next_alert = True
        self.want=['BD','CH','PY', 'ID','IS','NA','MA','MY','UG','SG','NP']
        self.order=[]
        self.have={}
        self.mycu='KR'
        self.ordqty=3
        self.excqty=30
        self.low=True

    def worldbank(self):
        d = self.driver
        d.get(self.base_url+"worldbank") 
        self.have={}
        x=d.find_elements_by_xpath("//tr")
        for z in range(1,len(x)): 
            id= x[z].get_attribute("id")
            if id[:6]=="invest":
                q=x[z].find_elements_by_xpath("td")
                cu=id[-2:]
                print q[3].text+" "+cu  # qty+amnt
                self.have[cu]=int(q[3].text)
                
            
    def xchange(self):
        "returns 1 if not succ"
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

    def checkbuy(self):
        try:
            suc=self.driver.find_elements_by_class_name("success")
        except Exception as inst:
            print "trading succ: "+type(inst)
            suc=[]
            return 0
        for r in suc:       
            y=r.find_elements_by_tag_name("li")
            tmp=y[0].text.split()
            getqty=int(tmp[0])
            tmp=y[1].text.split()
            givqty=int(tmp[0])
            getcu=y[0].get_attribute("data-coin")
            givcu=y[1].get_attribute("data-coin")
            if getcu in self.have:
                gethav= self.have[getcu]
            else:
                gethav=0;
            givhav=self.have[givcu]
            print "canbuy "+str(getqty)+" "+getcu+" hav "+str(gethav)+ \
                " give "+givcu +" "+str(givqty)+ " hav "+str(givhav)
            if getqty==givqty:
                getnew=gethav+getqty
                givnew=givhav-givqty                
                print "wouldbuy " + str(getnew)+ " vs "+ str(givnew)
                if givnew > getnew:
                    bu=r.find_element_by_link_text("buy")
                    print bu.rect
                    bu.click()
                    return getqty
        return 0
            
            
    def trading(self):
        d = self.driver
        d.get(self.base_url+"tradingplace")
        self.order=[]
        try:
            rem=self.driver.find_elements_by_class_name("info")
        except Exception as inst:
            print "trading info: "+type(inst)
            rem=[]
        for r in rem:       
            y=r.find_elements_by_tag_name("li")
            my=y[0].get_attribute("data-coin")
            cu=y[1].get_attribute("data-coin")
            print "ordered "+cu+ " my "+my 
            self.order.append(cu)
        return self.checkbuy()
                    
    def newoffer(self,ta):
        d = self.driver
        d.get(self.base_url+"newoffer")
        x=d.find_element_by_name('M[KR]')
        x.clear()
        x.send_keys(str(self.ordqty))
        x=d.find_element_by_name("Y["+ta+"]")
        x.clear()
        x.send_keys(str(self.ordqty))
        d.find_element_by_xpath("//button[@type='submit']").click()
    
    def login(self):
        d = self.driver
        d.get(self.base_url)
        d.find_element_by_link_text("Click here to log in").click()
        d.find_element_by_name("username").send_keys("r2d2")
        d.find_element_by_name("password").send_keys("robot")
        d.find_element_by_css_selector("fieldset > button.btn").click()
  
    def removeorder(self):
        d = self.driver
        try:
            x=d.find_element_by_link_text('remove')
            x.click()
            return("weg")
        except Exception as inst:
            print type(inst)     # the exception instance
            return("nix")
    
    def removeall(self):
        self.trading()
        while "weg"==self.removeorder():
            print "removed"
           
        
    def addem(self):
        if 5==len(self.order): return 
        for cu in self.want:
            if cu in self.have:
                print "have "+str(self.have[cu])+" "+cu
                if self.low:
                    print "low"
                else:
                    if self.have[cu]<5:
                        if not cu in self.order:
                            print "new ordered "+cu
                            self.newoffer(cu)
            else:
                if cu in self.order:
                    print "ordered "+cu
                else:
                    print "newoffer "+cu
                    self.newoffer(cu)
        
    def schluss(self):
        self.driver.quit()

    def wobex(self):
        self.worldbank()
        my=self.have[self.mycu]
        print "wobex after woba1 "+str(my)+" "+self.mycu        
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
            
    def onego(self):
        self.wobex()
        tmp=1
        cnt=5
        while tmp>0:
            tmp=self.trading()
            cnt-=cnt
            print str(cnt)+" trading returned "+str(tmp)
            if cnt<1: 
                tmp=0
            self.wobex()
        self.addem()
        print str(self.have)
        print "low = "+str(self.low)
        
    def doit(self):
        while 1:
            self.onego()
            try:
                print "Sleeping"
                for cnt in range(0,20):
                    time.sleep(4)
            except Exception as inst:
                print "doit: "+type(inst)
                return 1
        
if __name__ == "__main__":
    g=greed()
    g.setUp()
    g.login()
    g.doit()
    
#
#
#
#    