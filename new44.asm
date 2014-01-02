;*************************************************************************
; Test Program SPI     
; for new tinyno
; CPU should be 1 MHz (as default CKSEL = 0010, CKDIV8 programmed)
; Timer 0 CTC controls snding and other stuff with clkI/O/256
; Timer 1 CTC controls receiving, clkI/O/64 compared to Timer 0
;*************************************************************************
.NOLIST
.include "tn44def.inc"
.LIST

; Constants
.equ    anaSamp    	=   0x20   	; number of samples
.equ    dur1       	=    8   	; OCR0B to signal 0
.equ    dur0       	=   16   	; OCR0B to signal 1
.equ    durTot		=   24   	; OCR0A time 
.equ    durTim1		=   12 		; Timer 1 OCR1A to sample 4*(durTot/durTim1) times per bit
; recver 
.equ	limLow		=  0x90		; Analog below this value considered Signal
.equ    rcv0	    =    4		; if signal dur below consider 0 else 1
.equ    rcvEOB 	 	=    8      ; if nosignal longer than this consider eobyte
; fields
.equ	fldMax     = 4			; check these fields -1
.equ	colR		= 0b00001000
.equ	colG		= 0b00001100
.equ	colU		= 0b00000100
; register usage
.def	debug		= R0	; debug mode if not 0
.def	myCol		= R1	; my color of current field
.def	rcvOri		= R2	; ori recved
.def	setCol		= R3	; color to set if 0..7 pressed
.def	inOri		= R4	; 
.def    cycCnt      = R5	; cycle for on field, dec by Tim0
.def	sndCnt		= R6	; if <> 0 snd USI
.def	total			= R7	; total times per cycle inc in tim0
.def	inData  	= R8	; contains incoming Data if inDataValid
.def	inByte		= R9	; incoming Byte built by tim1
.def	sigCnt		= R10	; count of signal duration
.def	nosCnt		= R11   ; count of no Signal duration
.def	oriCnt	 	= R12	; count to snd varying Ori
;.def	sinCnt	 	= R13	; 
;.def	cntOn	 	= R14	; 
.def	sregS		= R15	; saves status during interrupt
.def 	tmp 		= R16   ; general usage, not preserved
.def	mesDur		= R17	; Duration of signal
.def	sndBit		= R18	; Bit which is currently  sent 8..1, 0=nosnd
.def	sndByte		= R19	; Byte which is currently sent
.def	field		= R20	; current field 0..
.def	evaRes		= R21	; result of evaluation
.def	myOri		= R22	; my Ori
.def	anaCnt		= R23	; Counter analog 
.def	tmpL		= R24   ;
.def	tmpH		= R25   ;
; XL				= R26 	; BufX in, do not touch
; XH				= R27	; BufX out, do not touch
; YL				= R28   ; 
; YH				= R29 	; 
; ZL				= R30   ; current ponter to Buffer
; ZH				= R31	; must be Zero!

;Data Segment	
.dseg
	.org SRAM_START
; Ribus must be in lower memory as ?H are set to 0
BufX:		.Byte 8 	  ;Input from USI
BufXEnd:	
BufY:		.BYTE anaSamp	  ;Output to USI
BufYEnd:	
FeBck:		.Byte 16		; EE no response, DD alive , D0 to D3 for valid orientatios
FeCol:		.Byte 16		; color


;Code Segment	
.cseg
; interrupt Jump Table attiny x4
	.org 0x0000
 	rjmp RESET 					;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
	reti; 		rjmp EXT_INT0 	;  2 IRQ0 
	reti; 		rjmp PCINT0 	;  3 PCINT0 
	reti;		rjmp 	PCINT1_Handler 		;  4 PCINT1  
	reti; 		rjmp WDT	 	;  5 Watchdog Time-out
	reti;		rjmp TIM1_CAPT	;  6 Timer1 Capture
	rjmp 	Tim1_CompA			;  7 Timer1 Compare A
	reti; 		rjmp TIM1_COMPB	;  8 Timer1 Compare B
	reti; 		rjmp TIM1_OVF	;  9 Timer1 Overflow
	rjmp 	Tim0_CompA			; 10 Timer0 Compare A
	rjmp 	Tim0_CompB			; 11 Timer0 Compare B
	reti; 		rjmp TIM0_OVF	; 12 Timer0 Overflow
	reti; 		rjmp ANA_COMP 	; 13 Analog Comparator Handler
	reti; 		rjmp ADC 	 	; 14 Analog Conversion Complete
	reti; 	 	rjmp EE_RDY 	; 15 EEPROM Ready Handler
	reti;		rjmp USI_STR	; 16 USI Start
	rjmp 	USI_OVF				; 17 USI Overflow
	

