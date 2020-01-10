; SPI Interface for attiny x5
;
; external defines required:
;
; Using
; BufX
; BufXEnd
; inL inH   pointer to input buffer
; outL outH   pointer to output buffer
; ZH must be 0?
;; Ribus must be in lower memory as ?H are set to 0
;BufinL
;BufinH
;BufX:		.Byte 8 	  ;Input from USI
;BufXEnd:	
;BufY:		.BYTE 8	  ;Output to USI
;BufYEnd:	.Byte 2
; myGP, USIdirect
; put mess to USI

; rjmp		rjmp USI_OVF    ; 15 USI Overflow


USI_Setup:  ;Slave 
; Interrupt called at overflow then USI data is stored in XBuf and taken from YBuf
; 
; USISIE: Setting this bit to one enables the start condition detector interrupt. If there is a pending interrupt
; USIOIE: Counter Overflow Interrupt Enable
; USIWM1, USIWM0: Wire Mode
;   0        1    Three Wire
; USICLK: Clock Strobe Writing a one to this bit location strobes the USI Data Register to shift one step and the counter
; USICS1 USICS0 USICLK 	    Clock Source            4-bit Counter Clock Source
;	0		0		0   	No   Clock 				No Clock
;   0      	0 		1       Software clock strobe (USICLK) Software clock strobe (USICLK)
;	0 		1 		X 		Timer/Counter0 Compare Match Timer/Counter0 Compare Match
;	1 		0 		0		Ext, positive edge 		Ext, both edges
;	1 		1 		0 		Ext, negative edge 		Ext, both edges
;	1 		0 		1 		Ext, positive edge 		Software clock strobe (USITC)
;	1 		1 		1 		Ext, negative edge 		Software clock strobe (USITC)
	ldi tmp, (0<< USISIE)+(1<< USIOIE)+(0<<USIWM1)+(1<<USIWM0)+(1<<USICS1)+(0<<USICS0)+(0<<USICLK)
	out USICR,tmp
; set ribs and USI
	cbi	myGP, USIdirect
	ldi tmp, BufX
	mov  inL,tmp
	mov	inH, tmp
	ldi  tmp,BufY
	mov	outL, tmp
	mov	outH, outL
	ldi tmp,(1<<USIOIF)
	out USISR,tmp
	ret


; get character in xBuf (inL+) into tmp
USI_GetCh:
	clr	tmp
	cp	inL,inH
	breq	USI_GetCh5 ; we have nothing?
	cli     ; avoid changing X in between
	push	ZL
	push ZH
	clr ZH
	mov		ZL,inL
	ld		tmp,Z+
	cpi		ZL,BufXEnd
	brne	USI_GetCh3
	ldi		ZL, BufX
USI_Getch3:
	mov		inL,ZL
	pop	ZH
	pop	ZL
	sei	
USI_GetCh5:		; ok
	ret
;**************** 
; put char in tmp into yBuf (outH+)
USI_PutCh:
;   if USI is not full write it without buffering
	sbis	myGP, USIdirect
	rjmp	USI_PutChDirect
	cli
	push	ZL
	push ZH
	clr ZH
	mov		ZL,outH
	st		Z+,tmp
;if ZL=outL then the buffer is full, undo
	cp		ZL,outL
	brne	USI_PutCh3
	dec 	ZL
USI_PutCh3:
	cpi		ZL,BufYEnd
	brne	USI_PutCh5
	ldi		ZL, BufY
USI_PutCh5:		; ok
	mov		outH,ZL
USI_PutCh7:
	pop		ZH
	pop		ZL
	sei
	ret
USI_PutChDirect:
	out		USIDR, tmp
	sbi		myGP, USIdirect
	ret

;***********	
USI_SendNib:
; tmp 0..9 to 48..57, A..F to 65..70
;tmpL was saved in calling routine, so we can use it
	andi	tmp,15
	ldi  tmpL,48
	add	tmp,tmpL
	cpi	tmp,58
	brcs	USI_putch		;K > tmp
	ldi	tmpL,7
	add	tmp,tmpL	
	rjmp USI_putch
	
;***********
;Send tmp as hex value
USI_SendHex:
	push tmp
	push	tmpL	;save
	push tmp
	swap tmp
	rcall USI_SendNib
	pop  tmp
	rcall USI_SendNib
	pop	tmpL
	pop 	tmp
	ret
;***********
;Send tmp as dec value
USI_SendDec:
	push tmpL
	push	tmpH	;save
	push tmp
	mov tmpL ,tmp
	ldi tmpH ,100
	rcall div8u ;remander in tmpX
	mov  tmp,tmpL
	rcall USI_SendNib
	mov tmpL ,tmpX
	ldi tmpH ,10
	rcall div8u ;remander in tmpX
	mov  tmp,tmpL
	rcall USI_SendNib
	mov  tmp,tmpX
	rcall USI_SendNib
	ldi tmp,' '
	rcall USI_PutCh
	pop 	tmp
	pop	tmpH
	pop  tmpL
	ret

;**************** 
USI_Ovf:  ;Interrupt Handler USI Overflow X=in Y=Out
	in   	sregS, SREG	
	push 	tmp
	push    ZL
	push	ZH
	clr ZH
	ldi 	tmp,(1<<USIOIF)  	; reset flag
	out 	USISR,tmp
;
; Put Output (outL+) if nothing to snd put #
;
	cp		outL,outH
	brne	USI_Ovf_nxt
;   nothing in buffer
	ldi 		tmp,'#'
	cbi		myGP, USIdirect
	rjmp	USI_Ovf5
USI_Ovf_nxt: ;take next from buffer
	mov		ZL,outL
	ld		tmp,Z+
	sbi		myGP, USIdirect  ; we have something to snd in the buffer
	cpi		ZL, BufYEnd
	brne	USI_Ovf3
	ldi		ZL, BufY
USI_Ovf3:
	mov		OutL,ZL
USI_Ovf5:
	out		USIDR,tmp
	
;   get input (inH+)
	mov		ZL,inH
	in		tmp, USIBR
	st		Z+,tmp
	cpi		ZL, BufXEnd
	brne	USI_OvfIn3
	ldi		ZL, BufX
USI_OvfIn3:
	mov		inH,ZL
USI_OvfIn5:
	pop		ZH
	pop		ZL
	pop		tmp
	out		SREG,sregS
	reti


;***** divide tmpL by tmpH
;.def	tmp	;counter 		saved
;.def	tmpX	;remainder    	set
;.def	tmpL	;dividend     	input and result
;.def	tmpH	;divisor		imput unchanged

div8u:	
	push tmp
	sub	tmpX,tmpX	;clear remainder and carry
	ldi	tmp,9	;init loop counter
d8u_1:	
	rol	tmpL		;shift left dividend
	dec	tmp		;decrement counter
	brne	d8u_2	;if done
	pop	tmp
	ret			;return
d8u_2:	
	rol	tmpX		;shift dividend into remainder
	sub	tmpX,tmpH	;remainder = remainder - divisor
	brcc	d8u_3	;if result negative
	add	tmpX,tmpH	;restore remainder
	clc			;clear carry to be shifted into result
	rjmp	d8u_1	;else
d8u_3:	
	sec			;set carry to be shifted into result
	rjmp	d8u_1
