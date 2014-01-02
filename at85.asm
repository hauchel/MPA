;*************************************************************************
; Attiny x5 Blink
; Fuse Bytes:
;           7 6 5 4 3 2 1 0
; Extended 						FF
; Highfuse  1 1 0 1 0 1 0 1  	D5   SPIEN, EESAVE, BODLEVEL 2.7
; LowFuse                  		62 
;*************************************************************************
.NOLIST
.include "tn85def.inc"
.LIST
.LISTMAC

; Sender controlled by Tim0
.equ    dur1       	=    8   	; OCR0B to send 0
.equ    dur0       	=   16   	; OCR0B to send 1
.equ    durTim0		=   24   	; OCR0A bit time frame appr 162 Hz for 1Mhz and clk /256 (3,906 Khz)
.equ    cnt0Top     =   0x20    ; slow clock sets gpio1 flags
.equ    bits2Snd	=	 9		; send these -1, MSB first
; Receiver controlled by Tim1
.equ    durTim1		=   12 		; Timer 1 OCR1A to sample 8 times per bit(4*durTim0/durTim1)
.equ	limLow		=  0x90		; Analog below this value considered Signal
.equ    rcv0	    =    4		; if signal dur below consider bit received 0 else 1
.equ    rcvEOB 	 	=    8      ; if no signal longer than this consider eobyte
;Misc
.equ    anaSamp    	=   0x80   	; number of samples in Bufer
.equ	stateMax     =   15      ; number of supported States-1 (0..stateMax)
; register usage
.def	debug		= R0		; running in Simulator if not 0
.def	myCol		= R1		; my color
.def	inCol		= R2		; incoming
.def	myOri		= R3		; my Ori
.def	inOri		= R4		; 
.def    LedCnt		= R5		; 
;.def    			= R6		; 
;.def				= R7		; set to xx if inData received, dec during timer0
.def	inData  	= R8		; contains incoming Data if inDataValid
.def	inByte		= R9		; incoming Byte built by tim1
.def	sigCnt		= R10		; count of signal duration
.def	nosCnt		= R11   	; count of no signal duration
;.def			= R12   	; count of no signal duration
;.def			 	= R13		; 
.def	cnt0	 	= R14		; decremented during tim0
.def	sregS		= R15		; saves status during interrupt
.def 	tmp 		= R16   	; general usage, not preserved
.def	state		= R17		; Current state
.def	anaCnt		= R18		; 
.def	mesDur		= R19		; Current value to transmit for debg
.def	sndBit		= R20		; Bit which is currently sent 8..1, 0=nosend
.def	sndByte		= R21		; Byte which is currently sent
.def	nacCnt		= R22		; no activity
;.def	  			= R23		; set to xx if button pressed, dec during timer0
.def	tmpL		= R24   	; upper 4 register pairs
.def	tmpH		= R25   	;
; XL				= R26 		; index to access buffer
; XH				= R27		; must be zero at all times
; YL				= R28   	; sendBuffer in
; YH				= R29		; sendBuffer out 
; ZL				= R30       ; 
; ZH				= R31	    ;

;Data Segment	
.dseg
.org SRAM_START
Buf:		.BYTE anaSamp	  ;Output Buffer
BufEnd:	.Byte 2
LedSet: .Byte 1				; 0xab = a on time b off time 

;Code Segment	
.cseg
; interrupt Jump Table attiny 85
	.org 0x0000
 	rjmp RESET 					;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
	reti; 		rjmp INT0 		;  2 External Interrupt
	reti;	rjmp PCINT0_Handler			;  3 PCINT0 Handler
	reti; 		rjmp TIM1_COMPA ;  4 Timer1 Compare Match A 
	reti;		rjmp TIM1_OVF 	;  5 Timer1 Overflow Handler
	reti;		rjmp TIM0_OVF 	;  6 Timer0 Overflow Handler
	reti; 	 	rjmp EE_RDY 	;  7 EEPROM Ready Handler
	reti; 		rjmp ANA_COMP 	;  8 Analog Comparator Handler
	reti; 		rjmp ADC	 	;  9 Analog Conversion Complete
	rjmp Tim1_CompB				; 10 Timer1 Compare Match B
	rjmp Tim0_CompA				; 11 Timer0 Compare Match A
	rjmp Tim0_CompB				; 12 Timer0 Compare Match B
	reti; 		rjmp WDT	 	; 13 WDT Watchdog Time-out
	reti;		rjmp USI_START  ; 14 USI Start
	reti;		rjmp USI_OVF    ; 15 USI Overflow
	