;Ports Field 0 to 15 
; 138 A0
.equ 	fe0Num		=   0
.equ 	fe0Prt		=	PORTA
.equ 	fe0Pin		=	PINA
.equ 	fe0Dir		=	DDRA
; 138 A1
.equ 	fe1Num		=   1
.equ 	fe1Prt		=	PORTA
.equ 	fe1Pin		=	PINA
.equ 	fe1Dir		=	DDRA
; 138 A2
.equ 	fe2Num		=   2
.equ 	fe2Prt		=	PORTA
.equ 	fe2Pin		=	PINA
.equ 	fe2Dir		=	DDRA
; 138 E3/E2 left or rigth
.equ 	fe3Num		=   3
.equ 	fe3Prt		=	PORTA
.equ 	fe3Pin		=	PINA
.equ 	fe3Dir		=	DDRA

; USI
.equ 	sckNum		=   4
.equ 	sckPrt		=	PORTA
.equ 	sckPin		=	PINA
.equ 	sckDir		=	DDRA

.equ 	DO_Num		=   5
.equ 	DO_Prt		=	PORTA
.equ 	DO_Pin		=	PINA
.equ 	DO_Dir		=	DDRA

.equ 	DI_Num		=   6
.equ 	DI_Prt		=	PORTA
.equ 	DI_Pin		=	PINA
.equ 	DI_Dir		=	DDRA


; In Analog -> ADC setup!
.equ 	anaNum		=   7
.equ 	anaPrt		=	PORTA
.equ 	anaPin		=	PINA
.equ 	anaDir		=	DDRA

;Selection led within field
; 3rd138 A0 toggles odd/even
.equ 	ld0Num		=   0
.equ 	ld0Prt		=	PORTB
.equ 	ld0Pin		=	PINB
.equ 	ld0Dir		=	DDRB
; 3rd138 A1 low bit 1 of 4
.equ 	ld1Num		=   1
.equ 	ld1Prt		=	PORTB
.equ 	ld1Pin		=	PINB
.equ 	ld1Dir		=	DDRB
; 3rd138 A2 hi bit 1 of 4
.equ 	ld2Num		=   2
.equ 	ld2Prt		=	PORTB
.equ 	ld2Pin		=	PINB
.equ 	ld2Dir		=	DDRB


; GPIO use sbi cbi sbis sbic 
.equ	myGP	= GPIOR0	; flag register
.equ	USIdirect 	= 7 	; 1 if data in USI,		0 if no data
.equ	received	= 6     ; 1 data in  	
.equ    inDataValid = 5     ; 1 if inData valid
.equ    stopSnd		= 4		; 1 if sending to stop (OCR0B)

.equ	mySet	= GPIOR1	; Settings
.equ	anaraw 		= 7		; 1 to store raw data,	0 to count signal
.equ	anaDau		= 6     ; 1 to sample contin, 	0 to sample anaCnt
.equ    anaMes      = 5     ; 1 to return count of signal  
.equ    copRec		= 4		; 1 if snding recved
.equ    sndOff      = 1     ; 1 to not switch off snding led
.equ    cycMod		= 0     ; 1 to process all fields in sequence


.MACRO PortOut ; num dir Port as output to zero
	sbi @1 , @0
	cbi @2,  @0
.ENDMACRO

.MACRO PortInP ; num dir Port as input with Pup
	cbi @1 , @0
	sbi @2, @0
.ENDMACRO



; Start of Program
RESET:
;here we go:
	ldi r16, high(RAMEND); Main program start
	out SPH,r16 ; Set Stack Pointer to top of RAM
	ldi r16, low(RAMEND)
	out SPL,r16


