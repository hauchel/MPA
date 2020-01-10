;------------------------------------------------------------------------------
; attiny 44 mot driver
;           clkdiv8  bod
; lfuse    62  e2    e2  
; hfuse    df  df    dc
; avrdude -p t44 -c usbasp -U lfuse:w:0xe2:m -U hfuse:w:0xdc:m
; commands nnnx
;------------------------------------------------------------------------------
.include "tn44def.inc"
.def      mulL		= R0
.def      mulH		= R1
.def		advalA	= R2
.def		advalB	= R3
.def   	num		= R7		; numeric value received
.def      cntA		= R8       
.def      cntB		= R9
.def		posiA	= R10	; 0 = disabled
.def		posiB	= R11	; 0=disabled		
.def		inT1		= R12	; 0=disabled
.def		stup		= R13	; 0=disabled
.def		sregs	= R15
.def 	tmp 		= R16	; general usage, not preserved
.def 	tmpX		= R17	; general usage, not preserved
.def 	tmpL		= R18   	; general usage, not preserved
.def 	tmpH		= R19   	; general usage, not preserved
.def		spedA	= R20	; 0 = disabled
.def		spedB	= R21	; 0=disabled		
.def 	sndbyte	= R22   	; general usage, not preserved


; GPIO use sbi cbi sbis sbic 
.equ		myGP	= GPIOR0	
.equ		quiet 	= 7 		; 1 if data in USI,		0 if no data
.equ		usidirect	= 6		; 1 to store ,			0 to buffer
.equ		pWasA	= 5     	; 1 to sample contin, 	0 to sample and dec anaCnt
.equ		pWasB	= 4     		; 1 data in  	
.equ    	pRepA 	= 3     	; 1 if inData is valid
.equ    	pRepB     = 2         ; 1 to return count of signal  
.equ    	togg      = 1         ; 1 to return count of signal  

;---------------------------------------------------------
;Ports
; MOSI
.equ 	mosiNum		=   6
.equ 	mosiPrt		=	PORTA
.equ 	mosiPin		=	PINA
.equ 	mosiDir		=	DDRA
; MISO
.equ 	misoNum		=   5
.equ 	misoPrt		=	PORTA
.equ 	misoPin		=	PINA
.equ 	misoDir		=	DDRA
; SCK
.equ 	clkNum		=   4         
.equ 	clkPrt		=	PORTA
.equ 	clkPin		=	PINA
.equ 	clkDir		=	DDRA
; LED
.equ 	aliNum		=   7
.equ 	aliPrt		=	PORTA
.equ 	aliPin		=	PINA
.equ 	aliDir		=	DDRA
; Motor
.equ 	leBNum		=   1
.equ 	leBPrt		=	PORTA
.equ 	leBPin		=	PINA
.equ 	leBDir		=	DDRA
;
.equ 	leANum		=   0
.equ 	leAPrt		=	PORTA
.equ 	leAPin		=	PINA
.equ 	leADir		=	DDRA

.equ 	adANum		=   2
.equ 	adBNum		=   2
.equ 	adcPrt		=	PORTA
.equ 	adcPin		=	PINA
.equ 	adcDir		=	DDRA

;inp on PortB
.equ 	inANum		=   0    ;ws
.equ 	inBNum		=   1    ;gr
.equ      KnoNum          =   2    ;
.equ 	inPrt		=	PORTB
.equ 	inPin		=	PINB
.equ 	inDir		=	DDRB
;

.dseg
	.org SRAM_START
; Ribus must be in lower memory as ?H are set to 0
BufX:		.Byte 8 	  ;Input from USI
BufXEnd:	
BufY:		.BYTE 18  ;to be sent by USI
BufYEnd:	     .Byte 2	 ; must be in this sequence
savSpedA:		.Byte 1
savSpedB:		.Byte 1
savCntA:		.Byte 1
savCntB:		.Byte 1

.macro PortOut ; Num Dir Prt as output to zero
	sbi @1, @0
	cbi @2, @0
.endmacro
.macro PortInP ; Num Dir Prt as input with Pup
	cbi @1, @0
	sbi @2, @0
.endmacro

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
	rjmp 	TIM1_COMPB	;  8 Timer1 Compare B
	reti; 		rjmp TIM1_OVF	;  9 Timer1 Overflow
	rjmp 	Tim0_CompA	; 10 Timer0 Compare A
	rjmp 	Tim0_CompB	; 11 Timer0 Compare B
	rjmp 	Tim0_Ovf		; 12 Timer0 Overflow
	reti; 		rjmp ANA_COMP 	; 13 Analog Comparator Handler
	reti;	rjmp 	ADC_comp 	 	; 14 Analog Conversion Complete
	reti; 	 	rjmp EE_RDY 	; 15 EEPROM Ready Handler
	reti;		rjmp USI_STR	; 16 USI Start
	rjmp 	USI_OVF				; 17 USI Overflow


