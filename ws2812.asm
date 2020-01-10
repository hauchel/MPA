;*************************************************************************
; Attiny x5 ws2812 LedStripeLanguage
; Fuse Bytes:
; Extended 	FF
; Highfuse  	D5   SPIEN, EESAVE, BODLEVEL 2.7
; LowFuse      62 
;
; Idea is using a current buffer and a shift approach
; commands (nnn is value 0 to 255)
; nnnr nnng nnnb    set rgb value
; z      clear          
; f      fill buffer with current rgb
; l      shift buffer left
; s      shift buffer (right)
; np     run Program nnn 1 to 9
; nnnt   acivate timer with cnt nnn 0off
; nnnq   set timer prescaler e.g. 4q
; w      write current rgb
; nnnc   write predefined color       
; m      set nnn to 255
; h      set nnn to 128
; + -    +-nnn by 10
;        toggle display of current rgb after change
;        bar depending on analog
;        rainbow fill
;*************************************************************************
.NOLIST
.include "tn45def.inc"
;.LIST
;.LISTMAC

; register usage
.def	debug	= R0		; running in Simulator if not 0
.def	myCol	= R1		; my color
.def	inL		= R2		; USI incoming
.def	inH		= R3		; USI in
.def	outL		= R4		; USI out
.def outH		= R5		; USI out
.def num		= R6		; incoming number
.def	anaVal	= R7		; set to xx if inData received, dec during timer0
.def	prog  	= R8		; current prog
.def	inByte	= R9		; incoming Byte built by tim1
.def	sigCnt	= R10		; count of signal duration
.def	nosCnt	= R11   	; count of no signal duration
;.def		= R12   	; count of no signal duration
.def	tim0pre	= R13	; prset value for tim0
.def	tim0cnt 	= R14	; decremented during tim0
.def	sregS	= R15	; saves status during interrupt
.def tmp 		= R16   	; general usage, not preserved
.def	Sndcnt	= R17	; Current state
.def	tickcnt	= R18	; old 
.def	valR		= R19	; 
.def	valB		= R20	; 
.def	valG  	= R21	; 
.def	bufcnt	= R22	; counter fur buffer
.def	tmpX			= R23	; set to xx if button pressed, dec during timer0
.def	tmpL			= R24   	; upper 4 register pairs
.def	tmpH			= R25   	;
; XL				= R26 	; 
; XH				= R27	; 
; YL				= R28   	; 
; YH				= R29	;
; ZL				= R30     ; 
; ZH				= R31	; 0 forever

;Data Segment	
.dseg
.org SRAM_START
; Ribus must be in lower memory as ZH are set to 0
BufX:		.Byte 8 	  ;Input from USI
BufXEnd:	
BufY:		.Byte 8	  ;Output to USI
BufYEnd:		.Byte 2
Data:		.Byte 30    ;9*3

;Code Segment	
.cseg
; interrupt Jump Table attiny 85
	.org 0x0000
 	rjmp RESET 			;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
	reti	;rjmp INT0 		;  2 External Interrupt
	reti	;rjmp PCINT0_H		;  3 PCINT0 Handler
	reti	;rjmp TIM1_COMPA 	;  4 Timer1 Compare Match A 
	reti	;rjmp TIM1_OVF 	;  5 Timer1 Overflow Handler
	reti	;rjmp TIM0_OVF 	;  6 Timer0 Overflow Handler
	reti	;rjmp EE_RDY 		;  7 EEPROM Ready Handler
	reti	;rjmp ANA_COMP 	;  8 Analog Comparator Handler
	reti	;rjmp ADC	 		;  9 Analog Conversion Complete
	reti	;rjmp Tim1_CompB	; 10 Timer1 Compare Match B
	rjmp Tim0_CompA		; 11 Timer0 Compare Match A
	reti	;rjmp Tim0_CompB	; 12 Timer0 Compare Match B
	reti	;rjmp WDT	 		; 13 WDT Watchdog Time-out
	reti	;rjmp USI_START  	; 14 USI Start
	rjmp	USI_OVF   		; 15 USI Overflow
	