; configure Ports 
    PortOut fe0Num, fe0Dir, fe0Prt
	PortOut fe1Num, fe1Dir, fe1Prt
	PortOut fe2Num, fe2Dir, fe2Prt
	PortOut fe3Num, fe3Dir, fe3Prt
	PortOut DO_Num, DO_Dir, DO_Prt
	PortOut ld0Num, ld0Dir, ld0Prt
	PortOut ld1Num, ld1Dir, ld1Prt
	PortOut ld2Num, ld2Dir, ld2Prt
		    
	PortInP DI_Num, DI_Dir, DI_Prt
    PortInP sckNum, sckDir, sckPrt
    

    PortInP anaNum, anaDir, anaPrt
; configure 
	rcall 	ADC_Setup
	rcall 	USI_Setup
	rcall 	Tim0_Setup
	rcall 	Tim1_Setup
;	rcall ExtInt_Setup  ; remove if not dbg

	clr	  	debug
	cbi		myGP, USIdirect
	cbi		mySet, anaRaw
	sbi		mySet, anaDau
	ldi		anaCnt, 0x80
	cbi		mySet, anaMes
	cbi		mySet, sndOff 
	sbi		mySet, cycMod 
	ldi		tmp, 3
	mov		myOri, tmp
	ldi		tmp, 3
	mov		oriCnt, tmp
	clr     cycCnt
	sei ; Enable interrupts


start:
	ldi tmp, 0x0F
	rcall	USI_putch


lop:	
; check messages from ints
	tst		mesDur
	breq	lopPre1
	rcall	StoreMes

lopPre1:   	; check incoming data from Signal
	sbic	myGP,inDataValid
	rcall	Eval

lopPre5:	; check Dauersnd
	tst		sndCnt
	breq	LopPre6
	tst    	sndBit
	brne	LopPre6
	ldi		tmp, 0xA9
	dec		sndCnt
	rcall	send

lopPre6: ; new field if oricnt
	sbis	mySet,cycMod
	rjmp	lopPre7		
	tst		cycCnt
	brne	lopPre7 ; cycle still running
;pending sends?
	tst    	sndBit
	brne   	lopPre8 ; Already busy
	rcall	FeldNext
	
lopPre7:	; check ori (wait if free, then inc my)
	tst		oriCnt
	breq	lopPre8
	tst    	sndBit
	brne   	lopPre8 ; Already busy
	dec		oriCnt
	inc		myOri
	andi	myOri,0x03
	rcall	Select
; color from field 
	mov		tmp, myOri
	or		tmp, myCol
	swap	tmp
	sbic	mySet,copRec
	rcall	usi_putch
	rcall	Send   ; we send only upper 4 bits
;	ori		tmp, 0x0B
;	rcall	USI_putch

lopPre8:	; check usi Input
	cp		XL, XH
	breq	lop
; get and evl char in tmp
	rcall	USI_GetCh
	cpi		tmp, 'a'   	;one analog conversion
	brne	no_a
;
	sbi		mySet, anaRaw 
	sbi		ADCSRA, ADSC ; start conversion	
;Wait until EOC
Convert2a:
	sbic	ADCSRA, ADSC ; is one during conversion
	rjmp	Convert2a
	in		tmp, ADCH 
	cbi		mySet, anaRaw ; leave raw mode
	rcall	USI_putCH
	rjmp	lop
no_a:
	cpi		tmp, 'b'		; send BB
	brne	no_b
	ldi		tmp,0xBB
	rcall	USI_putCH
	rcall	Send
	rjmp	lop
no_b:

	cpi		tmp, 'c'      	;cyc
	brne	no_c
	sbi		mySet,cycMod
	rjmp	lop
no_c:
	cpi		tmp, 'C'		; cyc
	brne	no_cc
	cbi		mySet,cycMod
	rjmp	lop
no_cc:

	cpi		tmp, 'd'
	brne	no_d
	cbi		mySet, anaDau
	ldi		anaCnt, 60
	rjmp	lop
no_d:
	cpi		tmp, 'D'
	brne	no_dd
	sbi		mySet, anaDau
	ldi		anaCnt, 60
	rjmp	lop
no_dd:

	cpi		tmp, 'f'		; transfer feld
	brne	no_f
	rcall	SendFeld
	rjmp	lop
no_f:

	cpi		tmp, 'g'		; transfer feld
	brne	no_g
	ldi		tmp,colG
	mov		setCol,tmp
	rjmp	lop
no_g:

	cpi		tmp, 'k'
	brne	no_k
	cbi		mySet, copRec
	rjmp	lop
