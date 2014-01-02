;*************************************************************************
;
; SUDOKU Solver
;
;
;
;
.NOLIST
;;.include "m168pdef.inc"  ; AVR Studio 4.13 does not know a 328
.include "m328pdef.inc"
.LISTMAC
.include "macro.inc"
.LIST
 
; register usage
.def	resL		= R0		; result of multiplication
.def	resH		= R1		; 
.def	zero		= R2		; fixed value zero
.def	dwnL		= R4		; Down Counter
.def	dwnH		= R5		;     "
.def	dwnX		= R6		; Down Counter
.def	dwnXX	= R7		; Down Counter

.def	cnt0L	= R11   	; counts tim0
.def	cnt0H	= R12	;	"
.def	cnt0X	= R13	;    "
.def	sregEE	= R14	; save status during EEprom or SPI access
.def	sregS	= R15	; save status during interrupt
.def tmp 		= R16   	; general usage, not preserved
.def	tmpL		= R17   	; general usage, not preserved
.def	tmpH		= R18   	; general usage, not preserved
.def	tmpC		= R19   	; general usage, not preserved
.def	refP		= R20	; pointer to ref
.def fldNum   	= R21	; field working on (1..81) 
.def bckPL	= R22	; Pointer in backtrack
.def	bckPH	= R23	; 
.def	WL		= R24	; word general usage
.def	WH		= R25	; 
; XL			= R26 	; SPI queue pointer
; XH			= R27	; 	  "
; YL			= R28   	; 
; YH			= R29 	; 
; ZL			= R30   	; general usage, not preserved
; ZH			= R31	; general usage, not preserved


