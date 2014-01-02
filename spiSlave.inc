; Some routines as SPI Slave
; uses spiBuf (max 255 bytes!) to store Data 
; spiInL/H and spiOutL/H point to ribu
;
SpiSlaveInit:
	push	tmp
	clr 	spiRcv
	ldi 	tmp, high(spiBuf)
	sts	spiInH,tmp
	sts	spiOutH,tmp
	ldi 	tmp, low(spiBuf)
	sts	spiInL,tmp
	sts	spiOutL,tmp
	ldi  tmp,(1<<SPIE)+(1<<SPE)
	out 	SPCR, tmp
	pop 	tmp
	ret

SPI_STC:
; Interrupt-Handler when SPI received, 
; fetch data in spiRcv, put new data in
	in   sregS, SREG 
	in	spiRcv, SPDR	
;
	push	XL
	push	XH
	lds  XL, spiOutL
	lds  XH, spiInL
	cp	XL,XH
	breq SPI_STC_Nix ;empty
	lds  XH, spiOutH
	push	tmp
	ld	tmp,X+
	out  SPDR,tmp
	pop  tmp
	cpi	XL, low(spiBufEnd)
	brne SPI_STC_1
; Buffer end
	ldi 	XL, low(spiBuf)
	ldi 	XH, high(spiBuf)
SPI_STC_1:
	sts	spiOutL,XL
	sts	spiOutH,XH
	rjmp SPI_STC_Back
SPI_STC_Nix:
; nothing to send
	clr	XL
	out  SPDR,XL
SPI_STC_Back:
	pop	XH
	pop	XL
	out	SREG,sregS
	reti

SpiSendByte:
;Send tmp as byte
	rcall SpiSendByteShort
	ldi 	tmp, ' '
	rjmp	SpiSend   ;implies ret

SpiSendByteShort:
;Send tmp as byte but no spaces
	push	tmpL	;save
	push tmp
	swap	tmp
	rcall SpiSendNib
	pop  tmp
	rcall SpiSendNib
	pop	tmpL
	ret

SpiSendString:
; Transfer string from flash pointed to by Z(destroyed) until \0
;	txt: .db "Hallo ",'\n', 0
;	  ldi ZH, high(txt*2);
;	  ldi ZL, low(txt*2);
; 
	push	tmp
SpiSendString_1:
	lpm	tmp,Z+
	tst	tmp
	breq SpiSendString_X
	rcall SpiSend
	rjmp SpiSendString_1
SpiSendString_X:
	pop 	tmp
	ret

SpiSendNib:
; 0..9 to 48..57, A..F to 65..70
;tmpL was saved in calling routine, so we can use it
	andi	tmp,15
	ldi  tmpL,48
	add	tmp,tmpL
	cpi	tmp,58
	brcs	SpiSend		;K > tmp
	ldi	tmpL,7
	add	tmp,tmpL	;fallthru intended
; fallthru!
SpiSend:
; just put tmp in buf
	push	XL
	push	XH
	lds  XL, spiInL
	lds  XH, spiInH
	st	X+,tmp
	cpi	XL, low(spiBufEnd)
	brne SpiSend1
; Buffer end
	ldi 	XL, low(spiBuf)
	ldi 	XH, high(spiBuf)
SpiSend1:
	sts	spiInL,XL
	sts	spiInH,XH
	pop	XH
	pop	XL
	ret