no_k:
	cpi		tmp, 'K'
	brne	no_kk
	sbi		mySet, copRec
	rjmp	lop
no_kk:

	cpi		tmp, 'm'		; anaMes
	brne	no_m
	cbi		mySet, anaMes
	rjmp	lop
no_m:
	cpi		tmp, 'M'
	brne	no_mm
	sbi		mySet, anaMes
	rjmp	lop
no_mm:

	cpi		tmp, 'n'
	brne	no_n
	ldi		tmp,0   ;N=0
no_nX:
	mov		myOri,tmp
	rjmp	no_Answer
no_n:

	cpi		tmp, 'o'		;sndOff
	brne	no_o
	cbi		mySet, sndOff
	rjmp	lop
no_o:
	cpi		tmp, 'O'
	brne	no_oo
	sbi		mySet, sndOff
	rjmp	lop
no_oo:

	cpi		tmp, 'p'		;anaRw
	brne	no_p
	cbi		mySet, anaRaw
	rjmp	lop
no_p:
	cpi		tmp, 'P'
	brne	no_pp
	sbi		mySet, anaRaw
	rjmp	lop
no_pp:

	cpi		tmp, 'r'		;red
	brne	no_r
	ldi		tmp,colR
	mov		setCol,tmp
	rjmp	lop
no_r:

	cpi		tmp, 's'
	brne	no_s

	rjmp	lop
no_s:
	cpi		tmp, 'S'
	brne	no_ss

	rjmp	lop
no_ss:

	cpi		tmp, 'u'		;unknown
	brne	no_u
	ldi		tmp,colU
	mov		setCol,tmp
	rjmp	lop
no_u:

	cpi		tmp, 'v' ; send settings
	brne	no_v
	in		tmp, mySet
	rjmp	no_Answer
no_v:

	cpi		tmp, 'w'
	brne	no_w
	ldi		tmp,0   ;W=3
	rjmp	no_nX
no_w:

	cpi		tmp, '0'		; field fieldtion
	brne	no_0
	ldi		field, 0
	rjmp	FeldSet 
no_0:
	cpi		tmp, '1'
	brne	no_1
	ldi		field, 1
	rjmp	FeldSet
no_1:
	cpi		tmp, '2'
	brne	no_2
	ldi		field, 2
	rjmp	FeldSet 
no_2:
	cpi		tmp, '3'
	brne	no_3
	ldi		field, 3
	rjmp	FeldSet
no_3:
	cpi		tmp, '4'
	brne	no_4
	ldi		field, 4
	rjmp	FeldSet
no_4:
	cpi		tmp, '5'
	brne	no_5
	ldi		field, 5
	rjmp	FeldSet
no_5:
	cpi		tmp, '6'
	brne	no_6
	ldi		field, 6
	rjmp	FeldSet
no_6:
	cpi		tmp, '7'
	brne	no_7
	ldi		field, 7
	rjmp	FeldSet
no_7:						
	cpi		tmp, '8'		;NOP
	brne	no_8

	rjmp	no_Answer 
no_8:
	cpi		tmp, '9'		;NOP
	brne	no_9

	rjmp	no_Answer 
no_9:

; done
	rjmp lop

; after changing 
FeldSet:
; set field
	tst		setCol
	breq	FeldSet1
	ldi		zl,FeCol
	add		zl,field
	st		Z,setCol
	clr		setCol
FeldSet1:
	sbic	mySet,copRec
	rcall   SendFeld
	rcall   FeldWahl
	rjmp	lop
no_Answer:
	rcall	USI_Putch

	rjmp	lop

SendFeld:
; sends field contents F and C
	ldi		tmpL,fldMax
	ldi		zl,FeBck
	add		zl,tmpL
SendFeld1:
	mov		tmp, tmpL
	ori		tmp, 0xF0
	dec     tmp		; real field nummber
	rcall   USI_putch
	ld		tmp, -z
	rcall   USI_putch
	dec		tmpL
	brne 	SendFeld1

	ldi		tmpL,fldMax
	ldi		zl,FeCol
	add		zl,tmpL
SendFeld2:
	ld		tmp, -z
	ori		tmp,0xC0
	rcall   USI_putch
	dec		tmpL
	brne 	SendFeld2
	ret


FeldNext: ;selects next field
; old values
	ldi		zl,FeBck
	add		zl,field
