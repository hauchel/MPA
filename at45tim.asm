;*************************************************************************
; Attiny x5 servo driver with spi
; Fuse Bytes:
;           7 6 5 4 3 2 1 0
; Extended 						FF
; Highfuse  1 1 0 1 0 1 0 1  	D5   SPIEN, EESAVE, BODLEVEL 2.7
; LowFuse                  		62 
;
;
;*************************************************************************
.NOLIST
.include "tn45def.inc"
;.LIST
;.LISTMAC

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
.def base			= R5		; base value
;.def    			= R6		; 
;.def				= R7		; set to xx if inData received, dec during timer0
.def	inData  	= R8		; contains incoming Data if inDataValid
.def	inByte		= R9		; incoming Byte built by tim1
.def	sigCnt		= R10		; count of signal duration
.def	nosCnt		= R11   	; count of no signal duration
;.def			= R12   	; count of no signal duration
;.def			 	= R13		; 
.def	cnt0	 		= R14	; decremented during tim0
.def	sregS		= R15	; saves status during interrupt
.def tmp 			= R16   	; general usage, not preserved
.def	repcntB		= R17	; Current state
.def	oldVal		= R18	; old 
.def	oldCnt		= R19	; Cnt down if same value
.def	state		= R20	; 0 or value to set
.def	sndByte		= R21	; Byte which is currently sent if empty
.def	adhigh		= R22	; no activity
.def	tmpX			= R23	; set to xx if button pressed, dec during timer0
.def	tmpL			= R24   	; upper 4 register pairs
.def	tmpH			= R25   	;
; XL				= R26 	; index to access buffer
; XH				= R27	; must be zero at all times
; YL				= R28   	; sendBuffer in
; YH				= R29		; sendBuffer out 
; ZL				= R30       ; 
; ZH				= R31	    ; 0 forever

;Data Segment	
.dseg
.org SRAM_START
; Ribus must be in lower memory as ZH are set to 0
BufX:		.Byte 8 	  ;Input from USI
BufXEnd:	
BufY:		.Byte 8	  ;Output to USI
BufYEnd:		.Byte 2
;Code Segment	
.cseg
; interrupt Jump Table attiny 85
	.org 0x0000
 	rjmp RESET 				;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
	reti; 	rjmp INT0 		;  2 External Interrupt
	reti;	rjmp PCINT0_H		;  3 PCINT0 Handler
	reti; 	rjmp TIM1_COMPA 	;  4 Timer1 Compare Match A 
	reti;	rjmp TIM1_OVF 		;  5 Timer1 Overflow Handler
	reti;	rjmp TIM0_OVF 		;  6 Timer0 Overflow Handler
	reti; 	rjmp EE_RDY 		;  7 EEPROM Ready Handler
	reti; 	rjmp ANA_COMP 		;  8 Analog Comparator Handler
	reti; 	rjmp ADC	 		;  9 Analog Conversion Complete
	reti;	rjmp Tim1_CompB	; 10 Timer1 Compare Match B
	rjmp Tim0_CompA			; 11 Timer0 Compare Match A
	rjmp Tim0_CompB			; 12 Timer0 Compare Match B
	reti; 		rjmp WDT	 	; 13 WDT Watchdog Time-out
	reti;		rjmp USI_START  ; 14 USI Start
	rjmp	USI_OVF    ; 15 USI Overflow
	


;Ports
; MOSI
.equ 	mosiNum		=   0
.equ 	mosiPrt		=	PORTB
.equ 	mosiPin		=	PINB
.equ 	mosiDir		=	DDRB
; MISO
.equ 	misoNum		=   1
.equ 	misoPrt		=	PORTB
.equ 	misoPin		=	PINB
.equ 	misoDir		=	DDRB
; SCK
.equ 	clkNum		=   2         
.equ 	clkPrt		=	PORTB
.equ 	clkPin		=	PINB
.equ 	clkDir		=	DDRB
; LED
.equ 	ledNum		=   3
.equ 	ledPrt		=	PORTB
.equ 	ledPin		=	PINB
.equ 	ledDir		=	DDRB
; adc
.equ 	adcNum		=   4
.equ 	adcPrt		=	PORTB
.equ 	adcPin		=	PINB
.equ 	adcDir		=	DDRB

