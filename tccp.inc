; contains routines to handle tccp
; Registers reserved:
;
;

; 
; Tiny Cluster Comminucation Protocol
; Connects SPI in three wire mode up to 15 slaves to a master with low hardware effort.
; Master     SL1 SL2 SLF
; SCK---------+---+---+
; MISO        o>  o>  o  -----> Master MISO
; MOSI -----> i \-i \-i
; Message Level Convention
; Device wakes up if activated by device select 0x
; Receives and sends data until other 0x
; Special Chars
; It might be reqd to read data by master without sending. In this case Master sends pollChar which should be ignored
; Upper Nibble 1 is Ack from Slaves
;; The first byte after the attention can be interpreted by the slave as a command to regulate the logic transportation level
; Slave mode is comAct  or not active
; Interrupt:
; active:
; DAC        Data:       store and eventually provide new  
;           Control:
;           for me:      why? ignore/reset?
;           not for me: doe end of transaction
; Not active:
; DIG        Data:   ignore
;       Control:
; CME        for me:  or 00change to active and acknowledge
; CNM     not for me : ignore
; Example
; Send message AA DD ZZ to device two:
; State                        Sl     does   S2  does   S3  does  Master
; idle                 71         72         73                                
; EX: Message forS2:   02  CNM    71  DIG    72  DIG       
; AA                                     AA  DIG    02  CME    71  DIG ...
; DD                   DD  DIG    AA  DAC  
; ZZ                   ZZ  DIG    DD  DAC
; How does a slave know its number?: If for more than a given time (e.g. 1 ms) the same control value is in and not changed, are 0
; If it's 00, forget it
; When Beginning the Master sends
; 00 01 02 03 04 05 06 07 until it receives 00:
; Then wait more than 1ms
; Same solve the out of sync issue: send all 00 then wait. Timeout will reset the
; Improve:
;	do net send leading zeros
;   

V24ReceiveAvail:
;returns tmp 0 if receive Buffer empty
	mov 	tmp,bufRcvIP
	sub	tmp,bufRcvOP	
	ret

V24Receive:
USI_GetCh:
; get character from BufRcv in tmp, Wait if nothing received
;	PfiLow 		; Debug only Check for Counter value and set Pfi if not zero
;	in tmp,USISR   
;	andi tmp,0x0F
;	breq UsiGetCh05
;	pfiHigh
UsiGetCh05:		; End Debug
	cp	bufRcvIP,bufRcvOP	
	breq	USI_GetCh ; nothing in buffer, wait
	push	XL
	push	XH
	clr	XH 		; X always below 0x100
	mov  XL, BufRcvOP
	ld	tmp,	X+
	cpi	XL, low(BufRcvEnd)
	brne UsiGetCh10
; Buffer end
	ldi 	XL, low(BufRcv)
;store buffer
UsiGetCh10:
	mov	BufRcvOP,XL
; restore regs
	pop	XH
	pop	XL
	ret

; should leave all regs unchanged except after read
;***********
; Send a CR
V24SendCr:
; CR is 10
	push tmp
	ldi 	tmp, '\n'
	rcall V24Send 
	pop tmp
	ret
;***********
; Send char in tmp then space 
V24SendSpc:
	push tmp
	rcall V24Send 
	ldi 	tmp, ' '
	rcall V24Send
	pop tmp
	ret
;***********
; Send char in tmp then backspace 
V24SendBSpc:
	push tmp
	rcall V24Send 
	ldi 	tmp, 8
	rcall V24Send
	pop tmp
	ret
;***********
;Send tmpH/L as word
V24SendWordHL:
	push	tmp
	mov	tmp,tmpH
	rcall V24SendByteShort
	mov	tmp,tmpL
	rcall V24SendByte
	pop 	tmp
	ret