; delta ?
	ld		tmpL,Z
	cp		tmpL, evaRes
	breq	FeldNext1
	st		Z,evaRes
	mov		tmp,field
	ori		tmp,0xF0   ;field number 
	rcall	usi_putch
	mov		tmp, tmpL  ; old
	rcall	usi_putch
	mov		tmp, evaRes	;new
	rcall	usi_putch

FeldNext1:
	inc		field
	cpi		field, fldMax
	brne	FeldNext5
	clr		field
;performance
	mov		tmp,total
	rcall	usi_putch
	clr		total
FeldNext5:

FeldWahl:
	ldi		zl,FeCol
	add		zl,field
	ld		myCol,Z

; sets field ports
	sbi		fe0Prt, fe0Num		
	sbrs	field,0
	cbi		fe0Prt, fe0Num		
	sbi		fe1Prt, fe1Num		
	sbrs	field,1
	cbi		fe1Prt, fe1Num		
	sbi		fe2Prt, fe2Num		
	sbrs	field,2
	cbi		fe2Prt, fe2Num		
	sbi		fe3Prt, fe3Num		
	sbrs	field,3
	cbi		fe3Prt, fe3Num		
;
	ldi		evaRes, 0xEE   ;evaluating
	; select ori last used
	ldi		zl,FeBck
	add		zl,field
	ld		tmp, Z
	dec		tmp ; is incr later
	andi	tmp,0x03
	mov		myOri,tmp
	ldi		tmp,4
	mov		oriCnt,tmp
	ldi		tmp, 32 ; for one field snd 4x5+wait
	mov		cycCnt,tmp

	ret

Select:
; led in field depending on selec
	sbi		ld0Prt, ld0Num		;odd = no output
	sbi		ld1Prt, ld1Num		
	sbrs	myOri,0
	cbi		ld1Prt, ld1Num		

	sbi		ld2Prt, ld2Num		
	sbrs	myOri,1
	cbi		ld2Prt, ld2Num		

	cbi		ld0Prt, ld0Num			
	ret



Eval:
; called after incoming data available
	mov     tmp,inData
	cbi	    myGP,inDataValid
;   evaluate incoming values #TODO: validate
	sbic	mySet,copRec
	rcall	USI_putCH
; store value into Feld(field)
	mov		evaRes, tmp

;	cpi		tmp, 0xDD  ; alive start scan
;	brne    Eval_Snd
;	ldi		tmp,4
;	mov		oriCnt, tmp
;	ret
	
Eval_Snd:
; store Ori recved
	andi	tmp, 0x03
	mov		rcvOri, tmp
	swap    tmp
	ori		tmp,0x0A
	mov		tmp,cycCnt
	clr		cycCnt  ; next to scan
	sbi		myGP, stopSnd
; 
; performance
;	rcall	usi_putch
Eval_x:
	ret


;**************** 
Send:
; snd via Signlak, no checking!
	mov 	sndByte,tmp		 
	ldi		sndBit,5    ;number of bits to snd+1
	ret

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

;**************** 
Tim0_CompA:
; does sending et al
; bitcnt on entry 
;   0		return, possible to snd new data
;   1       don't set out (EOByte)
;   2..x    set out       
;
	in   	sregS, SREG	
	push 	tmp
; Determine what to snd 
	tst    	sndBit
	breq   	Tim0_CompA_Nix
; set OCR0B to dur0 or dur1
	ldi		tmp, dur0
	lsl		sndByte
	brcc    Tim0_CompAS2		
	ldi		tmp, dur1
Tim0_CompAS2:
	out 	OCR0B, tmp
	dec     sndBit
	tst		sndBit 
	breq    Tim0_CompA_Nix
	cbi		ld0Prt, ld0Num ;Signal On
Tim0_CompA_Nix:
; Misc business counters downto 0:
	tst		cycCnt
	breq 	Tim0_CompA_Nix3
	dec		cycCnt
Tim0_CompA_Nix3:			
	inc		total
Tim0_CompA_Nix5:
	pop		tmp
	out		SREG,sregS
	reti

;**************** 
Tim0_CompB:
; switch off
	in   	sregS, SREG	
	sbis	mySet, sndOff    
 	sbi		ld0Prt, ld0Num ;Signal Off
