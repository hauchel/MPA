# -*- coding: utf-8 -*-
import requests
import HTMLParser



class MyParse(HTMLParser.HTMLParser):
    def __init__(self):   
        HTMLParser.HTMLParser.__init__(self)
        self.eval=False
        
    def handle_starttag(self, tag, attrs):
#        print "Starttag >"+tag+"<",
        for a in attrs:
            if a[0] == 'href':
                print "href "+a[1]
            elif a[0] == 'class':
                print "class "+a[1]+str(attrs)
            else :
                print "miscs "+a[1]+str(attrs)
 #           print str(a),        

   
        
if __name__ == "__main__":
    p = MyParse
    s = requests.Session()
    u = 'http://www.greedgame.com/login'
    r=s.get(u)
    payload = {'username': 'R2D2', 'password': 'robot'}
    r=s.post(u,data=payload)
    

