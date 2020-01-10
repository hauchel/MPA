; Misc V2 routines
; should leave all regs unchanged except after read
;***********
; Send a CR (actually a CRLF...)
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
V24Xon:
	push tmp
	ldi tmp,17
	rcall V24Send
	pop  tmp
	ret
V24Xoff:
	push tmp
	ldi tmp,19
	rcall V24Send
	pop  tmp
	ret
;***********	
V24Send:
.IF  BuildSimulator == 1
	ret
.ENDIF
; Wait for empty transmit
	push tmp
V24SendWait10:
	lds  tmp,UCSR0A
	sbrs tmp,UDRE0
	rjmp V24SendWait10
; Write Data
	pop  tmp
	sts  UDR0,tmp
	ret

V24ReceiveAvail:
;returns tmp 0 if receive Buffer empty
	push tmpC
	lds  tmp, V24InL
	lds  tmpC, V24OutL
	sub	tmp,tmpC
	pop  tmpC
	ret

;***********	
V24Receive:
; read tmp from out pointer
	pfiHigh 3
	push XL
	push XH
; x points to the char to read
	lds  XL, V24OutL
	lds  XH, V24OutH
V24ReceiveLop:
; Dont need to disable Ints as only low is checked
	lds  tmp, V24InL
	cp 	tmp,XL
	breq V24ReceiveLop	; in=out->empty
	ld	tmp,X+
; update pointers
	cpi	XL, low(V24BufEnd)
	brne V24ReceiveDone
; Buffer end set pointer to Begin
	ldi 	XL, low(V24Buf)
	ldi 	XH, high(V24Buf)
V24ReceiveDone:
; store out pointer
	sts	V24OutL,XL
	sts	V24OutH,XH
	pop	XH
	pop  XL
	pfiLow 3
	ret
;***********
V24ReceiveWait:
; Wait for data to be received without int
	lds tmp, UCSR0A
	sbrs tmp, RXC0
	rjmp V24ReceiveWait
	; Get and return received data from buffer
	lds tmp, UDR0
	ret
;***********	
V24_RXC:
; Character received Interrupt Handler
	pfiHigh 4
	in   sregS, SREG
	push tmp
; get char
	lds tmp, UDR0
; putch just put tmp in buf, don't care for overruns
	push	XL
	push	XH
	lds  XL, V24InL
	lds  XH, V24InH
	st	X+,tmp
	cpi	XL, low(V24BufEnd)
	brne V24_RXCDone
; Buffer end
	ldi 	XL, low(V24Buf)
	ldi 	XH, high(V24Buf)
V24_RXCDone:
;store buffer
	sts	V24InL,XL
	sts	V24InH,XH
	pop	XH
	pop	XL
	pop  tmp
	out  SREG,sregS
	pfiLow 4
	reti
;***********	
V24Init:
	push	tmp
	; Set baud rate tmpL tmpH 
	sts UBRR0H, tmpH
	sts UBRR0L, tmpL
	; Enable receiver and transmitter
	ldi tmp, (1<<RXEN0)|(1<<TXEN0)|(0<<TXCIE0)|(1<<RXCIE0)
	sts UCSR0B,tmp
	; Set frame format: 8data, 1stop bit
	ldi tmp, (0<<USBS0)|(3<<UCSZ00)
	sts UCSR0C,tmp
V24ResetBuffer:	;here only to init Receive Buffer
	ldi 	tmp, high(V24Buf)
	sts	V24InH,tmp
	sts	V24OutH,tmp
	ldi 	tmp, low(V24Buf)
	sts	V24InL,tmp
	sts	V24OutL,tmp
	ldi  tmp,'>'
	sts  V24BufBeg,tmp ; mark to find range issues
	ldi  tmp,'<'
	sts  V24BufEnd,tmp
	pop 	tmp
	ret
