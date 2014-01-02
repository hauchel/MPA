;*************************************************************************
;* Prototype Roiny Master
;* Descr see bottom
;*************************************************************************
.NOLIST
.include "tn44def.inc"
.LIST

; Duration of signal controlled by Tim0
.equ    dur0       	=    8     ;OCR0B
.equ    dur1       	=   16     ;OCR0B
.equ    durTot		=   24     ;OCR0A


; register usage
.def	cnt1		= R0	; 
.def	cnt2		= R1	; 
.def	cnt3		= R2	; 
.def	val1		= R3	; Current Number
.def	val2		= R4	; Number for Pause
.def	val3		= R5	; Number of Counts
;.def	val19		= R6	; ADC: Value for Mux3..Mux0 
.def	AdRefs		= R7	; ADC: Value for Refs2..Refs0
;.def	mux 	= R8	; contains zero for addC
.def	valOCR1B	= R9	; Selection of inputs 0x0s 
.def	valOCR1C	= R10	; 0 to 3 which one to select
.def	AdVal2		= R11   ; Value of last conversion
.def	AdVal3	 	= R12	; Value of last conversion
.def	cntOn	 	= R13	; Counter
.def	sregS		= R15	; saves status during interrupt
.def 	tmp 		= R16   ; general usage, not preserved
.def	tmpL		= R17   ;
.def	tmpH		= R18   ;
.def	SndNum 		= R19	; Number of Dig
.def	SndDur		= R20	; Duration to Send, 0 = off
.def	active		= R21	; 0 to 3 
.def	ButCnt		= R22	; 0 Led off else Led on (decremented)
.def	recv		= R23	; 
.def	usepowH		= R24	; 
;.def	usepowH		= R25	; 
; XL				= R26 	; RiBu out, also used in Interrupt, do not touch
; XH				= R27	; 
; YL				= R28   ; RiBu in, also used in Interrupt, do not touch
; YH				= R29	; 
; ZL				= R30
; ZH				= R31	

;Data Segment	
.dseg
	.org SRAM_START
;Begin of Area saved in Flash
myCont:
myContEnd:
;End of Area saved in Flash
ribu:		.BYTE 80	  ;has to be even!
ribuEnd:	

;Code Segment	
.cseg
; interrupt Jump Table attiny 44
	.org 0x0000
 	rjmp RESET 					;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
	reti; 		rjmp EXT_INT0 	;  2 IRQ0 Handler
	reti; 		rjmp PCINT0 	;  3 PCINT0 Handler
	reti; 		rjmp PCINT1 	;  4 PCINT1 Handler 
	reti; 		rjmp WDT	 	;  5 Watchdog Time-out
	reti;		rjmp TIM1_CAPT	;  6 Timer/Counter1 Capture
	reti; 		rjmp TIM1_COMPA	;  7 Timer/Counter1 Compare A
	reti; 		rjmp TIM1_COMPB	;  8 Timer/Counter1 Compare B
	reti; 		rjmp TIM1_OVF	;  9 Timer/Counter1 Overflow
	rjmp TIM0_COMPA				; 10 Timer/Counter0 Compare A
	rjmp TIM0_COMPB				; 11 Timer/Counter0 Compare B
	reti; 		rjmp TIM0_OVF	; 12 Timer/Counter0 Overflow
	reti; 		rjmp ANA_COMP 	; 13 Analog Comparator Handler
	reti; 		rjmp ADC 	 	; 14 Analog Conversion Complete
	reti; 	 	rjmp EE_RDY 	; 15 EEPROM Ready Handler
	reti;		rjmp USI_STR	; 16 USI Start
	reti;		rjmp USI_OVF	; 17 USI Overflow
	

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
.equ 	shSNum		=   6
.equ 	shSPrt		=	PORTA
.equ 	shSPin		=	PINA
.equ 	shSDir		=	DDRA

.equ 	shWNum		=   3
.equ 	shWPrt		=	PORTA
.equ 	shWPin		=	PINA
.equ 	shWDir		=	DDRA

; In Analog 0
.equ 	anNum		=   0
.equ 	anPrt		=	PORTA
.equ 	anPin		=	PINA
.equ 	anDir		=	DDRA

;Incoming Buttons
.equ 	buYeNum		=   7
.equ 	buYePrt		=	PORTA
.equ 	buYePin		=	PINA
.equ 	buYeDir		=	DDRA

.equ 	buBlNum		=   2
.equ 	buBlPrt		=	PORTB
.equ 	buBlPin		=	PINB
.equ 	buBlDir		=	DDRB


; Start of Program
	.org 0x0020
