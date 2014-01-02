;*************************************************************************
; ATMega 328P ADC testground
; Using Timer0 to trigger ADC and send 8 bit result via V24
; Timer1 toggles to charge/discharge capacitor on PB1 (e.g. 33n via 10k+)
; 
; Commands recived via V24 (500.000) or SPI (Slave):
; 0..9 	decimal value stored in acc (up to 2 bytes)
; a	*	set timer  cur0A (e.g. 16a sets to 0x10)
; b  *   	set timer  cur0P
; c		change calls all setups
; d       set default values
; f		set frequency (#todo)
; g       jump RESET
; h       Set V24 1MBaud
; i       enable Ints
; I       disable Ints
; l       load data from EEPROM
; m  *    select ADC Input (e.g. 2m selects ADC2)
; o	*	set timer1 cur1AL/H       
; p	*    set ADC prescaler 
; q  *	set timer1 prescaler cur1P
; r       send Conversion Result (myGP sndResult)
; R       do not send
; s       save Data to EEPROM
; v       send V24 debug output  (myGP sndDebug)
; V       do not send 
; z	*	Zweipunkt set min/max (#todo)
;
; Ports used:
; PD4 	  out set high before calling ADC, low on completion
; PD6       out Timer0 compA toggle output
; PD7  D7   in  Button (pup) (#todo)
; PB1  D9   out Timer1 compA toggle output to charge/discharge 
; PB2  D10  in  SS
; PB3  D11  in  MOSI
; PB4  D12  out MISO
; PB5  D13  in  SCK
;
; Ports used in:
; PCx  Ax	 Analog in
; 
; 
;*************************************************************************
.NOLIST
;;.include "m168pdef.inc"  ; AVR Studio 4.13 does not know a 328
.include "m328pdef.inc"
.LISTMAC
.include "macro.inc"
 
; register usage
.def	resL		= R0		; result of multiplication
.def	resH		= R1		; 
.def shaAdcs   = R2		; shadow of curAdcs
.def sha1P	= R3		; shadow of Timer1 prescaler
.def	spiRcv	= R4		; last received SPI value, 0 = no data received
.def	ten		= R10	; Fixed Value ten to multiply with
.def	cnt0L	= R11   	; counts tim0
.def	cnt0H	= R12	;	"
.def	ana		= R13	; last read analog value
.def	sregEE	= R14	; save status during EEprom or SPI access
.def	sregS	= R15	; save status during interrupt
.def tmp 		= R16   	; general usage, not preserved
.def	tmpL		= R17   	; general usage, not preserved
.def	tmpH		= R18   	; general usage, not preserved
.def	tmpC		= R19   	; general usage, not preserved
.def	accL		= R20	; accu for numerical
.def	accH		= R21	;   	"
.def	x22		= R22	; 
.def	x23		= R23	; 
.def	WL		= R24	; word general usage
.def	WH		= R25	; 
; XL			= R26 	; SPI queue pointer
; XH			= R27	; 	  "
; YL			= R28   	; 
; YH			= R29 	; 
; ZL			= R30   	; general usage, not preserved
; ZH			= R31	; general usage, not preserved


; GPIO use sbi cbi sbis sbic 
.equ	myGP		= GPIOR0	; flag register
.equ butD 	= 7		; previous state of button (ugly)
.equ	sndResult	= 6 		; send analog if 1 
.equ	sndDebug	= 5     	; send debug  if 1


;Data Segment	
.dseg
.org SRAM_START
; Configuration stored in EEPROM
config:
cur0A:	.BYTE 1		; OCR0A used to set value
cur0P: 	.BYTE 1		; Tim0 Prescaler (3 bits)
curMux: 	.BYTE 1		; ADC MUX3..0 
curAdcs: 	.BYTE 1		; ADC Register
cur1AL: 	.BYTE 1		; OCR1AL
cur1AH: 	.BYTE 1		; OCR1AH
cur1P: 	.BYTE 1	 	; Tim1 Prescaler (3 Bits)
curLo:	.BYTE 1		; low limit
curHi:	.BYTE 1		; high
configEnd:

spiData:
spiInL:	.BYTE 1		;
spiInH:	.BYTE 1		;
spiOutL:	.BYTE 1		;
spiOutH:	.BYTE 1		;
dbgB:     .BYTE 1        ; mark to find range issues
spiBuf: 	.BYTE 60	  	; output queue for SPI
spiBufEnd:
dbgE:     .BYTE 1        ; mark to find range issues
;Code Segment	
.cseg
; interrupt Jump Table atmega 328
.org 0x0000
	jmp RESET		; RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
.org 0x001C
	jmp TIM0_COMPA ; Timer0 Compare A Handler
.org 0x002A
	jmp ADC_COMP	; AD Conversion Complete
.org 0x0022
	jmp SPI_STC	; SPI Transfer Complete 

.org 0x0033
RESET:
	ldi tmp, high(RAMEND);
	out SPH,tmp ;
	ldi tmp, low(RAMEND)
	out SPL,tmp

; set constants and debug values
	ldi 	tmp,10
	mov 	ten,tmp
	sbi 	myGP,sndResult
	sbi 	myGP,sndDebug
	ldi 	tmp,'>'
	sts  dbgB,tmp
	ldi 	tmp,'<'
	sts  dbgE,tmp

; enable ports
	PortOutD 4 
	PortOutD 6
	PortOutB 1 
	PortOutB 4 
	PortPupD butD

; setup Serial
	ldi 	tmpL,1    ; 16Mhz 25=38400  16=57600  8=115200 1=500.000 0=1.000.000
	clr	tmpH
	rcall V24Init

; setup spi
	rcall spiSlaveInit;
; show version and reason for reset
	ldi  tmp, __HOUR__
	rcall spiSendByteShort
	ldi 	tmp,':'
	rcall spiSend
	ldi  tmp, __MINUTE__
	rcall spiSendByte
	in	tmp, MCUSR
	rcall spiSendByteShort
	clr  tmp
	out 	MCUSR,tmp
	ldi 	tmp,'>'
	rcall spiSend

; read EEPROM
	rcall LoadData
	lds 	tmp,curMux
	cpi 	tmp, 0xFF
	brne Reset_0
; use Default if not set
	rcall SetDefault

Reset_0:	
	rcall Setup
	sei
	rjmp Loop

; only if in Simulator:
Debug:
	ldi tmp,'c'
	rcall DoCmd
	ldi tmp,'q'
	rcall DoCmd
	ldi tmp,'5'
	rcall DoCmd
	ldi tmp,'6'
	rcall DoCmd
	ldi tmp,'7'
	rcall DoCmd	
	rjmp debug

Loop:
; if tim1 prescaler is 0, act as Zweipunktregler controlled by H/L
	tst	sha1P
	brne	LoopTim1		; 
	lds	tmp,curHi
	cp	tmp,ana	;Carry set if ana > Hi
	brcs	LoopToHi
	lds	tmp,curLo
	cp	ana,tmp	;Carry set if ana <=Lo
	brcc	LoopTim1
; Set out to increase ana
; have to use the force event depending on actual PIN
	sbic PINB,1
	rjmp	LoopTim1	;already set
	ldi	tmp, (1<<FOC1A)
	sts	TCCR1C, tmp
	rjmp	LoopTim1
LoopToHi:
; clear out to decrease ana
	sbis PINB,1
	rjmp	LoopTim1	;already clear
	ldi	tmp, (1<<FOC1A)
	sts	TCCR1C, tmp
LoopTim1:
; my masters voice ?
	lds 	tmp, UCSR0A
	sbrc tmp, RXC0		; is set if unread data
	rjmp LoopV24
; or SPI?
	tst spiRcv
	breq LoopNx
; Disable Ints before clearing spi
	in   sregEE,SREG
	cli
	mov 	tmp,spiRcv	
	clr 	spiRcv
	out 	SREG,sregEE
	rcall DoCmd
	rjmp  Loop
LoopNx:
; button (#todo)
	sbis	PIND, butD     ; is clear if pressed
	rjmp LoopBut
; not pressed, need to check if it was on before
	sbic myGP, butD
	rjmp Loop			; was not pressed
; was just released, so have to switch Analog back
	sbi	myGP,butD
	rjmp Loop
LoopBut:
	cbi	myGP, butD
	rjmp Loop
	
LoopV24:	
	rcall V24Receive
LoopCmd:
	rcall DoCmd
	rjmp  Loop

Setup:
; all and clear acc
	clr accL
	clr accH
	rcall Tim0Setup
	rcall Tim1Setup
	rcall ADC_Setup
	ret

DoCmd:
; process command in tmp
; rjmped routines should ret thus back from this also
	sbic	myGP,sndDebug
	rcall V24Send

	cpi	tmp,'a'	;set OCR0A
	brne C_a
	sts 	cur0A, accL
C_chng: 			; here if any setups were changed
	rcall Setup
	rjmp Show
C_a:
	cpi	tmp,'b' 	;set Timer Prescaler
	brne C_b
	sts 	cur0P, accL
	rjmp C_chng
C_b:
	cpi tmp,'c'	; changed 
	brne C_c
	rjmp C_chng
C_c:
	cpi tmp,'d'	; default
	brne C_d
	rcall SetDefault
	rjmp C_chng
C_d:
	cpi tmp,'g'	; reset
	brne C_g
	rjmp RESET
C_g:
	cpi tmp,'h'	; highspeed
	brne C_h
	clr	tmpH
	clr  tmpL
	rjmp V24Init
C_h:
	cpi tmp,'i'	; enable Ints
	brne C_i
	sei
	ret
C_i:
	cpi tmp,'I'	; disable Ints
	brne C_ii
	cli
	rjmp Show	
C_ii:
	cpi 	tmp,'l'	; load
	brne C_l
	rcall LoadData
	rjmp Show
C_l:
	cpi 	tmp,'m'	; set mux	
	brne C_m
	sts 	curMux,accL
	rjmp	c_chng
C_m:
	cpi 	tmp,'o'	; set Timer 1	
	brne C_o
	sts 	cur1AL,accL
	sts 	cur1AH,accH
	rjmp	c_chng
C_o:
	cpi 	tmp,'p'   ; prescaler
	brne C_p
	sts 	curAdcs,accL
	rjmp	c_chng
C_p:
	cpi 	tmp,'q'   ; prescaler
	brne C_q
	sts 	cur1P,accL
	rjmp	c_chng
C_q:
	cpi 	tmp,'s'	; save data
	brne C_s
	rcall SaveData
	rjmp Show
C_s:
	cpi 	tmp,'r'	; send result
	brne C_r
	sbi 	myGP,sndResult
	ret
C_r:
	cpi 	tmp,'R'	; don't send result
	brne C_rr
	cbi 	myGP,sndResult
	ret
C_rr:
	cpi tmp,'u'	;unused :-)
	brne C_u
	ret
C_u:
	cpi 	tmp,'v'	; send Debug
	brne C_v
	sbi 	myGP,sndDebug
	rjmp Show 	; feedback
C_v:
	cpi 	tmp,'V'	; don't send Debug
	brne C_vv
	cbi 	myGP,sndDebug
	ret
C_vv:
	cpi tmp,'w'	; w does nothing
	brne C_w
	ret
C_w:

;check for numbers, has to be last as temp is destroyed:
	subi	tmp,48
	brcs	C_nix	;tmp is 47 or less
	cp	tmp,ten
	brcc	C_nix	;tmp is ge 10
	rjmp	NumIn
C_nix:
	ldi  tmp,'?'
	sbic	myGP,sndDebug
	rcall V24Send
	ret


NumIn:
; Multiply acc by 10 then add tmp
	push	tmp
	mul  accL,ten
	mov  accL,resL
	add  accL,tmp
; high byte
	mov	tmp,resH
	clr  resH
	adc  tmp,resH 	; possible carry
	mul  accH,ten
	mov  accH,resL
	add	accH,tmp  ; don't care if overflow
	pop 	tmp
	ret

SetDefault:
; Timer0 set starting values 20Khz	 	   
	ldi 	tmp,99
	sts 	cur0A,tmp
	ldi 	tmp,2
	sts 	cur0P,tmp
; ADC from AD2
	ldi 	tmp,2
	sts 	curMux,tmp
	ldi	tmp, 5  ;Prescaler div 32
	sts 	curAdcs,tmp
; Timer1 set starting values 4Khz	 	   
	ldi 	tmp,99
	sts 	cur1AL,tmp
	clr  tmp
	sts 	cur1AH,tmp
	ldi 	tmp,4
	sts 	cur1P,tmp
; Low- and High for Zweipunkt
	ldi 	tmp,100
	sts 	curLo,tmp
	ldi 	tmp,200	
	sts 	curHi,tmp
	ret

txHead: .db '\n'," a  b  m  p   o    q  H  L",'\n', 0

ShowSpi:
; output to Spi 
 	ldi ZH, high(txHead*2);
	ldi ZL, low(txHead*2);
	rcall SpiSendString
	rcall SetDataPtr
ShowSpi_1:
	ld	tmp,Z+
	rcall SpiSendByte
	dec	tmpC
	brne	ShowSpi_1
	ret

Show:
; Show the current settings
	rcall ShowSpi
	sbis myGP,sndDebug  ;V24 only if enabled
	ret
	rcall V24SendCR
	rcall SetDataPtr
Show_1:
	ld	tmp,Z+
	rcall V24SendByte
	dec	tmpC
	brne	Show_1
	rcall V24SendCR
	ret

SetDataPtr:
; set pointers to acces current data area
; EEPROM starts from 0
	ldi 	tmpL,0
	ldi 	tmpH,0
; Memory length 
	ldi  tmpC, configEnd - config 
	ldi	ZH,high(config)
	ldi	ZL,low(config)
	ret

SaveData:
; to EEPROM
	rcall SetDataPtr
	rjmp EEPROM_Save
;
LoadData:
; from EEPROM
	rcall SetDataPtr
	rjmp EEPROM_Load

;
; Interrupt Handlers
;
TIM0_COMPA:
; Interrupt-Handler Timer 0
; start conversion
	in   sregS, SREG
	sts	ADCSRA,shaAdcs
	sbi 	PORTD,4		; indicate start conversion
; Counter (not used)
	dec  cnt0L 
	brne Tim0_nx
	dec	cnt0H
Tim0_nx:		
	out	SREG,sregS
	reti


ADC_COMP:
; Interrupt-Handler Conversion Complete
; send  data, no flags changed
	in   sregS, SREG 	; Angst	
	cbi 	PORTD,4		; indicate conversion complete
	lds 	ana,ADCH
	sbic	myGP,sndResult	; send it?
	sts  UDR0,ana		; brute force, no overrun checks
	out	SREG,sregS
	reti

;
; Setups
;
ADC_Setup:  
; Single conversion mode, 8 Bit from curMux
; provide: 
; 	curMux:   Selection of input (lowest 4 bits used)
; 	curAdcs:	Prescaler(lowest 3 bits used)
; 
;keep shadow of ADCSRA in shaAdcs
	push	tmp
	push tmpL
	lds	tmp, curAdcs
	andi tmp,0x07
	mov 	shaAdcs,tmp
	ldi	tmp, (1<<ADEN)+(1<<ADSC)+(0<<ADATE)+(0<<ADIF)+(1<<ADIE);  +(0<<ADPS2) + (0<<ADPS1) + (1<<ADPS0)
	or	shaAdcs,tmp
	sts	ADCSRA,shaAdcs
	sts  curAdcs,shaAdcs ; save to show settings
; ADLAR: ADC Left Adjust Result
	lds	tmpL, curMux
	andi tmpL,0x0F
	ldi	tmp, (0<<REFS1)+(1<<REFS0)+(1<<ADLAR) ;+(0<<MUX3)+(0<<MUX2)+(1<<MUX1)+ (0<<MUX0)
	or	tmp,tmpL
	sts	ADMUX,tmp
	sts  curMux,tmp
;ADCSRB select Timer0 CompA Trigger (did not work??)
	ldi	tmp, (0<<ADTS2)+(1<<ADTS1)+(1<<ADTS0)
	sts	ADCSRB,tmp
	pop  tmpL
	pop	tmp
	ret

Tim0Setup: 
; for  CTC= WGM 10
; provide:
; 	cur0A   Value for OCR0A
; 	cur0P   prescaler  
	push	tmp
	push tmpL
;A  Toggle OC0A                                      CTC
	ldi  tmp, (0<<COM0A1)+(1<<COM0A0)+(0<<COM0B1)+(0<<COM0B0)+(1<<WGM01)+(0<<WGM00)
	out	TCCR0A, tmp
;B                                                      by cur0P
	ldi 	tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02);  +(0<<CS02)+(0<<CS01)+(0<<CS00)
	lds  tmpL,cur0P
	andi tmpL,0x7
	or	tmp,	tmpL
	out  TCCR0B, tmp
	sts  cur0P,tmp
; Top by Compare A
	lds  tmp,cur0A
	out 	OCR0A, tmp
; Compare B not used
	ldi	tmp, 0xFF
	out 	OCR0B, tmp
; Interrupt 
	ldi 	tmp, (0<<OCIE0B)+(1<<OCIE0A)+(0<<TOIE0)
	sts	TIMSK0, tmp
	pop  tmpL
	pop	tmp
	ret

Tim1Setup: 
; for  CTC= WGM 0100
; provide:
; 	cur1AH   Value for OCR1A
; 	cur1AL 
; 	cur1P   prescaler (shadowed)
; 16 Bit Write H L Read L H
	push	tmp
	push tmpL
;A  Toggle OC1A                                      CTC
	ldi  tmp, (0<<COM1A1)+(1<<COM1A0)+(0<<COM1B1)+(0<<COM1B0)+(0<<WGM11)+(0<<WGM10)
	sts	TCCR1A, tmp
;B                                                            by cur1P
	lds  tmp, cur1P
	andi tmp,0x7
	mov 	sha1P,tmp
	ldi 	tmp, (0<<ICNC1)+(0<<ICES1)+(0<<WGM13)+(1<<WGM12)   ;+(0<<CS12)+(0<<CS11)+(0<<CS10)
	or	tmp, sha1P
	sts  TCCR1B, tmp
;C not used

; Top by Compare A
	lds 	tmp, cur1AH
	lds 	tmpL, cur1AL
	sts 	OCR1AH,tmp
	sts 	OCR1AL, tmpL
; Compare B not used
	ldi tmp, 0xFF
	sts 	OCR1BH, tmp
	sts 	OCR1BL, tmp
; Interrupt 
	ldi 	tmp,(0<<ICIE1)+ (0<<OCIE1B)+(0<<OCIE1A)+(0<<TOIE1)
	sts	TIMSK1, tmp
	pop  tmpL
	pop	tmp
	ret

.include "spiSlave.inc"
.include "V24.inc"
.include "eeprom.inc"

;AVRDUDE for Mini Pro:                   port                         hex file location
;avrdude -v -patmega328p -carduino -P\\.\COM6 -b57600 -D -V -Uflash:w:C:\one\proadc.hex:i