;***********
;Send tmp as char then tmpH/L as word (e.g. do display pointer values
V24SendWordCh:
	rcall V24Send
	rjmp	V24SendWordHL
;***********
;Send the 3 Index registers and SP
V24SendIdx:
	push tmp
	push tmpL
	push tmpH
	ldi  tmp,'X'
	movw	tmpL,XL
	rcall V24SendWordCh
	ldi  tmp,'Y'
	movw	tmpL,YL
	rcall V24SendWordCh
	ldi  tmp,'Z'
	movw	tmpL,ZL
	rcall V24SendWordCh
	ldi  tmp,'S'
	in tmpL,SPL;	;hav do subtract the currently pushed.
	in tmpH,SPH;
	rcall V24SendWordCh
	pop 	tmpH
	pop 	tmpL
	pop 	tmp
	ret
;***********
;Send tmp as byte
V24SendByte:
	push tmp		;save original value
	push	tmpL
	push tmp
	swap tmp
	rcall V24SendNib
	pop  tmp
	rcall V24SendNib
	pop	tmpL
	ldi 	tmp, ' '
	rcall V24Send 
	pop 	tmp
	ret
;***********
;Send tmp as byte but no spaces
V24SendByteShort:
	push tmp
	push	tmpL	;save
	push tmp
	swap tmp
	rcall V24SendNib
	pop  tmp
	rcall V24SendNib
	pop	tmpL
	pop 	tmp
	ret
;***********	
V24SendNib:
; 0..9 to 48..57, A..F to 65..70
;tmpL was saved in calling routine, so we can use it
	andi	tmp,15
	ldi  tmpL,48
	add	tmp,tmpL
	cpi	tmp,58
	brcs	V24send		;K > tmp
	ldi	tmpL,7
	add	tmp,tmpL	
	rjmp V24Send
;***********	
V24SendString:
; Transfer string from flash pointed to by Z(destroyed) until \0
;	txt: .db "Hallo ",'\n', 0 ; <-dont forget 0
;	  ldi ZH, high(txt*2);
;	  ldi ZL, low(txt*2);
; 
	push	tmp
V24SendString_1:
	lpm	tmp,Z+
	tst	tmp
	breq V24SendString_X
	rcall V24Send
	rjmp V24SendString_1
V24SendString_X:
	pop 	tmp
	ret
;***********	

V24Send:
USI_PutCh:
; put character in BufSnd, no Overflow detection
	push	XL
	push	XH
	clr	XH 		; always below 0x100
	mov  XL, BufSndIP
	st	X+,tmp
	cpi	XL, low(BufSndEnd)
	brne UsiPutCh10
; Buffer end
	ldi 	XL, low(BufSnd)
;store buffer
UsiPutCh10:
	mov	BufSndIP,XL
; restore regs
	pop	XH
	pop	XL
	ret



USI_OVF: ;tiny 85 SPI Character received Interrupt Handler 
; simple rules
; 
	PfiHigh
	in   sregS, SREG
; get char
	in usiD, USIBR
; active?
	sbic UsiGP, gpUsiActive
	rjmp UsiActive	
; DIG  Data:   ignore
	cp	usiD,usiNum
	breq	UsiMakeActive
	out	SREG, sregS			; nothing 2do
	PfiLow
	reti	
; CME    for me: change to active and acknowledge
UsiMakeActive:
	sbi	USIDR, 4	; makes 1x
	sbi	UsiGP, gpUsiActive
	LedOn
	PfiLow
	out	SREG, sregS
	reti
UsiMakeInactive:
	cbi	UsiGP, gpUsiActive
	LedOff	
	rjmp UsiEndNoX

UsiActive:
	cp	usiD,usiNum
	breq	UsiMakeActive ;my own select
; if incoming is device Select, de-activate
	push tmp
	ldi  tmp,devMask
	and  tmp,usiD
; Device Select not for me 
	breq UsiMakeInactive
; Data received:
	push	XL
	push	XH
	clr	XH ; always below 0x100
; First handle out;   
	cp BufSndIP,BufSndOP
	brne UsiActiveSend
; nothing to send, put 
	ldi tmp,pollChar
	out	USIDR,tmp	
	rjmp UsiActiveReceive
UsiActiveSend:
	mov	XL,BufSndOP
	ld	tmp,X+
; put my new Value into USI:
	out	USIDR,tmp	
	cpi	XL, low(BufSndEnd)
	brne UsiActiveSnd10
; Buffer end
	ldi 	XL, low(BufSnd)
UsiActiveSnd10:
	mov	BufSndOP,XL	
;put rcv Char in inBuf
UsiActiveReceive:
	mov  XL, BufRcvIP
	st	X+,usiD
	cpi	XL, low(BufRcvEnd)
	brne UsiActiveRead10
; Buffer end
	ldi 	XL, low(BufRcv)
;store buffer
UsiActiveRead10:
	mov	BufRcvIP,XL
; restore regs
	pop	XH
	pop	XL
UsiEndNoX:
	pop  tmp
	PfiLow
	out  SREG,sregS
	reti


USI_Setup85:  ;Tiny 85 as Slave 
	push tmp
; USIWM1:0  01 Three wire mode 
;	mode  USICS1   USICS0   USICLK	Clock Source                
;	  0		1 		0 		0		Ext, positive edge 	
;	  1		1 		1 		0 		Ext, negative edge 	
; In external clock mode 0 (USICS0 = 0), DI is sampled at positive edges, and DO is changed at negative
; e.g. 328 uses 
; 	0	CPOL=0, CPHA=0 	Sample (Rising) 	Setup (Falling)
;	1	CPOL=0, CPHA=1 	Setup (Rising) 	Sample (Falling)
; Very Strange: works only with Data Mode 3 on Master Arduino
;
	ldi tmp, (0<< USISIE)+(1<< USIOIE)+(0<<USIWM1)+(1<<USIWM0)+(1<<USICS1)+(0<<USICS0)
	out USICR,tmp
	ldi tmp,(1<<USIOIF)
	out USISR,tmp
	; put a certain value in usi:
	ldi tmp,pollChar
	out	USIDR,tmp	

; set ribus and usi flags
	cbi	UsiGP, gpUsiActive
	cbi	UsiGP, gpUsiKnown
	cbi  UsiGP, gpUsiSend	
	cbi  UsiGP, gpUsiDebug	
	ldi	tmp,	low(BufRcv)
	mov	BufRcvIP,tmp
	mov	BufRcvOP,tmp
	ldi	tmp,	low(BufSnd)
	mov	BufSndIP,tmp
	mov	BufSndOP,tmp
	pop tmp
	ret