;	sbis	myGP, stopSnd
;	rjmp	Tim0_CompB_Done
;	ldi		sndBit,1
;	cbi		myGP, stopSnd
Tim0_CompB_Done:
	out		SREG,sregS
	reti

;**************** 
Tim1_CompA:
;trigger Analog conversion and evaluate results
;sig
;nosCnt   x        0  1  2
; on Ex   0  0  0  1  2  3...
;sigCnt   0  0  1  2
; on Ex   0  1  2  0  0  0  0
;Sample   |  |  |  |  |  |  |
;          +-----+
;Signal----+     +-|-------------
;received  --+              +---
;            +-----|--------+            
;
;            A     B        C
; A flank to Sig, clear received
; B flank to Nosig, move bit to inbyte
; C EOByte store to dataIn,  clear inbyte, set received
	in   	sregS, SREG	
	tst		anaCnt
	breq 	Tim1_CompA9
; 
	push	tmp
	in		tmp, ADCH 
	sbi		ADCSRA, ADSC ; start again
; Dauerfeuer?
	sbis	mySet, anaDau
	dec		anaCnt
; either store values or calculate duration
	sbis	mySet, anaRaw
	rjmp	Tim1_CompA_Calc
; raw values just store
	mov		mesDur,tmp
	rjmp 	Tim1_CompA_Done

Tim1_CompA_Calc:
; if below, consider it Signal
	cpi		tmp, limLow
	brlo	Tim1_CompA_Sig
; no signal. if previous was signal, tell duration
	tst		sigCnt
	breq	Tim1_CompA_Calc1
; flank Sig->NoSig (B)
	mov		tmp, sigCnt
; shift byte
	cpi		tmp, rcv0
; carry set if < rcv0
	rol     inByte
	sbic	mySet, anaMes
	mov		mesDur, sigCnt
	clr		sigCnt
Tim1_CompA_Calc1:
	inc		nosCnt
; assume end of byte after 
	ldi		tmp, rcvEOB 
	cp		nosCnt,tmp
    brne    Tim1_CompA_Done
; no signal, return first   (C)
	sbic    myGP, received 
	rjmp	Tim1_CompA_Done
	sbi		myGP, received 
	mov		inData, inByte
	sbi		myGP, inDataValid 
	clr		inByte
Tim1_CompA_Done:
	pop		tmp
Tim1_CompA9:			
	out		SREG,sregS
	reti
; signal   
Tim1_CompA_Sig:	
	inc		sigCnt
	tst		nosCnt
	breq	Tim1_CompA_Done
; flank NoSig->Sig (A)
	clr		nosCnt
	cbi		myGP, received
	rjmp	Tim1_CompA_Done




Tim0_Setup: 
; Normal Port Operation ,Mo  W2 W1 W0
;                         2  0  1  0 CTC         OCRA Immediate MAX  

	ldi tmp, (0<<COM0A1)+(0<<COM0A0)+(0<<COM0B1)+(0<<COM0B0)+(1<<WGM01)+(0<<WGM00)
	out		TCCR0A, tmp
; Clock from Prescaler / 1024
;CS12 CS11 CS10 for tim1  should be less than tim0!
;CS02 CS01 CS00 for tim0
; 0    0    0    No clock source (Timer/Counter stopped)
; 0    0    1    clkI/O/(No prescaling)
; 0    1    0    clkI/O/8 (From prescaler)
; 0    1    1    clkI/O/64 (From prescaler)    ->tim1
; 1    0    0    clkI/O/256 (From prescaler)   ->tim0
; 1    0    1    clkI/O/1024 (From prescaler)
; 1    1    0    External clock source on T0 pin. Clock on falling edge.
; 1    1    1    External clock source on T0 pin. Clock on rising edge.
; 
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(1<<CS02)+(0<<CS01)+(0<<CS00)
	out     TCCR0B, tmp
; Top 
	ldi 	tmp, durTot
	out 	OCR0A, tmp
; Compare
	ldi tmp, 0xFF
	out 	OCR0B, tmp
; Interrupt Enable 
	ldi tmp, (1<<OCIE0B)+(1<<OCIE0A)+(0<<TOIE0)
	out     TIMSK0, tmp
	ret


Tim1_Setup: 
; Normal Port, WGM 13 12 11 10
;                   0  1  0  0 CTC         OCRA Immediate MAX  

	ldi tmp, (0<<COM1A1)+(0<<COM1A0)+(0<<COM1B1)+(0<<COM1B0)+(0<<WGM11)+(0<<WGM10)
	out		TCCR1A, tmp