;Ports
; LED vs GND with 0k2
.equ 	sh0Num		=   0
.equ 	sh0Prt		=	PORTB
.equ 	sh0Pin		=	PINB
.equ 	sh0Dir		=	DDRB
; Send LED vs GND with 0k2
.equ 	sh1Num		=   1
.equ 	sh1Prt		=	PORTB
.equ 	sh1Pin		=	PINB
.equ 	sh1Dir		=	DDRB
; ADC 1 for SFH309 vs GND with 4k7 pup
.equ 	anaNum		=   2         
.equ 	anaPrt		=	PORTB
.equ 	anaPin		=	PINB
.equ 	anaDir		=	DDRB
; Button Yellow 1k vs GND sets state to 0
.equ 	buYeNum		=   3
.equ 	buYePrt		=	PORTB
.equ 	buYePin		=	PINB
.equ 	buYeDir		=	DDRB
; Button Blue  1k vs GND incs state
.equ 	buBlNum		=   4
.equ 	buBlPrt		=	PORTB
.equ 	buBlPin		=	PINB
.equ 	buBlDir		=	DDRB


; GPIO use sbi cbi sbis sbic 
.equ	myGP	= GPIOR0		; 
.equ	USIdirect 	= 7 		; 1 if data in USI,		0 if no data
.equ	anaRaw 		= 6			; 1 to store raw data,	0 to eval signal
.equ	anaDau		= 5     	; 1 to sample contin, 	0 to sample and dec anaCnt
.equ	received	= 4     	; 1 data in  	
.equ    inDataValid = 3     	; 1 if inData is valid
.equ    anaMes      = 2         ; 1 to return count of signal  

.equ	myCn0		= GPIOR1    ; all flags are set on cnt0 , must be reset by code using it 
.equ    cn0Led      = 7         ; Led
.equ    cn0Nac      = 6         ; No data received
.equ    cn0But      = 5         ; Button

.macro PortOut ; Num Dir Prt as output to zero
	sbi @1, @0
	cbi @2, @0
.endmacro
.macro PortInP ; Num Dir Prt as input with Pup
	cbi @1, @0
	sbi @2, @0
.endmacro
.macro Blink
	push	tmp
	ldi		tmp,@0
	sts		ledSet,tmp
	pop		tmp
.endmacro
; Start set to 0x20
	.org 0x0020
RESET:
;here we go:
	ldi tmp, low(RAMEND)
	out SPL,tmp
	ldi tmp, high(RAMEND)
	out SPH,tmp 
	clr	debug
;	inc	debug	;REMOOOOOOOOOOOOOOOOVE

; eval MCUSR
;  WDRF: Watchdog Reset  is reset by a Power-on Reset, or by writing 0
;  BORF: Brown-out Reset is set if a Brown-out Reset occurs. reset by a Power-on Reset, or by writing 0
;  EXTRF:External Reset  is set if an External Reset occurs. reset by a Power-on Reset, or by writing 0
;  PORF: Power-on Reset  is set if a Power-on Reset occurs.  reset only by writing a logic zero to the flag.
; seems simulator does not set this
	in		tmp,MCUSR
; no idea who or what i am
	clr	myCol
	inc myCol ;unknown
	clr	myOri

; set up Buffer
	ldi	YL, Buf
	mov	YH, YL
	clr	XH

; configure Ports outgoing to zero
	PortOut sh0Num, sh0Dir, sh0Prt
	PortOut sh1Num, sh1Dir, sh1Prt
; configure Ports incoming PullUp
    PortInP buYeNum, buYeDir, buYePrt
    PortInP buBlNum, buBlDir, buBlPrt
	PortInP anaNum,  anaDir,  anaPrt

; configure 
	rcall 	Tim0_Setup
	rcall 	Tim1_Setup
	rcall	ADC_Setup
	clr		state

 
start:
	tst	debug
	brne start_debug
	rjmp	start_1
start_debug:


start_1: ; Normalbetrieb
	ldi     State,8
	clr 	tmp
	out		myCn0,tmp  ;reset all cn0
	ldi		tmp,1
	mov		cnt0,tmp
	mov     ledCnt,tmp
	sei ; Enable interrupts

lop:	
; check if debug data to store
	tst		mesDur
	breq	lopPre1
	mov		tmp, mesDur
	clr		mesDur
	rcall	PutCh
lopPre1: ; check incoming Signal
	sbic	myGP,inDataValid
	rcall	Eval
; Try to send
	rcall	CheckSend
; check if button Pressed
	sbic	myCn0, cn0But
	rcall   DoBut
; handle indicator LED
	sbic	myCn0, cn0Led
	rcall	DoLed