RESET:
;here we go:
	ldi r16, high(RAMEND); Main program start
	out SPH,r16 ; Set Stack Pointer to top of RAM
	ldi r16, low(RAMEND)
	out SPL,r16

; configure Ports outgoing to zero
	sbi shNDir, shNNum
	cbi shNPrt, shNNum

	sbi shEDir, shENum
	cbi shEPrt, shENum

	sbi shSDir, shSNum
	cbi shSPrt, shSNum

	sbi shWDir, shWNum	     
	cbi shWPrt, shWNum

; configure Ports incoming PullUp
	cbi buYeDir, buYeNum
    sbi buYePrt, buYeNum

	cbi buBlDir, buBlNum
    sbi buBlPrt, buBlNum

	cbi anDir, anNum
    sbi anPrt, anNum

; configure 
	rcall ADC_Setup
	rcall Tim0_Setup


	sei ; Enable interrupts

start:
	ldi tmp, 0xFF
	mov cnt1, tmp
	mov val1, tmp
	ldi tmp, 8
	mov cnt2, tmp
	mov val2, tmp
	ldi tmp, 8
	mov cnt3, tmp
	mov val3, tmp

lop:	
; check if button Pressed (0)
	tst     ButCnt
	brne	lop1
	sbis	buBlPin, buBlNum
	rjmp	dobuBl
	sbis	buYePin, buYeNum
	rjmp	dobuYe
lop1:
	dec 	cnt1
	brne  	lop  
	mov 	cnt1, val1

; Start Conversion
	
	sbi		ADCSRA, ADSC ; is one during conversion	
;Wait until EOC
Convert2a:
	sbic	ADCSRA, ADSC ; is one during conversion
	rjmp	Convert2a
	in		AdVal2, ADCH 
	mov		tmp, AdVal2
	clc
    rol		tmp
    rol		tmp
    rol		tmp
	mov 	active,tmp
	ldi  	SndNum, 0xFF

	tst		ButCnt
	breq    lop3
	dec		ButCnt
lop3:	 
	dec 	cnt2
    brne	lop
	mov 	cnt2, val2

	dec 	cnt3
    brne	lop
	mov 	cnt3, val3

	rjmp 	lop

dobuYe:
; Button yellow pressed
	ldi		SndDur, dur0
	inc		active
dobuts_xx:
	ldi  	SndNum, 0xFF
	ldi		ButCnt, 0x20
	rcall	showbuts
dobuts_back:
	rjmp lop1

dobuBl:
; Button blue pressed, 
; already active?
; set next 
	ldi		SndDur, dur1
	dec		active
	rjmp	dobuts_xx



; Set buts depending on active
showbuts:
	andi	active, 0x03
	cpi		active,3
	brne	dobuts_n3
	sbi	shWPrt, shWNum
	ret
dobuts_n3:
	cpi		active,2
	brne	dobuts_n2
	sbi	shSPrt, shSNum
	ret
dobuts_n2:
	cpi		active,1
	brne	dobuts_n1
	sbi	shEPrt, shENum
	ret
dobuts_n1:
	sbi	shNPrt, shNNum
	ret

Tim0_CompA:
	in   	sregS, SREG	
	push 	tmp
; Determine what to send
	tst    SndDur
	breq   Tim0_CompA_1
; set OCR0B
	out 	OCR0B, sndDur
;	Snd_On

Tim0_CompA_1:

; Still things to send?
	tst    sndNum
	breq   Tim0_CompA_Done
	rcall showbuts		
	dec    sndNum
	brne   Tim0_CompA_Done
    ldi    sndDur ,0
Tim0_CompA_Done:
	pop		tmp
	out		SREG,sregS
	reti


Tim0_CompB:
; switch off
	in   	sregS, SREG	
	cbi 	shWPrt, shWNum
	cbi 	shSPrt, shSNum
	cbi 	shEPrt, shENum
	cbi 	shNPrt, shNNum
;	Snd_off
Tim0_CompB_Done:
	out		SREG,sregS
	reti

Tim0_Setup: 
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
; 1    0    0    clkI/O/256 (From prescaler)
; 1    0    1    clkI/O/1024 (From prescaler)
; 1    1    0    External clock source on T0 pin. Clock on falling edge.
; 1    1    1    External clock source on T0 pin. Clock on rising edge.
; 
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(0<<CS02)+(1<<CS01)+(1<<CS00)
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

; Fuses: default
; using 
; Timing controlled by Tim0
; 4 LEDs NESW to determine Orientation of Stone
; 1 ADC to input 
; Timer0 controls 
; 2 SCK			7
; 1 MISO		6	
; 0 MOSI		5	NC 
;