;Ports
.equ 	myPrt		=	PORTB
.equ 	myPin		=	PINB
.equ 	myDir		=	DDRB

.equ 	mosiNum		=   0
.equ 	misoNum		=   1
.equ 	clkNum		=   2         
; LED
.equ 	ledNum		=   3
; alive
.equ 	adcNum		=   4

; GPIO use sbi cbi sbis sbic 
.equ		myGP	= GPIOR0		; 
.equ		tick	= 7 		; 1 if data in USI,		0 if no data
.equ		usidirect	= 6		; 1 to store ,			0 to buffer
.equ		Tickon =5  	; 1 to sample contin, 	0 to sample and dec anaCnt
.equ		received	= 4     		; 1 data in  	
.equ    	inDataValid = 3     	; 1 if inData is valid
.equ    	anaMes      = 2         ; 1 to return count of signal  

.macro PortOut ; Num Dir Prt as output to zero
	sbi myDir, @0
	cbi myPrt, @0
.endmacro
.macro PortInP ; Num Dir Prt as input with Pup
	cbi myDir, @0
	sbi myPrt, @0
.endmacro

; Start set to 0x20
	.org 0x0020
RESET:
;here we go:
	ldi tmp, low(RAMEND)
	out SPL,tmp
	ldi tmp, high(RAMEND)
	out SPH,tmp 
; configure Ports outgoing to zero
	PortOut ledNum
	PortOut misoNum

	PortInP adcNum
	PortInp mosiNum
	PortInP clkNum

	clr	tickcnt
	rcall USI_Setup
	rcall Tim0_Setup
	rcall DataSetup
	rcall ADC_Setup
	ldi tmp,65
	rcall USI_PutCh
	inc tmp
	rcall USI_PutCh
	inc tmp
	rcall USI_PutCh
	sei
Lop1:
	sbic	myGP,tick
	rcall doTick
	rcall USI_GetCh
	or	tmp,tmp
	brne DoCmd

	rjmp	Lop1

DoCmd:
; process command in tmp
; numeric values 48 to 57 are stored
	cpi	tmp,58
	brge	C_NoNum 
	cpi	tmp,48
	brlt	C_NoNum
; mult num by 1010
	push tmp
	lsl num
	push num
	lsl num	
	lsl num
	pop tmp
	add num,tmp
; then add tmp
	pop tmp
	subi tmp,48
	add num,tmp
	rjmp Lop1
C_NoNum:

	cpi	tmp,'a' 	; get analog
	brne C_a
	push	tmp
	sbi		ADCSRA, ADSC ; start next conversion
wait_adc:
    	sbic    ADCSRA, ADSC        
    	rjmp    wait_adc
	in		tmp, ADCH 
	rcall USI_SendDec
	rjmp	Lop4
C_a:

	cpi	tmp,'b' 	; blue value 
	brne C_b
	mov  valB,num
	rjmp Lop5
C_b:

	cpi	tmp,'c' 	; clear
	brne C_c
	clr  valR
	clr  valB
	clr  valG
	rcall BufFill
	rcall BufSend
	rjmp Lop4
C_c:

	cpi	tmp,'d' 	; 
	brne C_d
	rcall DataSetup
	rcall BufSend
	rjmp Lop4
C_d:

	cpi	tmp,'f' 	; 
	brne C_f
	rcall BufFill
	rcall BufSend
	rjmp Lop4
C_f:

	cpi	tmp,'g' 	
	brne C_g
	mov  valG,num
	rjmp Lop5
C_g:

	cpi	tmp,'h' 	; 
	brne C_h
	ldi tmp,127
	mov num,tmp
	rjmp Lop4
C_h:

	cpi	tmp,'l' 	; 
	brne C_l
	rcall BufLeft
	rcall BufSend
	rjmp Lop4
C_l:

	cpi	tmp,'m' 	; 
	brne C_m
	ldi tmp,255
	mov num,tmp
	rjmp Lop4
