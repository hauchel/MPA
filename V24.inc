;***********
;
V24SendCr:
; CR is 10
	ldi 	tmp, '\n'
	rjmp	V24Send   ;implies ret

;***********
;Send tmp as byte
V24SendByte:
	push	tmpL
	push tmp
	swap tmp
	rcall V24SendNib
	pop  tmp
	rcall V24SendNib
	pop	tmpL
	ldi 	tmp, ' '
	rjmp	V24Send   ;implies ret

;***********
;Send tmp as byte but no spaces
V24SendByteShort:
	push		tmpL	;save
	push 	tmp
	swap 	tmp
	rcall 	V24SendNib
	pop     tmp
	rcall   V24SendNib
	pop		tmpL
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
	add	tmp,tmpL	;fallthru intended

V24Send:
; Wait for empty transmit buffer
	push tmp
V24Send1:
	lds  tmp,UCSR0A
	sbrs tmp,UDRE0
	rjmp V24Send1
; Put data into buffer
	pop  tmp
	sts  UDR0,tmp
	ret

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

V24Receive:
; Wait for data to be received
	lds tmp, UCSR0A
	sbrs tmp, RXC0
	rjmp V24Receive
	; Get and return received data from buffer
	lds tmp, UDR0
	ret

V24Init:
	; Set baud rate tmpL tmpH 
	sts UBRR0H, tmpH
	sts UBRR0L, tmpL
	; Enable receiver and transmitter
	ldi tmp, (1<<RXEN0)|(1<<TXEN0)
	sts UCSR0B,tmp
	; Set frame format: 8data, 1stop bit
	ldi tmp, (0<<USBS0)|(3<<UCSZ00)
	sts UCSR0C,tmp
	ret
