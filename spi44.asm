;*************************************************************************
; Test Program SPI     anaDau  raw
; blu  sample cont     set 1
; yel  sample anaCnt   set 0
; 'g'  count                   set 0
; 'a'  raw data                set 1
; W    indicates analog sampling
; E    indicates data to send
; N    is sender (tbd)
; CPU should be 1 MHz (CKSEL = 0010, CKDIV8 programmed)
; Timer 0 CTC controls sending and other stuff with clkI/O/256
; Timer 1 CTC controls receiving, clkI/O/64 compared to Timer 0
; Descr see bottom
;*************************************************************************
.NOLIST
.include "tn44def.inc"
.LIST

; Constants
.equ    anaSamp    	=   0x80   	; number of samples
.equ    dur1       	=    8   	; OCR0B to send 0
.equ    dur0       	=   16   	; OCR0B to send 1
.equ    durTot		=   24   	; OCR0A time 
.equ    durTim1		=   12 		; Timer 1 OCR1A to sample 4*(durTot/durTim1) times per bit
; receiver 
.equ	limLow		=  0x80		; Analog below this value considered Signal
.equ    rcv0	    =    4		; if signal dur below consider 0 else 1
.equ    rcvEOB 	 	=    8      ; if nosignal longer than this consider eobyte

; register usage
.def	debug		= R0	; debug mode if not 0
.def	myCol		= R1	; my color
.def	inCol		= R2	; incoming
.def	myOri		= R3	; my Ori
.def	inOri		= R4	; 
.def    butCnt      = R5
.def	sndCnt		= R6	; if <> 0 send 
.def	inDataSin	= R7	; set to xx if inData received, dec during timer0
.def	inData  	= R8	; contains incoming Data if inDataValid
.def	inByte		= R9	; incoming Byte built by tim1
.def	sigCnt		= R10	; count of signal duration
.def	nosCnt		= R11   ; count of no Signal duration
;.def	AdVal3	 	= R12	; 
;.def	cntOn	 	= R13	; 
;.def	cntOn	 	= R14	; 
.def	sregS		= R15	; saves status during interrupt
.def 	tmp 		= R16   ; general usage, not preserved
.def	tmpL		= R17   ;
.def	tmpH		= R18   ;
.def	mesDur		= R19	; Duration of signal
.def	sndBit		= R20	; Bit which is currently sent 8..1, 0=nosend
.def	sndByte		= R21	; Byte which is currently sent
.def	mesRise		= R22	; Timer value at rising 
;.def	butCnt		= R23	; 
;.def	butCnt		= R24	; 
.def	anaCnt		= R25	; Counter analog 
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
BufYEnd:	.Byte 2
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
	

;Out Leds NESW
;
.equ 	shNNum		=   2
.equ 	shNPrt		=	PORTA
.equ 	shNPin		=	PINA
.equ 	shNDir		=	DDRA

.equ 	shENum		=   1
.equ 	shEPrt		=	PORTA
.equ 	shEPin		=	PINA
.equ 	shEDir		=	DDRA
;
;.equ 	shSNum		=   5
;.equ 	shSPrt		=	PORTA
;.equ 	shSPin		=	PINA
;.equ 	shSDir		=	DDRA

.equ 	shWNum		=   3
.equ 	shWPrt		=	PORTA
.equ 	shWPin		=	PINA
.equ 	shWDir		=	DDRA

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


; In Analog 0
.equ 	anaNum		=   0
.equ 	anaPrt		=	PORTA
.equ 	anaPin		=	PINA
.equ 	anaDir		=	DDRA

;Incoming Buttons
.equ 	buYeNum		=   7
.equ 	buYePrt		=	PORTA
.equ 	buYePin		=	PINA
.equ 	buYeDir		=	DDRA

.equ 	buBlNum		=   2
.equ 	buBlPrt		=	PORTB
.equ 	buBlPin		=	PINB
.equ 	buBlDir		=	DDRB

; Pinchange Int
.equ 	mesNum		=   1
.equ 	mesPrt		=	PORTB
.equ 	mesPin		=	PINB
.equ 	mesDir		=	DDRB

; GPIO use sbi cbi sbis sbic 
.equ	myGP	= GPIOR0	; flag register for Ribus
.equ	USIdirect 	= 7 	; 1 if data in USI,		0 if no data
.equ	raw 		= 6		; 1 to store raw data,	0 to count signal
.equ	anaDau		= 5     ; 1 to sample contin, 	0 to sample anaCnt
.equ	received	= 4     ; 1 data in  	
.equ    inDataValid = 3     ; 1 if inData
;.equ     		= 2         ;



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
    PortOut shNNum, shNDir, shNPrt
	PortOut shENum, shEDir, shEPrt
;	PortOut shSNum, shSDir, shSPrt
	PortOut shWNum, shWDir, shWPrt
	PortOut DO_Num, DO_Dir, DO_Prt

    PortInP DI_Num, DI_Dir, DI_Prt
    PortInP sckNum, sckDir, sckPrt
    PortInP buYeNum, buYeDir, buYePrt
    PortInP buBlNum, buBlDir, buBlPrt
    PortInP MesNum, MesDir, MesPrt
    PortInP anaNum, anaDir, anaPrt
; configure 
	rcall 	ADC_Setup
	rcall 	USI_Setup
	rcall 	Tim0_Setup
	rcall 	Tim1_Setup