; Start of Program
RESET:
;here we go:
	ldi tmp, high(RAMEND); Main program start
	out SPH,tmp; Set Stack Pointer to top of RAM
	ldi tmp, low(RAMEND)
	out SPL,tmp

	in stup,MCUSR
	clr tmp
	out MCUSR,tmp

	PortOut misoNum, misoDir, misoPrt

	PortOut aliNum, aliDir, aliPrt
	PortOut leANum, leADir, leAPrt
	PortOut leBNum, leBDir, leBPrt

	PortInp mosiNum, mosiDir, mosiPrt
	PortInp clkNum, clkDir, clkPrt
	PortInp adANum, adcDir, adcPrt
	PortInp adBNum, adcDir, adcPrt
	PortInp inANum, inDir, inPrt
	PortInp inBNum, inDir, inPrt
	PortInp KnoNum, inDir, inPrt

	clr	  SpedA
	clr	  SpedB
	clr	  PosiA
	clr	  PosiB
	clr	  CntA
	clr	  CntB
	ldi tmp,10
	sts  savCntA,tmp
	sts  savCntB,tmp
	ldi tmp,150
	sts  savSpedA,tmp
	sts  savSpedB,tmp
	clr    num
	cbi  myGP,togg

	rcall  USI_Setup
	rcall  Tim0_Setup
     rcall  Tim1_Setup
	rcall  ADC_Setup

	mov tmp, stup
	rcall USI_SendHex
	ldi tmp,'R'
	rcall USI_PutCh	
	sei
	
Lop1:
	rcall USI_GetCh
	or	tmp,tmp
	brne	DoCmd

	ldi		tmp, (0<<REFS1)+(0<<REFS0)+(0<<MUX2)+(1<<MUX1)+ (0<<MUX0)
	out		ADMUX,tmp
	sbi		ADCSRA, ADSC ; start conversion
;Wait until EOC
Convert2A:
	sbic	ADCSRA, ADSC ; is one during conversion
	rjmp	Convert2A
	in		AdValA, ADCH 

	ldi		tmp, (0<<REFS1)+(0<<REFS0)+(0<<MUX2)+(1<<MUX1)+ (1<<MUX0)
	out		ADMUX,tmp
	sbi		ADCSRA, ADSC ; start conversion
;Wait until EOC
Convert2B:
	sbic	ADCSRA, ADSC ; is one during conversion
	rjmp	Convert2B
	in	AdValB, ADCH 
	rjmp Lop1
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
	
	
c_NoNum:

	cpi	tmp,'a' 	; count
	brne C_a
	sts  savCntA,num
	rjmp	Lop4
C_a:

	cpi	tmp,'b' 	; 
	brne C_b
	sts  savCntB,num
	rjmp Lop4
C_b:

	cpi	tmp,'c'   ;speed 	; 
	brne C_c
	sts  savSpedA, num
	rjmp Lop4
C_c:

	cpi	tmp,'d' 	; 
	brne C_d
	sts savSpedB, num
	rjmp Lop4
C_d:
	
	cpi	tmp,'e' 	; 
	brne C_e
	rjmp Lop1
C_e:

	cpi	tmp,'f' 	; show savs
	brne C_f
	lds tmp,SavCntA
	rcall USI_SendDec
	lds tmp,SavcntB
	rcall USI_SendDec
	lds tmp,SavSpedA
	rcall USI_SendDec
	lds tmp,SavSpedB
	rcall USI_SendDec
	ldi tmp, 'F'
	rjmp Lop5
C_f:

	cpi	tmp,'g' 	; 
	brne C_g
	rjmp LopGo
C_g:

	cpi	tmp,'h' 	; 
	brne C_h
	rcall getdata
	rjmp Lop4
C_h:

	cpi	tmp,'j' 	; 
	brne C_j
	mov  tmp, advalA
	rcall USI_SendDec
	mov  tmp, advalB
	rcall USI_SendDec
	ldi tmp, 'J'
	rjmp Lop5
C_j:

	cpi	tmp,'p' 	; 
	brne C_p
	mov tmp,cntA
	rcall USI_SendDec
	mov tmp,cntB
	rcall USI_SendDec
	ldi tmp, 'P'
	rjmp Lop5
C_p:

	cpi	tmp,'s' 	; 
	brne C_s
	mov tmp,SpedA
	rcall USI_SendDec
	mov tmp,SpedB
	rcall USI_SendDec
	ldi tmp, 'S'
	rjmp Lop5
C_s:

