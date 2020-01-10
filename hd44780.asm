;------------------------------------------------------------------------------
; HD44780 LCD Assembly driver
; http://avr-mcu.dxp.pl
; (c) Radoslaw Kwiecien
;
; for tiny 44
; uses PA0 to  PA3 for data
;
;------------------------------------------------------------------------------
.include "tn44def.inc"
#define HD44780_CLEAR					0x01

#define HD44780_HOME					0x02

#define HD44780_ENTRY_MODE				0x04
	#define HD44780_EM_SHIFT_CURSOR		0
	#define HD44780_EM_SHIFT_DISPLAY	1
	#define HD44780_EM_DECREMENT		0
	#define HD44780_EM_INCREMENT		2

#define HD44780_DISPLAY_ONOFF			0x08
	#define HD44780_DISPLAY_OFF			0
	#define HD44780_DISPLAY_ON			4
	#define HD44780_CURSOR_OFF			0
	#define HD44780_CURSOR_ON			2
	#define HD44780_CURSOR_NOBLINK		0
	#define HD44780_CURSOR_BLINK		1

#define HD44780_DISPLAY_CURSOR_SHIFT	0x10
	#define HD44780_SHIFT_CURSOR		0
	#define HD44780_SHIFT_DISPLAY		8
	#define HD44780_SHIFT_LEFT			0
	#define HD44780_SHIFT_RIGHT			4

#define HD44780_FUNCTION_SET			0x20
	#define HD44780_FONT5x7				0
	#define HD44780_FONT5x10			4
	#define HD44780_ONE_LINE			0
	#define HD44780_TWO_LINE			8
	#define HD44780_4_BIT				0
	#define HD44780_8_BIT				16

#define HD44780_CGRAM_SET				0x40

#define HD44780_DDRAM_SET				0x80


.equ	LCD_PORTDa 	= PORTA
.equ	LCD_DDRDa		= DDRA

.equ	LCD_D4 		= 3   ;grau
.equ	LCD_D5 		= 2   ;viol
.equ LCD_D6 		= 1   ;bla
.equ	LCD_D7 		= 0   ;grn

.equ	LCD_PORTCo 	= PORTB
.equ	LCD_DDRCo		= DDRB
.equ	LCD_RS		= 0    ;ws
.equ	LCD_EN		= 1    ;grau

.def 	tmp 		= R16   ; general usage, not preserved
.def 	tmpL		= R20   ; general usage, not preserved
.def 	tmpH		= R21   ; general usage, not preserved
.def 	outc		= R21   ; general usage, not preserved

;---------------------------------------------------------


.dseg
	.org SRAM_START
; Ribus must be in lower memory as ?H are set to 0
BufX:		.Byte 8 	  ;Input from USI
BufXEnd:	
BufY:		.BYTE 10
BufYEnd:	
FeBck:		.Byte 16		; EE no response, DD alive , D0 to D3 for valid orientatios
FeCol:		.Byte 16		; color


.cseg
; interrupt Jump Table attiny x4
	.org 0x0000
 	rjmp RESET 					;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
	reti; 		rjmp EXT_INT0 	;  2 IRQ0 
	reti; 		rjmp PCINT0 	;  3 PCINT0 
	reti;		rjmp 	PCINT1_Handler 		;  4 PCINT1  
	reti; 		rjmp WDT	 	;  5 Watchdog Time-out
	reti;		rjmp TIM1_CAPT	;  6 Timer1 Capture
	reti;rjmp 	Tim1_CompA			;  7 Timer1 Compare A
	reti; 		rjmp TIM1_COMPB	;  8 Timer1 Compare B
	reti; 		rjmp TIM1_OVF	;  9 Timer1 Overflow
	reti;	rjmp 	Tim0_CompA			; 10 Timer0 Compare A
	reti;	rjmp 	Tim0_CompB			; 11 Timer0 Compare B
	reti; 		rjmp TIM0_OVF	; 12 Timer0 Overflow
	reti; 		rjmp ANA_COMP 	; 13 Analog Comparator Handler
	reti; 		rjmp ADC 	 	; 14 Analog Conversion Complete
	reti; 	 	rjmp EE_RDY 	; 15 EEPROM Ready Handler
	reti;		rjmp USI_STR	; 16 USI Start
	reti; rjmp 	USI_OVF				; 17 USI Overflow


; Start of Program
RESET:
;here we go:
	ldi r16, high(RAMEND); Main program start
	out SPH,r16 ; Set Stack Pointer to top of RAM
	ldi r16, low(RAMEND)
	out SPL,r16
	rcall  LCD_Init
	sbi	DDRA, 7
	ldi outc,65
Lop1:
	ldi tmp,10
	rcall WaitMs
	cbi	PORTA, 7

	ldi tmp,15
	rcall WaitMs
	sbi	PORTA, 7

	mov tmp,outc
	rcall LCD_WriteData
	inc outc
	cpi outc,80
	brne lop1
	ldi outc,65
	rjmp Lop1

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