;	rcall ExtInt_Setup  ; remove if not dbg

	clr	  	debug
	cbi		myGP, USIdirect
	cbi		myGP, raw
	sbi		myGP, anaDau
	ldi		anaCnt, 0x80
	sei ; Enable interrupts

start:
	ldi tmp, '?'


lop:	
; check messages from ints
	tst		mesDur
	breq	lopPre1
	rcall	StoreMes

lopPre1:   	; check incoming data from Signal
	sbic	myGP,inDataValid
	rcall	Eval

lopPre3:   	; check buttons, but only once every Butcnt
	tst		debug      ;
	brne	lopPre5
	tst		butCnt
	brne	lopPre5
	sbis	buBlPin, buBlNum
	rjmp	dobuBl
	sbis	buYePin, buYeNum
	rjmp	dobuYe
lopPre5:	; check Dauersend
	tst		sndCnt
	breq	LopPre7
	tst    	sndBit
	brne	LopPre7
	ldi		tmp, 0xAA
	dec		sndCnt
	rcall	send
lopPre7:	; LED E indicates data for USI
lopPre8:	; check usi Input
	cp		XL, XH
	breq	lop
; get and eval char in tmp
	rcall	USI_GetCh

	cpi		tmp, 'a'   	;one analog conversion
	brne	lop_a
;
	sbi		myGP, raw 
	sbi		ADCSRA, ADSC ; start conversion	
;Wait until EOC
Convert2a:
	sbic	ADCSRA, ADSC ; is one during conversion
	rjmp	Convert2a
	in		tmp, ADCH 
	rcall	USI_putCH
	rjmp	lop
lop_a:
	cpi		tmp, 'b'
	brne	lop_b
	ldi		tmp,0xBB
	rcall	Send
	rjmp	lop
lop_b:
	cpi		tmp, 'c'
	brne	lop_c
	ldi		tmp,0xAA
	rcall	Send
	rjmp	lop
lop_c:
	cpi		tmp, 'd'   ;DauerSend
	brne	lop_d
	ldi		tmp,0x80
	mov		sndCnt,tmp
	rjmp	lop
lop_d:
	cpi		tmp, 'g'
	brne	lop_g
	cbi		myGP, raw 
	ldi		anaCnt, 60
	ldi		tmp,0xCC
	rcall	USI_putCH
	rjmp	lop
lop_g:
.include "lop.asm"

; done
	rjmp lop

Eval:
; called after incoming data available
	mov     tmp,inData
	cbi	    myGP,inDataValid
;   evaluate incoming values #TODO: validate
	rcall	USI_putCH
	cpi		tmp, 0xDD
	breq	Eval_X

	cpi		tmp, 0x04
	brne	Eval_no4
	rjmp	Eval_snd
Eval_No4:
	rjmp	Eval_x
Eval_Snd:
; build new out from myOri and myCol
	mov		tmpL, myCol
	swap	tmpL
	lsl 	tmpL
	lsl 	tmpL
	mov		tmp, myOri
	or		tmp,tmpL
	rcall   	Send
	ori		tmp, 0x0C
	rcall	usi_putch
Eval_x:
	ret

	
dobuYe:
; Button yellow pressed
	cbi		myGP, anaDau
dobuts_xx:
	ldi		anaCnt, 8 ; get n samples
	push	tmp
	ldi		tmp, 0x80
	mov		ButCnt,tmp
	clr		sndCnt
	pop		tmp
dobuts_back:
	rjmp lopPre5

dobuBl:
; Button blue pressed, 
	sbi		myGP, anaDau
	rjmp	dobuts_xx

;**************** 
Send:
; send via Signlak, no checking!
	mov 	sndByte,tmp		 
	ldi		sndBit,5    ;number of bits to send+1
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
; Put Output (YL+) if nothing to send put ?
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
	sbi		myGP, USIdirect  ; we have something to send in the buffer
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
;   0		return, possible to send new data
;   1       don't set out (EOByte)
;   2..x    set out       
;
	in   	sregS, SREG	
	push 	tmp
; Determine what to send 
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
	sbi		shNPrt, shNNum ;Signal On
Tim0_CompA_Nix:
; Misc business counters downto 0:
	tst		butCnt
	breq 	Tim0_CompA_Nix3
	dec		butCnt
Tim0_CompA_Nix3:			
	tst		inDataSin
	breq 	Tim0_CompA_Nix5
	dec		inDataSin
Tim0_CompA_Nix5:
	pop		tmp
	out		SREG,sregS
	reti

;**************** 
Tim0_CompB:
; switch off
	in   	sregS, SREG	
 	cbi		shNPrt, shNNum ;Signal Off
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
;   check dauer
	sbis	myGP, anaDau
	dec		anaCnt
; either store values or calculate duration
	sbis	myGP, raw
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
; REFS1 REFS0 Voltage Reference Selection
;   0     0   VCC used as analog reference, disconnected from PA0 (AREF)
;   0     1   External voltage reference at PA0 (AREF) pin, internal reference turned off
;   1     0   Internal 1.1V voltage reference
; MUX5:0 
; 000000 ADC0 (PA0) 
; 000111 ADC7 (PA7)
; 100000   0V (AGND)
; 100001 1.1V (I Ref)
; 100010 ADC8 (temp)
	ldi		tmp, (0<<REFS1)+(0<<REFS0)+(0<<MUX2)+(0<<MUX1)+ (0<<MUX0)
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
; ADPS2:0: ADC Prescaler Select Bits
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