C_yin:
	cpi	tmp,'y' 	; 
	brne C_y
	ldi tmp, 40
	mov cntA, tmp
	mov cntB, tmp
	ldi tmp, 200
	mov SpedA, num
	mov SpedB, num
	rjmp Lop4
C_y:

	cpi	tmp,' ' 	; 
	brne C_spc
	clr spedA
	clr spedB
	rjmp Lop4
C_spc:

	cpi	tmp,'#' 	; 
	brne C_lat
	rjmp Lop1
C_lat:

	rcall USI_PutCh
	ldi tmp,'?'
	rjmp Lop5

LopGo:
; Set speeds
	ldi  tmpL,255
	lds  tmp, savSpedA
	sub	tmpL,tmp
	ldi  tmpH,255
	lds  tmp, savSpedB
	sub	tmpH,tmp
	cli
	lds	cntA,savCntA
	lds	cntB,savCntB
	mov  spedA,tmpL
	mov  spedB,tmpH
	out 	OCR0A, tmpL
	out 	OCR0B, tmpH
	sei
Lop4:       ; here to send Z
	ldi tmp,'Z'
Lop5:
	clr num
	rcall USI_PutCh
	rjmp Lop1

getData:
	ldi ZL,low(values*2)
	ldi ZH,high(values*2)
	mov  tmp,num
	andi tmp,0x0F
	lsl tmp
	lsl tmp
	add  ZL,tmp
	brcc getData1
	inc ZH
getData1:
	lpm tmp,Z+
	sts savSpedA,tmp
	lpm tmp,Z+
	sts savSpedB,tmp
	lpm tmp,Z+
	sts savCntA,tmp
	lpm tmp,Z+
	sts savCntB,tmp
	ret

values:   ;savSpedA savSpedB savCntA savCntB
	.db 150,150,20,20
	.db 0,150,0,20
	.db 150,0,20,0

	
Waitms:
	push tmpL
WaitMs0:
	ldi tmpL,250
WaitMs1:
	nop
	dec  tmpL
	brne WaitMs1
	dec  tmp
	brne	WaitMs0

	pop  tmpL
	ret


;**************** 
Tim0_Ovf:

	in   	sregS, SREG	
	cbi		PORTA,0	
	cbi		PORTA,1	
	out		SREG,sregS
	reti

;**************** 
Tim0_CompB:
; switch on
	in   sregS, SREG
	or	spedB,spedB
	breq	Tim0_CompBX			
	sbi		PORTA,0	
Tim0_CompBX:
	out		SREG,sregS
	reti
;**************** 
Tim0_CompA:
; switch on
	in   	sregS, SREG	
	or	spedA,spedA
	breq	Tim0_CompAX			
	sbi		PORTA,1	
Tim0_CompAX:
	out		SREG,sregS
	reti

;**************** 
Tim1_CompB:
	in   	sregS, SREG
	sbi		aliPrt,aliNum
; detect change on
;             --------- 
;            |         |
; -----------           --------------
; curr 0       1  1  1  0  0  0
; was  0       0->1  1  1->0  0
;               !        !
; rep  0       0  0->1  1  1->0
;                  *        ! 
	in	inT1,inPin
	sbrs inT1,inBNum
	rjmp	Tim1B_0xx
	sbic myGP, pWasB 
     rjmp Tim1B_11x                  ;
	sbis myGP, pRepB
	rjmp Tim1B_100
; invalid, do nothing                    
Tim1B_Invalid:
	rjmp	Tim1B_Done  ; 1 0 1
Tim1B_100:
	sbi  myGP, pWasB
	rjmp	Tim1B_Done  ; 1 0 0
Tim1B_11x:
	sbic myGP, pRepB
	rjmp	Tim1B_Done  ; 1 1 1
Tim1B_110:
	sbi  myGP, pRepB 
	inc	posiB
	dec  cntB
	brne Tim1B_Done  ; 1 1 0
; stop
	clr SpedB
Tim1B_Done:
	rjmp Tim1_CompB_Done
Tim1B_0xx:
	sbic myGP, pWasB 
     rjmp Tim1B_01x                  
Tim1B_00x:
	sbis myGP, pRepB
	rjmp	Tim1B_Done    ;0 0 0
Tim1B_001:
 	cbi myGP, pRepB
	rjmp	Tim1B_Done    ;0 0 1
Tim1B_01x:           
	sbis myGP, pRepB
	rjmp	Tim1B_Invalid ;0 1 0
Tim1B_011:           
	cbi  myGP, pWasB
	rjmp	Tim1B_Done   ; 0 1 1
	
Tim1_CompB_Done:
	cbi		aliPrt,aliNum
	out		SREG,sregS
	reti


;**************** 
Tim1_CompA:
	in   	sregS, SREG
	sbi		aliPrt,aliNum
