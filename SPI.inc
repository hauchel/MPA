
;**************** 
; put mess to USI
StoreMes:
	mov		tmp, mesDur
	clr 	mesDur
	rjmp	USI_PutCh ; which returns
;**************** 
; get character in xBuf (XL+) into tmp
USI_GetCh:
	cp		XL,XH
	breq	USI_GetCh5 ; TODO: we have nothing?
	cli     ; avoid changing X in between
	push	ZL
	mov		ZL,XL
	ld		tmp,Z+
	cpi		ZL,BufXEnd
	brne	USI_GetCh3
	ldi		ZL, BufX
USI_Getch3:
	mov		XL,ZL
	pop		ZL
USI_GetCh5:		; ok
	sei		
	ret
;**************** 
; put char in tmp into yBuf (YH+)
USI_PutCh:
;   if USI is not full write it without buffering
	sbis	myGP, USIdirect
	rjmp	USI_PutChDirect
	cli
	push	ZL
	mov		ZL,YH
	st		Z+,tmp
;if ZL=YL then the buffer is full, undo
	cp		ZL,YL
	brne	USI_PutCh3
	dec 	ZL
USI_PutCh3:
	cpi		ZL,BufYEnd
	brne	USI_PutCh5
	ldi		ZL, BufY
USI_PutCh5:		; ok
	mov		YH,ZL
USI_PutCh7:
	pop		ZL
	sei
	ret
USI_PutChDirect:
	out		USIDR, tmp
	sbi		myGP, USIdirect
	ret
	
;**************** 
USI_Ovf:  ;Interrupt Handler USI Overflow X=in Y=Out
	in   	sregS, SREG	
	push 	tmp
	push    ZL
	ldi 	tmp,(1<<USIOIF)  	; reset flag
	out 	USISR,tmp
;
; Put Output (YL+) if nothing to snd put 0
;
	cp		YL,YH
	brne	USI_Ovf_nxt
;   nothing in buffer, provide zero
	clr		tmp
	cbi		myGP, USIdirect
	rjmp	USI_Ovf5
USI_Ovf_nxt: ;take next from buffer
	mov		ZL,YL
	ld		tmp,Z+
	sbi		myGP, USIdirect  ; we have something to snd in the buffer
	cpi		ZL, BufYEnd
	brne	USI_Ovf3
	ldi		ZL, BufY
USI_Ovf3:
	mov		YL,ZL
USI_Ovf5:
	out		USIDR,tmp
	
;   get input (XH+)
	mov		ZL,XH
	in		tmp, USIBR
	st		Z+,tmp
	cpi		ZL, BufXEnd
	brne	USI_OvfIn3
	ldi		ZL, BufX
USI_OvfIn3:
	mov		XH,ZL
USI_OvfIn5:
	pop		ZL
	pop		tmp
	out		SREG,sregS
	reti