; GPIO use sbi cbi sbis sbic 
.equ		myGP	= GPIOR0		; 
.equ		quiet 	= 7 		; 1 if data in USI,		0 if no data
.equ		usidirect	= 6		; 1 to store ,			0 to buffer
.equ		anaDau		= 5     	; 1 to sample contin, 	0 to sample and dec anaCnt
.equ		received	= 4     		; 1 data in  	
.equ    	inDataValid = 3     	; 1 if inData is valid
.equ    	anaMes      = 2         ; 1 to return count of signal  

.macro PortOut ; Num Dir Prt as output to zero
	sbi @1, @0
	cbi @2, @0
.endmacro
.macro PortInP ; Num Dir Prt as input with Pup
	cbi @1, @0
	sbi @2, @0
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
; configure Ports outgoing to zero
	PortOut ledNum, ledDir, ledPrt
	PortOut misoNum, misoDir, misoPrt

	PortInp mosiNum, mosiDir, mosiPrt
	PortInP adcNum, adcDir, adcPrt
	PortInP clkNum, clkDir, clkPrt

	rcall Tim0_Setup
	rcall ADC_Setup
	rcall USI_Setup
	ldi  repcntB, 5
	ldi	tmp,190
	mov	base,tmp
	ldi	oldCnt, 50
	cbi 	myGP, quiet	
	clr  state
	ldi	sndByte,65
	ldi tmp,65
	rcall USI_PutCh
	inc tmp
	rcall USI_PutCh
	inc tmp
	rcall USI_PutCh
	sei
Lop1:
	rcall USI_GetCh
	or	tmp,tmp
	breq Lop3
DoCmd:
; process command in tmp
	cpi	tmp,'a' 	; all test simple
	brne C_a
	ldi  state, 0xB0
	rjmp	Lop4
C_a:

	cpi	tmp,'b' 	; 
	brne C_b
	ldi  state, 0xC0
	rjmp Lop4
C_b:

	cpi	tmp,'c' 	; 
	brne C_c
	ldi  state, 0xE0
	rjmp Lop4
C_c:

	cpi	tmp,'q' 	; status
	brne C_q
	dec  state
	rjmp Lop4
C_q:

	cpi	tmp,'w' 	; status
	brne C_w
	inc  state
	rjmp Lop4
C_w:

	cpi	tmp,'x' 	; analog again
	brne C_x
	clr  state
	rjmp Lop4
C_x:

	cpi	tmp,'y' 	; activate out
	brne C_y
	clr	oldCnt
	cbi 	myGP, quiet
	rjmp Lop4
C_y:

Lop3:
	dec tmpL
	brne Lop1
Lop4:	;cmd or timeout
	or state,state
	breq Analog
	mov tmp,state
	rjmp Setit

Analog:
	sbi		ADCSRA, ADSC ; start next conversion
Wait_adc:
	sbic	ADCSRA, ADSC        ;  wait until complete
	rjmp  Wait_adc
    	;in    tmpX, ADCL        ; Low Byte first
    	in   tmp, ADCH 		; now high
     lsr	tmp
	lsr	tmp
	add	tmp,base
Setit:
	cp	tmp,oldVal
	breq	same
	mov	oldVal,tmp
     out 	OCR0B, tmp
	clr	oldCnt
	cbi 	myGP, quiet	
	rjmp Lop1
Same:
	dec	oldCnt
	brne	Lop1
	sbi 	myGP, quiet	
	mov  tmp,oldVal
	rcall usi_putch
	rjmp Lop1


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
; 1    0    0    clkI/O/256 (From prescaler) <- use 255 8ms
; 1    0    1    clkI/O/1024 (From prescaler)
; 1    1    0    External clock source on T0 pin. Clock on falling edge.
; 1    1    1    External clock source on T0 pin. Clock on rising edge.
;                                                     Prescaler
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(1<<CS02)+(0<<CS01)+(0<<CS00)
	out     TCCR0B, tmp