; 
; CS1x and WGM see above
	ldi tmp, (0<<WGM13)+(1<<WGM12)+(0<<CS12)+(1<<CS11)+(1<<CS10)+(0<<ICNC1)+(0<<ICES1)
;	tst debug
;	breq Tim1_Setup1
;   debug sets clock 
;	ldi tmp, (0<<WGM13)+(1<<WGM12)+(0<<CS12)+(0<<CS11)+(1<<CS10)+(0<<ICNC1)+(0<<ICES1)
Tim1_Setup1:
	out     TCCR1B, tmp
; Top, write Hi first
	ldi 	tmp, durTim1
	clr		tmpH
	out 	OCR1AH, tmpH
	out 	OCR1AL, tmp
; Compare
	out 	OCR1BH, tmpH
	out 	OCR1BL, tmp

; Interrupt Enable 
	ldi tmp, (0<<OCIE1B)+(1<<OCIE1A)+(0<<TOIE1)
	out     TIMSK1, tmp
	ret


;****************
ADC_Setup:  ;Single conversion mode
; REFS1 REFS0 Voltage Reference fieldion
;   0     0   VCC used as analog reference, disconnected from PA0 (AREF)
;   0     1   External voltage reference at PA0 (AREF) pin, internal reference turned off
;   1     0   Internal 1.1V voltage reference
; MUX5:0 
; 000000 ADC0 (PA0) 
; 000111 ADC7 (PA7)
; 100000   0V (AGND)
; 100001 1.1V (I Ref)
; 100010 ADC8 (temp)
	ldi		tmp, (0<<REFS1)+(0<<REFS0)+(1<<MUX2)+(1<<MUX1)+ (1<<MUX0)
	out		ADMUX,tmp
;ADCSRB 
; BIN: Bipolar Input Mode
; ACME: Analog Comparator Multiplexer Enable
; ADLAR: ADC Left Adjust Result
; ADTS2:0: ADC Auto Trigger Source requires  ADATE in ADCSRA is written to one!
; 0 0 0   Free Running mode
; 0 0 1   Analog Comparator
; 0 1 0   External Interrupt Request 0
; 0 1 1   Timer/Counter0 Compare Match A
; 1 0 0   Timer/Counter0 Overflow
; 1 0 1   Timer/Counter1 Compare Match B
; 1 1 0   Timer/Counter1 Overflow
; 1 1 1   Timer/Counter1 Capture Event
	ldi		tmp, (1<<ADLAR)+(0<<ADTS2)+(0<<ADTS1)+(0<<ADTS0)
	out		ADCSRB,tmp
; ADPS2:0: ADC Prescaler field Bits
; 0 0 0   2
; 0 0 1   2
; 0 1 0   4
; 0 1 1   8
; 1 0 0  16
; 1 0 1  32
; 1 1 0  64
; 1 1 1 128
; warm up AD:    ADC Enable  Start Conv   IntEn     
	ldi		tmp, (1<<ADEN) + (1<<ADSC) + (0<<ADPS2) + (0<<ADPS1) + (0<<ADPS0)
	out		ADCSRA,tmp
	ret

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
	ldi	XL, BufX
	mov	XH, XL
	ldi	YL, BufY
	mov	YH, YL
	clr	ZH
	ldi tmp,(1<<USIOIF)
	out USISR,tmp


	ret


ExtInt_Setup:
;   GIMSK
;	INT0: External Interrupt Request 0 Enable 
;   PCIE1: Pin Change Interrupt Enable 1   PCINT11:8 pins are enabled by PCMSK1
;   PCIE0: Pin Change Interrupt Enable 0    PCINT7:0 pins are enabled by PCMSK0
	ldi tmp, (0<< INT0)+(1<< PCIE1)+(0<<PCIE0)
	out GIMSK, tmp
;   PCMSK?
	ldi tmp, (1<< PCINT9)
	out PCMSK1, tmp
	ret
; Fuses: default
; Ports: 
; PA0
; PA1
; PA2
; PA3
; PA4 SCK
; PA5 MISO
; PA6 MOSI
; PA7 BuYe
; PB2 BuBl
; PB1
; PB0

