;*************************************************************************
; ATMega 328P first steps
; IN   OUT SBIS SBIC CBI SBI
; LDS  STS combined with SBRS, SBRC, SBR, and CBR
; Ports
;  0 7 PD0
;  8    PB0
; 13   PB5  Sclock(LED)
;*************************************************************************
.NOLIST
.include "m328Pdef.inc"
.LIST
.LISTMAC
 

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
; interrupt Jump Table atmega168
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
	reti; rjmp TIM0_COMPA				; 10 Timer/Counter0 Compare A
	reti; TIM0_COMPB				; 11 Timer/Counter0 Compare B
	reti; 		rjmp TIM0_OVF	; 12 Timer/Counter0 Overflow
	reti; 		rjmp ANA_COMP 	; 13 Analog Comparator Handler
	reti; 		rjmp ADC 	 	; 14 Analog Conversion Complete
	reti; 	 	rjmp EE_RDY 	; 15 EEPROM Ready Handler
	reti;		rjmp USI_STR	; 16 USI Start
	reti;		rjmp USI_OVF	; 17 USI Overflow

; Start of Program
	.org 0x0050
RESET:
;here we go:
	ldi tmp, high(RAMEND); Main program start
	out SPH,tmp ; Set Stack Pointer to top of RAM
	ldi tmp, low(RAMEND)
	out SPL,tmp
	rcall USART_Init
	ldi tmp,'a'
go1:
	rcall USART_Send
	ldi tmp,'b'
	rcall USART_Send
	ldi tmp,'c'
	rcall USART_Send
	rcall USART_Receive
	rjmp go1

USART_Send:
; Wait for empty transmit buffer
	push tmp
USART_Send1:
	lds  tmp,UCSR0A
	sbrs tmp,UDRE0
	rjmp USART_Send1
; Put data into buffer
	pop  tmp
	sts  UDR0,tmp
	ret

USART_Receive:
; Wait for data to be received
	lds tmp, UCSR0A
	sbrs tmp, RXC0
	rjmp USART_Receive
	; Get and return received data from buffer
	lds tmp, UDR0
	ret

; configure Ports outgoing to zero
USART_Init:
	; Set baud rate 16 Mhz 38.4
	ldi tmp,0
	sts UBRR0H, tmp
	ldi tmp,25
	sts UBRR0L, tmp
	; Enable receiver and transmitter
	ldi tmp, (1<<RXEN0)|(1<<TXEN0)
	sts UCSR0B,tmp
	; Set frame format: 8data, 2stop bit
	ldi tmp, (1<<USBS0)|(3<<UCSZ00)
	sts UCSR0C,tmp
	ret



