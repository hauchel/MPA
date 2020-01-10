;*************************************************************************
; Attiny x5 lamp controller
;*************************************************************************
.NOLIST
.include "tn45def.inc"
.include "macro.inc"
.LIST
.LISTMAC

.equ fldAnz 	=  81		
.equ	rcAnz 	=  9
.equ chkAnz 	= 20
.equ chkAnzRom	= 22

; USI Definitions
.equ	pollChar 	= '#'
.equ	devMask 	= 0xF8	; if byte and Mask <>0 -> device Select

;  register usage  *************************************************************************
.def	resL		= R0		; 
.def	resH		= R1		; 
.def	usiD		= R2		; reserved for usage during USI
.def	usiNum	= R3		; my usi number 0x0n
.def	bufRcvIP	= R4		; Receive
.def	bufRcvOP	= R5		; 
.def	BufSndIP	= R6		; Send Buffer
.def	BufSndOP	= R7		; 
.def	zero 	= R8		; set me
.def	inByte	= R9		; incoming Byte built by tim1
.def	sigCnt	= R10		; count of signal duration
.def	nosCnt	= R11   	; count of no signal duration
;.def			= R12   	; count of no signal duration
.def cnt0		= R13		; 
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
BufRcv:	.BYTE 20		  ;SPI Input Buffer
BufRcvEnd: 
BufSnd:	.BYTE 20		  ;SPI Output Buffer
BufSndEnd:				; must be <00FE as assuming XH 0
fld: 	.BYTE fldAnz+1		; value of field
fldEnd:
dof: 	.BYTE  fldAnz+1
bck:
ref:
srt:		.Byte 1

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
	reti; 	rjmp Tim0_CompA	; 11 Timer0 Compare Match A
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


.MACRO PfiHigh
	sbi PORTB, pnPfi
.ENDMACRO
.MACRO PfiLow
	cbi PORTB,pnPfi
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
	

; configure from EEPROM location 
	clr tmpH
	ldi tmpL,1
	rcall EEPROM_Read	; Number
	mov  tmpL,tmp		; test
	andi tmpL,devMask	; 
	breq Config20		; tmp contains 0x
Config7:	  
	ldi tmp,7			;^g as device for test
Config20:	
	mov usiNum,tmp
	rcall USI_Setup85	
	sei

MainLoop:	
	rcall USI_Getch
	rcall DoCmd
	rjmp	MainLoop


DoCmd:
; process command in tmp
; rjmped routines should ret thus back from this also
; 
	cpi	tmp,'a' 	; all test simple
	brne C_a
	sbi  usiGP,gpUsiActive
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

	cpi	tmp,pollChar 	; poll char should it arrive here?
	brne C_poll
	ret
C_poll:


; unknown command
	ldi	tmp,'?'
	rjmp USI_Putch
	ret


BuildInfo:
	push tmp
	ldi  tmp, __HOUR__
	rcall V24SendByteShort
	ldi 	tmp,':'
	rcall V24Send
	ldi  tmp, __MINUTE__
	rcall V24SendByte
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
	pop tmp
	ret

; Show routines use Y and tmpP should not change any regs as called from within debug mode
ReadGame:
	setXPtr fld+1		; value stored in field by X,first goes to [1]
	ldi fldNum,1
ReadGameNext:
	rcall USI_GetCh
; ignore 
	cpi tmp,pollChar
	breq ReadGame
	cpi tmp,' '
	breq ReadGame
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
	ldi tmp,'!'
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

ShowDof:
; show calculated Dof
	PushYtmp
	ldi	tmp,1
	SetYIdx 	dof, tmp
	rcall	ShowFldDof
	PopYtmp
	ret

ShowFld:
; show Field 
	PushYtmp
	ldi	tmp,1
	SetYIdx 	fld, tmp
	rcall	ShowFldDof
	PopYtmp
	ret

ShowFldDof:
; show Y^ field or dof or save 
	push tmpC 
	ldi	tmpC,fldAnz	
ShowSudLine10:
	ld	tmp,Y+
	subi tmp,-48       ;'0' 0x30 to '9'
	rcall V24Send
	dec	tmpC
	brne ShowSudLine10
	ldi tmp,'X'
	rcall V24Send
	pop tmpC
	ret
.include "tccp.inc"
;;;;;;;.include "sudokGame.inc"
.include "eeprom.inc"

; Fuse Bytes:
; 
;           	7 6 5 4  3 2 1 0   	Changed
; lfuse   E2   1 1 1 0  0 0 1 0	CKDIV8	 
; hfuse  	D7	1 1 0 1  0 1 1 1  	EESAVE
; efuse	FE	1 1 1 1  1 1 1 0	SELFPRGEN 					