; handle alert
	sbic	myCn0, cn0Led
	rcall	DoLed
; handle nacs
	sbic	myCn0, cn0Nac
	rcall	DoNac

;Branch depending on state
	mov		tmp, state
;    subi    tmp,0        			;minimum Entry
;    cpi     tmp,(stateMax-0+1)   	;check max
;    brsh    StatX            		;-> err #TODO:check
    ldi     ZL,low(StatJmpTab)      ;
    ldi     ZH,high(StatJmpTab)
    add     ZL,tmp            		;add index
    clr     tmp
    adc     ZH,tmp
    ijmp                        	;indirect to StatJmpTab

StatJmpTab:
    rjmp    Stat0
    rjmp    Stat1
    rjmp    Stat2
    rjmp    Stat3
    rjmp    Stat4
    rjmp    Stat5
    rjmp    Stat6
    rjmp    Stat7
    rjmp    Stat8
    rjmp    Stat9
	rjmp    Stat10
	rjmp    Stat11
	rjmp    Stat12
	rjmp    Stat13
	rjmp    Stat14
	rjmp    Stat15
StatX:								; Exit
	rjmp 	lop
StatSend:
	rcall	PutCh	
	rjmp	StatX

Stat0: ; Button Yellow resets and jumps to 1
	clr		anaCnt
	cbi 	myGP, anaDau
    cbi		myGP, anaRaw
	cbi		myGP, anaMes
	ldi		YL, Buf
	mov		YH, YL
	clr		XH
	Blink	0x11
	ldi		tmp,0xCC
	inc		state
	rjmp	StatSend
Stat1:  ; send tmpL bytes then goto Stat2
	ldi 	tmpL, 5
	ldi		tmp, 0x88
	ldi		tmpH, 0x11
Stat1_1:
	rcall	PutCh
	add 	tmp, tmpH
	dec		tmpL
	brne	Stat1_1
	inc		state
	rjmp	StatX
Stat2:  ; 
	blink	0x12
	rjmp	StatX
Stat3:	;   send raw
	blink   0x14
	ldi		anaCnt, anaSamp
	cbi 	myGP, anaDau
    sbi		myGP, anaRaw
	cbi		myGP, anaMes
	inc     state
	rjmp	StatX
Stat4:
	rjmp	StatX
Stat5:   ;  send data with mes
	ldi		anaCnt, anaSamp
	sbi		myGP, anaMes
Stat5a:
	ldi		anaCnt, anaSamp
	sbi 	myGP, anaDau
    cbi		myGP,anaRaw
	inc     state
	rjmp	StatX
Stat6:
	rjmp	StatX
Stat7:
	inc		state
	rjmp	StatX
Stat8:;Normalbetrieb Entry 
	ldi		anaCnt, 0x80
	sbi 	myGP, anaDau
    cbi		myGP, anaRaw
    cbi		myGP, anaMes
	blink   0x11
	inc		state
	rjmp	StatX
Stat9: ; No Data received since (nacCnt is 0) send alert
	tst		nacCnt
	brne	Stat9_Nix
	tst    	sndBit
	brne   	Stat9_Nix ; Already busy
	cp		YL,YH
	brne	Stat9_Nix ; Stuff in buffer
	ldi		tmp, 0xDD
	rcall	putCh
	ldi		nacCnt,5
Stat9_Nix:	
	rjmp	StatX

Stat10: ;Data received from Brett
	rjmp	StatX
Stat11: ;
	ldi		state,9
	rjmp	StatX
Stat12: ;
	ldi		state,9
	rjmp	StatX
Stat13: ;
	ldi		state,9
	rjmp	StatX
Stat14: ;
	ldi		state,9
	rjmp	StatX
Stat15: ;
	ldi		state,9
	rjmp	StatX

;*****************
Eval:
; something received, fetch it
	mov     tmp,inData
	cbi	    myGP,inDataValid
	ldi		nacCnt, 10
; #TODO check if valid 
; act on inData, extract cc and oo
	push    tmp
	clr     inCol 
	lsl		tmp
	lsl     inCol
	lsl		tmp
	lsl     inCol 
	clr		inOri
	lsl		tmp
	lsl     inOri
	lsl		tmp
	lsl     inOri
Eval_Cmd:
Eval_Back:
; Answer back
	pop		tmp
	rcall	putch
	ret

DoBut:
;
	sbic	buYePin, buYeNum
	rjmp	doButBl
doButYe:
; Button yellow pressed:
	clr		state
	rjmp	doButDone

doButBl:
	sbic	buBlPin, buBlNum
	rjmp	DoBut_X