; Top 
	ldi 	tmp, 0xFF
	out 	OCR0A, tmp
; Compare
	ldi tmp, 0x80
	out 	OCR0B, tmp
; Interrupt Enable for both timers
TimX_IntEn: 
	ldi tmp, (0<<OCIE1A)+(0<<OCIE1B)+(0<<TOIE1)+(1<<OCIE0A)+(1<<OCIE0B)+(0<<TOIE0)
	out     TIMSK, tmp
	ret
	
Tim0_CompA:
; bitcnt on entry 
;   0		return
;   1       don't set out
;   2..x    set out 
	in   	sregS, SREG		
	cbi		LedPrt, LedNum	; Signal off
	out		SREG,sregS
	reti

Tim0_CompB:
; switch send of off
	in   	sregS, SREG	
	dec       repcntB
	brne		Tim0_CompB_X
	sbis		myGp,quiet
	sbi		LedPrt, LedNum	; Signal on
	ldi		repcntB, 3
Tim0_CompB_X:
	out		SREG,sregS
	reti



ADC_Setup:  ; for x5, Single conversion mode
; REFS2 REFS1 REFS0 Voltage Reference Selection
;   x	  0     0   VCC used as analog reference, disconnected from PA0 (AREF)
;   x	  0     1   External voltage reference at AREF pin, internal reference turned off
;   0       1     0   Internal 1.1V voltage reference
; ...
; ADLAR: ADC Left Adjust Result
; MUX3:0
;  210 
; 0000 ADC0 (PB5) 
; 0001 ADC1 (PB2)
; 0010 ADC2 (PB4) . <--
; 0011 ADC3 (PB3)
; 0000   0V (AGND)
; 0001 1.1V (I Ref)
; 0010 ADC8 (temp)
	ldi		tmp, (0<<REFS2)+(0<<REFS1)+(0<<REFS0)+(1<<ADLAR)+(0<<MUX3)+(0<<MUX2)+(1<<MUX1)+ (0<<MUX0)
	out		ADMUX,tmp
;ADCSRA 
; ADEN: ADC Enable 1
; ADSC: ADC Start Conversion 1
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
; for better see tccp.inc
USI_Setup:  ;Slave 
; Interrupt called at overflow then USI data is stored in XBuf and taken from YBuf
; 
; USISIE: Setting this bit to one enables the start condition detector interrupt. 
; USIOIE: Counter Overflow Interrupt Enable
; USIWM1, USIWM0: Wire Mode
;   0        1    Three Wire
; USICLK: Clock Strobe Writing a one to this bit location strobes the USI Data Register to shift one step and the counter
; USICS1 USICS0 USICLK 	    Clock Source            4-bit Counter Clock Source
;	0		0		0   	No   Clock 				No Clock
;    0      	0 		1       Software clock strobe (USICLK) Software clock strobe (USICLK)
;	0 		1 		X 		Timer/Counter0 Compare Match Timer/Counter0 Compare Match
;	1 		0 		0		Ext, positive edge 		Ext, both edges
;	1 		1 		0 		Ext, negative edge 		Ext, both edges
;	1 		0 		1 		Ext, positive edge 		Software clock strobe (USITC)
;	1 		1 		1 		Ext, negative edge 		Software clock strobe (USITC)
; clock is H, to L samples MOSI, to H samples MISO
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


; get character in xBuf (XL+) into tmp
USI_GetCh:
	clr	tmp
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
	ldi	tmp,'-'
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
	inc	sndByte
	cpi	sndByte,80
	brne USI_OvfIn7
	ldi	sndByte,65

USI_OvfIn7:
	pop		ZL
	pop		tmp
	out		SREG,sregS
	reti

.include "usix5.inc"
