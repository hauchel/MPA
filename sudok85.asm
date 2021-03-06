;*************************************************************************
; SUDOKU Solver f�r attiny85. Ein Versuch
; use spii
; using tabwidth 5
;*************************************************************************

.NOLIST
.include "tn45def.inc"
.include "macro.inc"
.LIST
.LISTMAC

; Build Options
.SET Statistics=  0		; 1: create statistic using 7 registers and performance
.equ fldAnz 	=  81		
.equ	rcAnz 	=  9
.equ chkAnz 	= 20
.equ chkAnzRom	= 22
.equ  excAnz	= 10		; exclusion list always 0..9

; USI Definitions
.equ	pollChar 	= '#'	; ignored in all directions
.equ	ackChar 	= '*'	; EOD by device after much data
.equ	devMask 	= 0xF8	; if byte and Mask <>0 -> device Select

;  register usage  *************************************************************************
.def	resL		= R0		; 
.def	resH		= R1		; 
.def	usiD		= R2		; reserved for usage during USI
.def	usiNum	= R3		; my usi number 0x0n
.def	bufRcvIP	= R4		; Receive  Buffer Pointer
.def	bufRcvOP	= R5		; 
.def	BufSndIP	= R6		; Send Buffer
.def	BufSndOP	= R7		; 
.def	auxL		= R8		; aux, not preserved
.def	auxH		= R9		;	"     
.def	zero 	= R10	; set me
.def	nosCnt	= R11   	; count of no signal duration
;.def			= R12   	; 
.def	cnt0		= R13		; count of Tim 0 Ints
.def	sregEE 	= R14		; decremented during tim0
.def	sregS	= R15		; saves status during interrupt
.def tmp 		= R16   	; general usage, not preserved
.def	tmpC		= R17	;	" 
.def	tmpL		= R18   	; 	"upper 4 register pairs
.def	tmpH		= R19   	;
.def	refP		= R20	; pointer to ref
.def fldNum   	= R21	; field working on (1..81) 
.def bckPL	= R22	; Pointer in backtrack
.def	bckPH	= R23	; 
.def	WL		= R24   	; upper 4 register pairs
.def	WH		= R25   		;
; XL			= R26 		; 
; XH			= R27		; 
; YL			= R28   		; 
; YH			= R29		; 
; ZL			= R30       	; 
; ZH			= R31	    	;


;Data Segment	
.dseg
.org SRAM_START
; SPI 
BufRcv:	.BYTE 20		  ;SPI Input Buffer
BufRcvEnd: 
BufSnd:	.BYTE 10		  ;SPI Output Buffer
BufSndEnd:			
; must be <00FE as assuming XH 0
x128:				; 128 bytes used for XModem Data, shared with
fld: 	.BYTE  fldAnz+1	; value of field
fldEnd:
exc: 	.BYTE  excAnz		; exlusion list one entry each for 0..9, 0 not used
excEnd:
refLen:	.BYTE  1			; contains the number of ref entries (before the terminating  0), set by BuildDof
ref: 	.BYTE  fldAnz		; contains the changeable fields from 1..81,if 0=end
refEnd:
; This can be overwritten

dof: 
chk:
bck:
srt:		.Byte 1

endInd:

;Code Segment	
.cseg
; interrupt Jump Table attiny 85
	.org 0x0000
 	rjmp RESET 				;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
	reti; 	rjmp INT0 		;  2 External Interrupt
	reti;	rjmp PCINT0_Handler	;  3 PCINT0 Handler
	reti; 	rjmp TIM1_COMPA 	;  4 Timer1 Compare Match A 
	reti;	rjmp TIM1_OVF 		;  5 Timer1 Overflow Handler
	reti;	rjmp TIM0_OVF 		;  6 Timer0 Overflow Handler
	reti;  	rjmp EE_RDY 		;  7 EEPROM Ready Handler
	reti; 	rjmp ANA_COMP 		;  8 Analog Comparator Handler
	reti; 	rjmp ADC	 		;  9 Analog Conversion Complete
	reti; 	rjmp Tim1_CompB	; 10 Timer1 Compare Match B
	rjmp Tim0_CompA			; 11 Timer0 Compare Match A
	reti; 	rjmp Tim0_CompB	; 12 Timer0 Compare Match B
	reti; 	rjmp WDT	 		; 13 WDT Watchdog Time-out
	reti;	rjmp USI_START  	; 14 USI Start
	rjmp	USI_OVF  			  	; 15 USI Overflow
	

;Port usage
.equ	pnLed	=3 ; LED on PB3    RES 3 4 GND
.equ pnPfi  	=4 ; 
.equ pnMiso  	=1 ; 


; GPIO use sbi cbi sbis sbic 
.equ	usiGP		= GPIOR1	;  
.equ	gpUsiActive 	= 7 		; 1: if USI selected by Master	
.equ gpUsiKnown	= 6		; 1: UsiNumber known to store raw data,	0 to evl signal
.equ	gpUsiSend		= 5     	; 1: Send Buffer not empty
.equ	gpUsiDebug	= 4     	; 1: Debug Mode
.equ inDataValid	= 3     	; 1 if inData is valid
.equ anaMes      	= 2       ; 1 to return count of signal  