; Button blue pressed:
	cpi		state,stateMax
	breq	doButDone	
	inc		state
doButDone:
; reset counter flag
	cbi		myCn0, cn0But  
; send new state
	mov		tmp,state
	swap	tmp
	ori		tmp, 0x0D ; to show 0 also
	rcall	PutCh
DoBut_X:
	ret


DoLed:
; Led Counter from ledSet
	cbi		myCn0, cn0Led  
	dec		ledCnt
	brne	DoLed_X
; if on
	lds		tmp, ledSet
	sbic	sh0Prt, sh0Num
	rjmp	DoLed_S
	sbi		sh0Prt, sh0Num
	swap	tmp
	rjmp 	DoLed_All
DoLed_S:
	cbi		sh0Prt, sh0Num
DoLed_All:  ;tmp contains the applicable value in lower nibble
	andi	tmp, 0x0F
	mov		ledCnt,tmp
DoLed_X:
	ret
	
DoNac:
; Nac Counter 
	cbi		myCn0, cn0Nac  
	tst		NacCnt
	breq	DoNac_X ;already 0
	dec		NacCnt
DoNac_X:
	ret

CheckSend:
; checks if data in buffer, then sends these (YL+)
; returns Z if nothing to send
	tst    	sndBit
	brne   	Send_Nix ; Already busy
	cp		YL,YH
	breq	Send_Nix ; Nothing to send
	push	tmp			; should be unchanged
	mov		XL,YL
	ld		tmp,X+
	cpi		XL, BufEnd
	brne	Send_3
	ldi		XL, Buf
Send_3:
	mov		YL,XL
	mov 	sndByte,tmp		 
	ldi		sndBit,bits2Snd  ;
	pop		tmp
Send_Nix:
	ret

; put char in tmp into yBuf (YH+)
; as we send only 4 use lower only 
PutCh:
	mov		XL,YH
	st		X+,tmp
;if buffer is full, undo
	cp		XL,YL
	brne	PutCh3
	dec 	XL
PutCh3:
	cpi		XL,BufEnd
	brne	PutCh5
	ldi		XL, Buf
PutCh5:		; ok
	mov		YH,XL
	ret
	
Tim0_CompA:
; bitcnt on entry 
;   0		return
;   1       don't set out
;   2..x    set out 
	in   	sregS, SREG		
	push 	tmp