C_m:

	cpi	tmp,'p' 	; 
	brne C_p
	mov tim0Pre,num
	clr num
	rjmp Lop4
C_p:

	cpi	tmp,'q' 	; 
	brne C_q
	mov tim0Pre,num
	mov tim0Cnt,num
	clr num
	rjmp Lop4
C_q:

	cpi	tmp,'r' 	
	brne C_r
	mov  valR,num
	rjmp Lop5
C_r:

	cpi	tmp,'s' 	
	brne C_s
	rcall BufShift
	rcall BufSend
	rjmp Lop4
C_s:

	cpi	tmp,'t' 	; 
	brne C_t
	sbis myGP,tickon
	rjmp C_t1
	cbi myGP,tickon
	rjmp Lop4
C_t1: ;enable tick, set if num
	clr tickcnt
	or num,num
	breq C_t2
	out OCR0A,num
C_t2:
	sbi myGP,tickon
	rjmp Lop4
C_t:

	cpi	tmp,'w' 	; 
	brne C_w
	ldi ZL,data
	clr ZH
	st Z+,valG
	st Z+,valR
	st Z+,valB
	rjmp Lop4
C_w:

	cpi	tmp,'x' 	;
	brne C_x
	rcall BufSend
	rjmp Lop4
C_x:


	cpi	tmp,'y' 	; activate out
	brne C_y
	ldi  ZL,data
	clr ZH
	rcall SendTrip
	rjmp Lop4
C_y:

	cpi	tmp,'z' 	; clear
	brne C_z
	clr  valR
	clr  valB
	clr  valG
	rcall BufFill
	rcall BufSend
	rjmp Lop4
C_z:


Lop4:	;cmd or timeout
	rjmp Lop1

Lop5:	; store value in Buf
	clr num
	rcall SendGRB
	rjmp Lop1


doTick:
	cbi myGP,tick
	sbis myGP,Tickon
	ret ; not on
	cpi	tickcnt,6
	brge doTickB
	rcall BufShift
doTickSnd:
	rcall BufSend
	ret

doTickB:
	cpi	tickcnt,11
	brge doTickC
	rcall BufLeft
	rjmp doTickSnd

doTickC:
	clr tickcnt
doTickD:	
	ret

DataSetup:
	ldi ZL,data
	clr ZH
	ldi tmp, 100
	st  Z+,tmp
	clr tmp
	st Z+,tmp
	st Z+,tmp

	st Z+,tmp
	ldi tmp, 100
	st  Z+,tmp
	st  Z+,tmp

	st Z+,tmp
	clr tmp;
	ret

BufFill:
	clr ZH
	ldi ZL,data
	ldi bufcnt,8
BufFill1:
	st  Z+,valG
	st  Z+,valR
	st  Z+,valB
	dec bufCnt
	brne BufFill1
	ret

BufSend:
	clr ZH
	ldi ZL,data
	ldi bufcnt,8
BufSend1:
	rcall SendTrip
	dec bufCnt
	brne BufSend1
	ret

    
BufShift:
	clr ZH
	ldi ZL,data
	adiw ZL:ZH ,8*3
	mov XH,ZH
	mov XL,ZL
	push	valG
	push valR
	push valB
	ld  valG,-Z
	ld  valR,-Z
	ld  valB,-Z
	ldi bufcnt,21
BufShift1:
	ld  tmp,-z
	st  -x,tmp
	dec bufCnt
	brne BufShift1
	st  -X,valG
	st  -X,valR
	st  -X,valB
	pop valB
	pop valR
	pop valG
	ret

	
BufLeft:
	clr ZH
	ldi ZL,data
	mov XH,ZH
	mov XL,ZL
	push	valG
	push valR
	push valB
	ld  valG,Z+
	ld  valR,Z+
	ld  valB,Z+
	ldi bufcnt,21