; GPIO use sbi cbi sbis sbic 
.equ	myGP		= GPIOR0		; 
.equ	gpGameFlash	= 6 		; 1: read game from Flash else V24
.equ	gpSndDebug	= 5     	; 1: send debug info
.equ gpSimulator    = 4       ; 1: running in Simulator
.equ gpSolvAll      = 3       ; 1: dont stop after the first Solution
.equ gpSelfTest     = 2       ; 1: play all flash games on Init
.equ gptoEprom     	= 1       ; 1: write result to Eprom (#todo)

; Determine Size of fields 
.SET GameSize = 9

.IF  GameSize == 9
.equ  fldAnz = 10		; # of fields +1 xx +1
.equ	 rcAnz = 3		; # of r/c
.equ  chkAnz = 8         ; # of adjacend fields to check

.ELIF GameSize == 81
.equ  fldAnz = 82		; # of xx +1
.equ	 rcAnz =   9
.equ  chkAnz = 20

.ELSE 
.WARNING "Please .SET GameSize" 
.ENDIF


;Data Segment	
.dseg
.org SRAM_START
; All arrays start with index 1, use [0] to help debug
fld: 	.BYTE  fldAnz	; value of field
fldEnd:
ref: 	.BYTE  fldAnz	; order to process fields 1..81 0=end
refEnd:
exc: 	.BYTE  10		; exlusion list one entry each for 0..9
excEnd:
chkDumm:	.BYTE  1		; to contain limiter
chk: 	.BYTE  chkAnz+1	;  list of fields to check for given +1 for terminating 0
chkEnd:
gamePL:	.BYTE  1		; The game we play
gamePH:	.BYTE  1		; The game we play
cur0P:	.BYTE  1		; Timer0 Setting
cur0A:	.BYTE  1		; 
bck:    	.BYTE  1      	; backtrack is a really looong list, re-use it for
dof: 	.BYTE  fldAnz	
		.BYTE  400	; just a number to see RAM usage
bckEnd:
endInd:   .BYTE 1		; should not be overwritten


;Code Segment	
.cseg
; interrupt Jump Table atmega 328
.org 0x0000
	jmp RESET		; RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
.org 0x001C
	jmp TIM0_COMPA ; Timer0 Compare A Handler

.org 0x0033
RESET:
	ldi tmp, high(RAMEND);
	out SPH,tmp ;
	ldi tmp, low(RAMEND)
	out SPL,tmp
; set misc variables
	clr 	zero
; set configuration
	sbi	myGP, gpSimulator
	cbi	myGP, gpSolvAll
	sbi	myGP, gpGameFlash
	sbi	myGP, gpSndDebug	
	cbi	myGP, gpSelfTest	
	cbi	myGP, gpToEprom	
; setup Serial
	ldi 	tmpL,25    ; 16Mhz: 25=38400(0.2%) 16=57600(2.1%) 8=115200(3.5%) 1=500.000 0=1.000.000
	clr	tmpH
	rcall V24Init
; show version and reason for reset
	ldi  tmp, __HOUR__
	rcall V24SendByteShort
	ldi 	tmp,':'
	rcall V24Send
	ldi  tmp, __MINUTE__
	rcall V24SendByte
	in	tmp, MCUSR
	rcall V24SendByteShort
	clr  zero
	out 	MCUSR,zero
; setup Timer0 for 1Khz	 	   
	ldi 	tmp,3
	sts 	cur0P,tmp
	ldi 	tmp,249
	sts 	cur0A,tmp
	rcall Tim0Setup
; ports
	PortOutD 2	; misc performance indication
	PortOutD 4	; down/back indication
	PortOutD 6     ; OCR0A
	sei

MainNew:
	rcall SudoInit
	SetZCode Games  ;This is the first Game to play
	sts gamePL,ZL
	sts gamePH,ZH
; if playing from Flash and selftest do it now
	sbis	myGP,gpGameFlash
	rjmp	Main
	sbis	myGP,gpSelfTest
	rjmp	Main

MainNew10:
	SetZCode Games  ;This is the first Game to play
	rcall SelfTest

Main:
	ldi tmp,'>'
	rcall V24Send
	rcall V24Receive
LoopCmd:
	rcall DoCmd
	rjmp	Main

SelfTest:
; runs all test games starting from Z^
	sbi	myGP,gpGameFlash	
	sts gamePL,ZL
	sts gamePH,ZH
SelfTest10:
	rcall ReadGame
	tst 	tmp
	brne SelfTestDone
	rcall SolveSud

	rcall ValidateFld
	rjmp	SelfTest10
SelfTestDone:
	ret

txHlp: .db '\n'," dof D exc E f123X g n s t T v",'\n', 0

DoCmd:
; process command in tmp
; rjmped routines should ret thus back from this also
; f fielddata
; g go
; else ?
	sbic	myGP,gpSndDebug
	rcall V24Send

	cpi	tmp,'d' 	; show Dof
	brne C_d
	rcall V24SendCR
	rjmp ShowDof
C_d:

	cpi	tmp,'D' 	; calculate Dof
	brne C_dd
	rcall BuildDof
	rjmp ShowDof
C_dd:

C_e:	 ; show exc
C_ee: ; build exc

	cpi	tmp,'f'	; field data to come
	brne C_f
	cbi 	myGP, gpGameFlash
	rjmp	ReadGame
C_f:

	cpi	tmp,'g' 	; go solve current
	brne C_g
	rjmp	SolveSud
C_g:

	cpi	tmp,'h' 	; help
	brne C_h
	ldi ZH, high(txHlp*2);
	ldi ZL, low(txHlp*2);
	rjmp V24SendString
C_h:
 
	cpi	tmp,'n' 	;restart
	brne C_n
C_toMainNew:
	pop	tmp		;
	pop  tmp
	rjmp MainNew
C_n:
	
	cpi	tmp,'s' 	; show field
	brne C_s
	rcall V24SendCR
	rjmp ShowFld
C_s:

	cpi	tmp,'t' 	; test games
	brne C_t
	SetZCode Games
	rjmp SelfTest
C_t:

	cpi	tmp,'T' 	; test schwer
	brne C_tt
	SetZCode Schwer
	rjmp SelfTest
C_tt:

	cpi	tmp,'v' 	; validate
	brne C_v
	rjmp ValidateFld
C_v:

C_nix:
	ldi  tmp,'?'
	sbic	myGP,gpSndDebug
	rcall V24Send
	ret


TIM0_COMPA:
; Interrupt-Handler Timer 0
	in   sregS, SREG
; Counter
	inc  cnt0L 
	brne Tim0_nx
	inc	cnt0H
	brne Tim0_nx
	inc	cnt0X
Tim0_nx:		
	out	SREG,sregS
	reti

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


.include "sudokGame.inc"
.include "V24.inc"
.include "sudokLup.inc"