; Determine what to send (
	tst    	sndBit
	breq   	Tim0_CompA_Nix
; set OCR0B to dur0 or dur1
	ldi		tmp, dur0
	lsl		sndByte
	brcc    Tim0_CompA_2		
	ldi		tmp, dur1
Tim0_CompA_2:
	out 	OCR0B, tmp
	dec     sndBit
	tst		sndBit 
	breq    Tim0_CompA_Nix
	sbi		sh1Prt, sh1Num ;Signal On
		
Tim0_CompA_Nix:
; slow timer
	dec		cnt0
	brne 	Tim0_CompA_Done
	ldi		tmp,cnt0Top
	mov		cnt0,tmp
	ldi		tmp, 0xFF
	out		myCn0, tmp ;set all bits

Tim0_CompA_Done:
	pop		tmp
	out		SREG,sregS
	reti


Tim0_CompB:
; switch send of off
	in   	sregS, SREG	
	cbi	sh1Prt, sh1Num	; Signal off
	out		SREG,sregS
	reti

pcint0_Handler:			;debug only
Tim1_CompB:
;trigger Analog conversion and evaluate results
; these modes:                 
; do nothing if anaCnt=0, else
; return analog Value in mess if anaRaw=1 else
; return # of counts of signal in mess if anaEva=0  else
; evaluate
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
; A flank to Sig
; B flank to Nosig, move bit to inbyte, possibly set mesDur       
; C EOByte, store to dataIn,  clear inbyte
	in   	sregS, SREG	
	tst		anaCnt
	breq 	Tim1_CompA_Nix		;ignore
; get Analog value
	push	tmp
	in		tmp, ADCH 
	sbi		ADCSRA, ADSC ; start next conversion
; Dauerfeuer?
	sbis	myGP, anaDau
	dec		anaCnt
; either store value or calculate duration
	sbis	myGP, anaRaw
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
	sbic	myGP, anaMes
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
Tim1_CompA_Nix:			
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



Tim0_Setup: ; for x5
; Normal Port Operation ,Mo  W2 W1 W0
;                         2  0  1  0 CTC         OCRA Immediate MAX  

	ldi tmp, (0<<COM0A1)+(0<<COM0A0)+(0<<COM0B1)+(0<<COM0B0)+(1<<WGM01)+(0<<WGM00)
	out		TCCR0A, tmp
; Clock from Prescaler / 1024
;CS02 CS01 CS00 Description
; 0    0    0    No clock source (Timer/Counter stopped)
; 0    0    1    clkI/O/(No prescaling)
; 0    1    0    clkI/O/8 (From prescaler)
; 0    1    1    clkI/O/64 (From prescaler)
; 1    0    0    clkI/O/256 (From prescaler) <- use
; 1    0    1    clkI/O/1024 (From prescaler)
; 1    1    0    External clock source on T0 pin. Clock on falling edge.
; 1    1    1    External clock source on T0 pin. Clock on rising edge.
;                                                     Prescaler
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(1<<CS02)+(0<<CS01)+(0<<CS00)
	tst debug
	breq Tim0_Setup1 
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(0<<CS02)+(1<<CS01)+(0<<CS00) ;DEBUG settings
Tim0_Setup1:
	out     TCCR0B, tmp
; Top 
	ldi 	tmp, durTim0
	out 	OCR0A, tmp
; Compare
	ldi tmp, 0xFF
	out 	OCR0B, tmp
; Interrupt Enable for both timers
TimX_IntEn: 
	ldi tmp, (0<<OCIE1A)+(1<<OCIE1B)+(0<<TOIE1)+(1<<OCIE0A)+(1<<OCIE0B)+(0<<TOIE0)
	out     TIMSK, tmp
	ret


Tim1_Setup:  ; for x5, 
;CTC1 use OCR1C to count, match on OCR1B 
;PWM1A, COM1A1, COM1A0 all 0
;CS13 CS12 CS11 CS10
;	0	0	0	0 stopped
; 	0   0   0	1 CK
; 	0 	0 	1 	0 CK/2
; 	0 	0 	1 	1 CK/4
; 	0 	1 	0 	0 CK/8
; 	0 	1 	0 	1 CK/16
; 	0 	1 	1 	0 CK/32
; 	0 	1 	1 	1 CK/64 <--- use
...
;  	1	1	1	1 CK/16384

	ldi tmp, (1<<CTC1)+(0<<CS13)+(1<<CS12)+(1<<CS11)+(1<<CS10)
	out		TCCR1, tmp
	ldi 	tmp, durTim1
	out 	OCR1C, tmp
	ldi 	tmp, 1
	out 	OCR1B, tmp
; Interrupt Enable TIMSK shared with timer 0
	rjmp	TimX_IntEn ; which returns


ADC_Setup:  ; for x5, Single conversion mode
; REFS2 REFS1 REFS0 Voltage Reference Selection
;   x	  0     0   VCC used as analog reference, disconnected from PA0 (AREF)
;   x	  0     1   External voltage reference at AREF pin, internal reference turned off
;   0     1     0   Internal 1.1V voltage reference
; ...
; ADLAR: ADC Left Adjust Result
; MUX3:0 
; 0000 ADC0 (PB5) 
; 0001 ADC1 (PB2) <--
; 0010 ADC2 (PB4) .
; 0011 ADC3 (PB3)
; 0000   0V (AGND)
; 0001 1.1V (I Ref)
; 0010 ADC8 (temp)
	ldi		tmp, (0<<REFS2)+(0<<REFS1)+(0<<REFS0)+(1<<ADLAR)+(0<<MUX3)+(0<<MUX2)+(0<<MUX1)+ (1<<MUX0)
	out		ADMUX,tmp
;ADCSRA 
; ADEN: ADC Enable
; ADSC: ADC Start Conversion
; ADATE, ADIF, ADIE
; ADPS2:0: ADC Prescaler Select Bits
; 0 0 0   2
; 0 0 1   2
; 0 1 0   4
; 0 1 1   8
; 1 0 0  16
; 1 0 1  32
; 1 1 0  64
; 1 1 1 128
;
	ldi		tmp, (1<<ADEN)+(1<<ADSC)+(0<<ADATE)+(0<<ADPS2) + (0<<ADPS1) + (0<<ADPS0)
	out		ADCSRA,tmp
	clr		tmp
	out		ADCSRB,tmp
	ret

ExtInt_Setup:    ;for x5, debug only
	tst	debug
	breq ExtInt_Setup_Nix
;   GIMSK
;	INT0: External Interrupt Request 0 Enable 
;   PCIE: Pin Change Interrupt Enable 
	ldi tmp, (0<< INT0)+(1<< PCIE)
	out GIMSK, tmp
;   PCMSK PCINT5 to PCINT0
	ldi tmp, (1<< PCINT0)
	out PCMSK, tmp
ExtInt_Setup_Nix:
	ret
