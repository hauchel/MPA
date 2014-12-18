from gdb import gdb 
import time

class bubu():

    def __init__(self):
        self.db=gdb()  
        self.user="R2D2"
        
    def doit(self):
        while 1:
            self.db.db.commit()
            self.db.cst.execute("SELECT id,cmd from task where user='"+self.user+"' and done=''")
            print "curs" 
            for cmd in self.db.cst:
                print "Doit: "+str(cmd)
                if cmd[1]== "stop":
                    self.db.doneTask(cmd[0])
                    return 1
                elif cmd[1]=="one":
                    self.onego()
                else:
                    print "unknown"
                self.db.doneTask(cmd[0])                                  
            for cnt in range(0,2):
                    time.sleep(4)
            print self.db.zeit()

if __name__ == "__main__":
    g=bubu()
    g.user
    rx=g.db.getUserOn()
    g.doit()            