; GPIOR0 use sbi cbi sbis sbic 
.equ	myGP			= GPIOR0	;
.equ gpSwp		= 7		; local usage in Sort 1=swap occured during sort
.equ gpInfo		= 6		; 1: show bck during solution
.equ gpAutorun      = 5       ; 1: start solving after game is read (use go)
.equ gpErrWait		= 4		; 1: Wait for V24 after Error
.equ	gpGameFlash	= 3 		; 1: read game from Flash else V24
.equ	gpSndDebug	= 2     	; 1: send debug info


.MACRO PfiHigh
	sbi PORTB, pnPfi
.ENDMACRO
.MACRO PfiLow
	cbi PORTB, pnPfi
.ENDMACRO
.MACRO PfiTog
	sbi PINB, pnPfi
.ENDMACRO

.MACRO LedOn
	sbi PORTB, pnLed
.ENDMACRO
.MACRO LedOff
	cbi PORTB, pnLed
.ENDMACRO
.MACRO LedTog
	sbi PINB, pnLed
.ENDMACRO

RESET:
;here we go:
	ldi tmp, low(RAMEND)
	out SPL,tmp
	ldi tmp, high(RAMEND)
	out SPH,tmp 

; evl MCUSR
;  WDRF: Watchdog Reset  is reset by a Power-on Reset, or by writing 0
;  BORF: Brown-out Reset is set if a Brown-out Reset occurs. reset by a Power-on Reset, or by writing 0
;  EXTRF:External Reset  is set if an External Reset occurs. reset by a Power-on Reset, or by writing 0
;  PORF: Power-on Reset  is set if a Power-on Reset occurs.  reset only by writing a logic zero to the flag.
; seems simulator does not set this
	in		tmp,MCUSR
; configure Ports outgoing to zero
	PortOutB	pnLed
	PortOutB	pnMiso
	PortOutB	pnPfi
	rcall USI_Setup85	
	rcall Tim0_Setup85

; configure from EEPROM location 
	clr tmpH
	ldi tmpL,1
	rcall EEPROM_Read	; Number in tmp
	cpi	tmp,'S'
	breq ConfigSimu
	mov  tmpL,tmp		; test if valid
	andi tmpL,devMask	; 
	breq Config20		; tmp contains 0x
ConfigSimu:
	sei
	rcall	showFld
Config7:	  
	ldi tmp,7			;^g as device for test
Config20:	
	mov usiNum,tmp
; fill x-buffer with chars
	SetYPtr x128
	ldi tmpC,128
	ldi tmp,pollChar
Config30:
	st	Y+,tmp
	dec 	tmpC
	brne	Config30
	sei



MainLoop:	
	rcall USI_Getch
	rcall DoCmd
	rjmp	MainLoop

.include "tccp.inc"
.include "eeprom.inc"

; Application starts here:
DoCmd:
; process command in tmp
; rjmped routines should ret thus back from this also
; 
	cpi	tmp,'a' 	; all test simple
	brne C_a
	sbi	UsiGP,gpUsiActive
	ret
C_a:

	cpi	tmp,'b' 	; 
	brne C_b
	rjmp	BuildInfo
C_b:

	cpi	tmp,'f' 	; 
	brne C_f
	rjmp  ShowFld
C_f:

	cpi	tmp,'g' 	; 
	brne C_g
	rjmp  ReadGame
C_g:

	cpi	tmp,':' 	; 
	brne C_dop
	rjmp  ReadGame
C_dop:

	cpi	tmp,'i' 	; all test simple
	brne C_i
	rjmp  V24SendIdx
C_i:


	cpi	tmp,'l' 	; all test simple
	brne C_l
	LedOn
	ret
C_l:

	cpi	tmp,'k' 	; all test simple
	brne C_k
	LedOff
	ret
C_k:
	cpi	tmp,'x' 	; 
	brne C_x
	rjmp  ReadX128
C_x:

	cpi	tmp,'y' 	; 
	brne C_y
	rjmp  ShowX128
C_y:

	cpi	tmp,pollChar 	; poll char should it arrive here?
	brne C_poll
	ret
C_poll:


	
; unknown command
	ldi	tmp,'?'
	rjmp USI_Putch
	ret

ErrHand:
	ret
BuildInfo:
	push tmp
	ldi  tmp, __DAY__
	rcall V24SendByteShort
	ldi  tmp, __HOUR__
	rcall V24SendByteShort
	ldi  tmp, __MINUTE__
	rcall V24SendByteShort