LCD_WriteNibble:
	sbi		LCD_PORTCo, LCD_EN

	sbrs	tmp, 0
	cbi		LCD_PORTDa, LCD_D4
	sbrc	tmp, 0
	sbi		LCD_PORTDa, LCD_D4
	
	sbrs	tmp, 1
	cbi		LCD_PORTDa, LCD_D5
	sbrc	tmp, 1
	sbi		LCD_PORTDa, LCD_D5
	
	sbrs	tmp, 2
	cbi		LCD_PORTDa, LCD_D6
	sbrc	tmp, 2
	sbi		LCD_PORTDa, LCD_D6
	
	sbrs	tmp, 3
	cbi		LCD_PORTDa, LCD_D7
	sbrc	tmp, 3
	sbi		LCD_PORTDa, LCD_D7

	cbi		LCD_PORTCo, LCD_EN
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_WriteData:
	sbi		LCD_PORTCo, LCD_RS
	push	tmp
	swap	tmp
	rcall	LCD_WriteNibble
	pop		tmp
	rcall	LCD_WriteNibble

	clr	tmp
Wait4xCycles:
	nop
	nop
	dec tmp
	brne Wait4xCycles	
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_WriteCommand:
	cbi		LCD_PORTCo, LCD_RS
	push	tmp
	swap	tmp
	rcall	LCD_WriteNibble
	pop		tmp
	rcall	LCD_WriteNibble
	ldi		tmp,2
	rcall	WaitMs
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_WriteString:
	lpm		tmp, Z+
	cpi		tmp, 0
	breq	exit
	rcall	LCD_WriteData
	rjmp	LCD_WriteString
exit:
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_WriteHexDigit:
	cpi		tmp,10
	brlo	Num
	ldi		r17,'7'
	add		tmp,r17
	rcall	LCD_WriteData
	ret
Num:
	ldi		r17,'0'
	add		tmp,r17
	rcall	LCD_WriteData
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_WriteHex8:
	push	tmp
	
	swap	tmp
	andi	tmp,0x0F
	rcall	LCD_WriteHexDigit

	pop		tmp
	andi	tmp,0x0F
	rcall	LCD_WriteHexDigit
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_WriteDecimal:
	clr		r14
LCD_WriteDecimalLoop:
	ldi		r17,10
;	rcall	div8u   TODO
	inc		r14
	push	r15
	cpi		tmp,0
	brne	LCD_WriteDecimalLoop	

LCD_WriteDecimalLoop2:
	ldi		r17,'0'
	pop		tmp
	add		tmp,r17
	rcall	LCD_WriteData
	dec		r14
	brne	LCD_WriteDecimalLoop2

	ret

;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_SetAddressDD:
	ori		tmp, HD44780_DDRAM_SET
	rcall	LCD_WriteCommand
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_SetAddressCG:
	ori		tmp, HD44780_CGRAM_SET
	rcall	LCD_WriteCommand
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
LCD_Init:
	sbi		LCD_DDRDa, LCD_D4
	sbi		LCD_DDRDa, LCD_D5
	sbi		LCD_DDRDa, LCD_D6
	sbi		LCD_DDRDA, LCD_D7
	
	sbi		LCD_DDRCo, LCD_RS
	sbi		LCD_DDRCo, LCD_EN

	cbi		LCD_PORTCo, LCD_RS
	cbi		LCD_PORTCo, LCD_EN

	ldi		tmp, 100
	rcall	WaitMs

	ldi		r17, 3
InitLoop:
	ldi		tmp, 0x03
	rcall	LCD_WriteNibble
	ldi		tmp, 5
	rcall	WaitMs
	dec		r17
	brne	InitLoop

	ldi		tmp, 0x02
	rcall	LCD_WriteNibble

	ldi		tmp, 1
	rcall	WaitMs

	ldi		tmp, HD44780_FUNCTION_SET | HD44780_FONT5x7 | HD44780_TWO_LINE | HD44780_4_BIT
	rcall	LCD_WriteCommand

	ldi		tmp, HD44780_DISPLAY_ONOFF | HD44780_DISPLAY_OFF
	rcall	LCD_WriteCommand

	ldi		tmp, HD44780_CLEAR
	rcall	LCD_WriteCommand

	ldi		tmp, HD44780_ENTRY_MODE |HD44780_EM_SHIFT_CURSOR | HD44780_EM_INCREMENT
	rcall	LCD_WriteCommand

	ldi		tmp, HD44780_DISPLAY_ONOFF | HD44780_DISPLAY_ON | HD44780_CURSOR_OFF | HD44780_CURSOR_NOBLINK
	rcall	LCD_WriteCommand

	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------

	