BufLeft1:
	ld  tmp,z+
	st  x+,tmp
	dec bufCnt
	brne BufLeft1
	st  X+,valG
	st  X+,valR
	st  X+,valB
	pop valB
	pop valR
	pop valG
	ret

SendGRB:
	mov tmp,valG
	rcall SendWS
	mov tmp,valR
	rcall SendWS
	mov tmp,valB
	rjmp SendWS

SendTrip:
;Send Triple at Z
	ld tmp,Z+
	rcall SendWS
	ld tmp,Z+
	rcall SendWS
	ld tmp,Z+
	rjmp SendWS


; G R B
;	Zeit High 	Zeit Low
; "0" 	0.35 탎 �150 ns 	0.9 탎 �150 ns
;         3
; "1" 	0.9 탎 �150 ns 	0.35 탎 �150 ns
;         7
;Reset 	- 	>50 탎(?)
; 1 = 0.125 us = 10
;     ---      -----
;    |   |    |      |
; ---     ----        ---
;      3         7
SendWS:
	ldi Sndcnt,8 
	cli
SendLop:
	lsl tmp	 		; 1
	dec Sndcnt			; 1 
	sbi myPrt, ledNum   ; 2     
	brcs SendLop2		; 1,2
     cbi myPrt, ledNum   ; 2
SendLop2: 
	nop                 ; 1
	nop                 ; 1
	nop                 ; 1
     cbi myPrt, ledNum   ; 2 
     brne SendLop
SendEnd:   
     sei
	ret

	

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
; 1    0    0    clkI/O/256 (From prescaler) 
; 1    0    1    clkI/O/1024 (From prescaler) <- use 255 = 8ms
; 1    1    0    External clock source on T0 pin. Clock on falling edge.
; 1    1    1    External clock source on T0 pin. Clock on rising edge.
;                                                     Prescaler
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(1<<CS02)+(0<<CS01)+(1<<CS00)
	out     TCCR0B, tmp
; Top 
	ldi 	tmp, 80
	out 	OCR0A, tmp
; Compare not used
	ldi tmp, 0x80
	out 	OCR0B, tmp
; prescaler
	ldi tmp,4
	mov tim0Cnt,tmp
	mov tim0Pre,tmp
; Interrupt Enable for both timers
TimX_IntEn: 
	ldi tmp, (0<<OCIE1A)+(0<<OCIE1B)+(0<<TOIE1)+(1<<OCIE0A)+(0<<OCIE0B)+(0<<TOIE0)
	out     TIMSK, tmp
	ret
	
Tim0_CompA:
; just set flag
	in   	sregS, SREG
	dec  tim0cnt
	brne Tim0_CompA1
	mov  tim0Cnt, tim0Pre
	sbi	myGP,tick		
	inc  tickcnt
Tim0_CompA1:
	out		SREG,sregS
	reti



ADC_Setup:  ; for x5, Single conversion mode
; REFS2 REFS1 REFS0 Voltage Reference Selection
;   x	  0     0   VCC used as analog reference, disconnected from PA0 (AREF)
;   x	  0     1   External voltage reference at AREF pin, internal reference turned off
;   0       1     0   Internal 1.1V voltage reference
; ...
; ADLAR: 1 ADC Left Adjust Result
; MUX3:0 
; 0000 ADC0 (PB5) 
; 0001 ADC1 (PB2) 
; 0010 ADC2 (PB4) .
; 0011 ADC3 (PB3)
; 0000   0V (AGND)
; 1100 1.1V (I Ref)
; 1111 ADC8 (temp)
	ldi		tmp, (0<<REFS2)+(0<<REFS1)+(0<<REFS0)+(1<<ADLAR)+(0<<MUX3)+(0<<MUX2)+(1<<MUX1)+ (0<<MUX0)
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
	ldi		tmp, (1<<ADEN)+(1<<ADSC)+(0<<ADATE)+(1<<ADPS2) + (1<<ADPS1) + (1<<ADPS0)
	out		ADCSRA,tmp
	clr		tmp
	out		ADCSRB,tmp
	ret

.include "usix5.inc"