/*   Enable in case...
;	in	tmp, MCUSR
;	rcall V24SendByteShort
;	clr  tmp
;	out 	MCUSR,tmp
; Fuses
	push	tmpL
	push	tmpH
	rcall ReadFuses
	push tmp ;Efuse
	mov  tmp,tmpL
	rcall V24SendByte
	mov  tmp,tmpH
	rcall V24SendByte
	pop 	tmp
	rcall V24SendByte
	pop 	tmpH
	pop	tmpL
*/
	pop tmp
	ret

; Show routines use Y and tmpP should not change any regs as called from within debug mode
ReadX128:
	setXPtr x128		; value stored in field by X
	ldi tmpC,128
ReadX128Next:
	rcall USI_GetCh
	st	X+,tmp		; store in field
	dec  tmpC			
	brne	ReadX128Next	; stop if enuff
	ldi tmp,ackChar
	rjmp V24Send

; Show routines use Y and tmpP should not change any regs as called from within debug mode
ReadGame:
	setXPtr fld+1		; value stored in field by X,first goes to [1]
	ldi fldNum,1
ReadGameNext:
	rcall USI_GetCh
; ignore 
	cpi tmp,pollChar
	breq ReadGameNext
	cpi tmp,' '
	breq ReadGameNext
ReadGameReceived:
	mov	tmpL,tmp		;preserve in case of error
	subi	tmp,48
	brcs	ReadGameErr	;tmp is less '0'
	cpi	tmp,10
	brcc	ReadGameErr	;tmp is ge 10
; here tmp is valid number
	st	X+,tmp		; store in field
	inc 	fldNum		; now contains the field just stored 		
	cpi	fldNum,fldAnz	; stop if enuff
	brne ReadGameNext
ReadGameDone:
	ldi tmp,ackChar;
	rcall V24Send
	mov	tmp,fldnum
	rcall V24SendByteShort
	ret
ReadGameErr:
	ldi tmp,'E'
	rcall V24Send
	mov tmp,tmpL
	rcall V24Send
	mov	tmp,fldnum
	rcall V24SendByteShort
	ret

ShowX128:
; show 
	PushYtmp
	push	tmpC
	SetYPtr 	x128
	ldi		tmpC,fldAnz
ShowX128_10:
	ld	tmp,Y+
	rcall V24Send
	dec	tmpC
	brne ShowX128_10
	ldi tmp,ackChar
	rcall V24Send
	pop  tmpC
	PopYtmp
	ret

ShowDof:
; show calculated Dof
	PushYtmp
	SetYPtr 	dof+1
	ldi		tmp,fldAnz
	rcall	ShowFldDof
	PopYtmp
	ret

ShowFld:
; show Field 
	PushYtmp
	SetYPtr 	fld+1
	ldi 		tmp,fldAnz
	rcall	ShowFldDof
	PopYtmp
	ret

ShowFldDof:
; show Y^ field or dof or save for tmp chars converting 0 to 9
	push	tmpC
	mov	tmpC,tmp
ShowSudLine10:
	ld	tmp,Y+
	subi tmp,-48       ;'0' 0x30 to '9'
	rcall V24Send
	dec	tmpC
	brne ShowSudLine10
	ldi tmp,ackChar
	rcall V24Send
	pop tmpC
	ret

ShowRef:
	ret
ShowBck:
	ret
romBeg:
	ret	;#TODO

	
;**************** 
Tim0_CompA:
; does sending et al
; bitcnt on entry 
;   0		return, possible to send new data
;   1       don't set out (EOByte)
;   2..x    set out       
;
	in  	sregS, SREG	
	inc	cnt0
	out	SREG,sregS
	reti

Tim0_Setup85: 
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
; 0    1    1    clkI/O/64 (From prescaler) 
; 1    0    0    clkI/O/256 (From prescaler)
; 1    0    1    clkI/O/1024 (From prescaler)
; 1    1    0    External clock source on T0 pin. Clock on falling edge.
; 1    1    1    External clock source on T0 pin. Clock on rising edge.
	ldi tmp, (0<<FOC0A)+(0<<FOC0B)+(0<<WGM02)+(1<<CS02)+(0<<CS01)+(0<<CS00)
	out     TCCR0B, tmp
; Top 
	ldi 	tmp, 200
	out 	OCR0A, tmp
; Compare
	ldi tmp, 0xFF
	out 	OCR0B, tmp
; Interrupt Enable ; two timers here!!!
	ldi tmp, (0<<OCIE0B)+(1<<OCIE0A)+(0<<TOIE0)
	out     TIMSK, tmp
	ret



.include "sudokGame.inc"
; Fuse Bytes:
; 
;           	7 6 5 4  3 2 1 0   	Changed
; lfuse   E2   1 1 1 0  0 0 1 0	CKDIV8	 
; hfuse  	D5	1 1 0 1  0 1 0 1  	EESAVE, BODLEVEL
; efuse	FE	1 1 1 1  1 1 1 0	SELFPRGEN 					


; avrdude -v -patmega328p -carduino -P\\.\COM6 -b57600 -D -V -Uflash:w:path\sudoku.hex:i