; detect change on
;             --------- 
;            |         |
; -----------           --------------
; curr 0       1  1  1  0  0  0
; was  0       0->1  1  1->0  0
;               !        !
; rep  0       0  0->1  1  1->0
;                  *        ! 
	in	inT1,inPin
	sbrs inT1,inANum
	rjmp	Tim1A_0xx
	sbic myGP, pWasA 
     rjmp Tim1A_11x                  ;
	sbis myGP, pRepA
	rjmp Tim1A_100
; invalid, do nothing                    
Tim1A_Invalid:
	rjmp	Tim1A_Done  ; 1 0 1
Tim1A_100:
	sbi  myGP, pWasA
	rjmp	Tim1A_Done  ; 1 0 0
Tim1A_11x:
	sbic myGP, pRepA
	rjmp	Tim1A_Done  ; 1 1 1
Tim1A_110:
	sbi  myGP, pRepA 
	inc	PosiA
	dec  cntA
	brne Tim1A_Done  ; 1 1 0
; stop
	clr SpedA
Tim1A_Done:
	rjmp Tim1_CompA_Done
Tim1A_0xx:
	sbic myGP, pWasA 
     rjmp Tim1A_01x                  
Tim1A_00x:
	sbis myGP, pRepA
	rjmp	Tim1A_Done    ;0 0 0
Tim1A_001:
 	cbi myGP, pRepA
	rjmp	Tim1A_Done    ;0 0 1
Tim1A_01x:           
	sbis myGP, pRepA
	rjmp	Tim1A_Invalid ;0 1 0
Tim1A_011:           
	cbi  myGP, pWasA
	rjmp	Tim1A_Done   ; 0 1 1
	
Tim1_CompA_Done:
	cbi		aliPrt,aliNum
	out		SREG,sregS
	reti

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
	ldi		tmp, (0<<REFS1)+(0<<REFS0)+(0<<MUX2)+(1<<MUX1)+ (0<<MUX0)
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
	ldi		tmp, (1<<ADEN) + (1<<ADSC) + (1<<ADPS2) + (0<<ADPS1) + (1<<ADPS0)
	out		ADCSRA,tmp
	ret

Tim0_Setup: 
; Normal Port Operation ,Mo  W2 W1 W0
;					 0  0  0  0 255
;                         2  0  1  0 CTC         OCRA Immediate MAX  

	ldi tmp, (0<<COM0A1)+(0<<COM0A0)+(0<<COM0B1)+(0<<COM0B0)+(0<<WGM01)+(0<<WGM00)
	out		TCCR0A, tmp
; Clock from Prescaler / 1024
;CS12 CS11 CS10 for tim1  should be less than tim0!
;CS02 CS01 CS00 for tim0
; 0    0    0    No clock source (Timer/Counter stopped)
; 0    0    1    clkI/O/(No prescaling)
; 0    1    0    clkI/O/8 (From prescaler)
; 0    1    1    clkI/O/64 (From prescaler)    
; 1    0    0    clkI/O/256 (From prescaler)   
; 1    0    1    clkI/O/1024 (From prescaler)
; 1    1    0    External clock source on T0 pin. Clock on falling edge.
; 1    1    1    External clock source on T0 pin. Clock on rising edge.
; 
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(1<<CS02)+(0<<CS01)+(0<<CS00)
	out     TCCR0B, tmp
; Top 
	ldi 	tmp, 255
	out 	OCR0A, tmp
; Compare
	ldi tmp, 255
	out 	OCR0B, tmp
; Interrupt Enable 
	ldi tmp, (1<<OCIE0B)+(1<<OCIE0A)+(1<<TOIE0)
	out     TIMSK0, tmp
	ret


Tim1_Setup: 
; Normal Port, WGM 13 12 11 10
;                   0  1  0  0 CTC         OCRA Immediate MAX  

	ldi tmp, (0<<COM1A1)+(0<<COM1A0)+(0<<COM1B1)+(0<<COM1B0)+(0<<WGM11)+(0<<WGM10)
	out		TCCR1A, tmp
; 
; CS1x and WGM see above
	ldi tmp, (0<<WGM13)+(1<<WGM12)+(0<<CS12)+(1<<CS11)+(0<<CS10)+(0<<ICNC1)+(0<<ICES1)
	out     TCCR1B, tmp
; Top, write Hi first
	ldi 	tmpH ,5
	ldi 	tmpL ,0
	out 	OCR1AH, tmpH
	out 	OCR1AL, tmpL
; Compare
	ldi 	tmpH ,2
	out 	OCR1BH, tmpH
	out 	OCR1BL, tmpL

; Interrupt Enable 
	ldi tmp, (1<<OCIE1B)+(1<<OCIE1A)+(0<<TOIE1)
	out     TIMSK1, tmp
	ret

.include "usix5.inc"

