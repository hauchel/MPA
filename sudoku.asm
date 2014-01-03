;*************************************************************************
;
; SUDOKU Solver for Arduino 
;
;
; Build Options
.SET BuildSimulator = 0	; 1 if built for debugging
.SET GameSize = 81		; number of fields 9, 81 or 16(#todo)


.NOLIST
.IF  BuildSimulator == 1
	.include "m168pdef.inc"  ; AVR Studio 4.13 does not know a 328
.ELSE 
	.include "m328pdef.inc"
.ENDIF

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
.def	tmpC		= R17   	; general usage, not preserved
.def	tmpL		= R18   	; general usage, not preserved
.def	tmpH		= R19   	; general usage, not preserved
.def	refP		= R20	; pointer to ref
.def fldNum   	= R21	; field working on (1..81) 
.def bckPL	= R22	; Pointer in backtrack
.def	bckPH	= R23	; 
.def	WL		= R24	; word general usage
.def	WH		= R25	; 
; XL			= R26 	; all index-regs not preserved
; XH			= R27	; 
; YL			= R28   	; 
; YH			= R29 	; 
; ZL			= R30   	; 
; ZH			= R31	;


; GPIOR0 use sbi cbi sbis sbic 
.equ	myGP		= GPIOR0		;
.equ gpSwp		= 7		; local usage in Sort 1=swap occured during sort
.equ gpInfo		= 6		; 1: show bck during solution
.equ gpErrWait		= 4		; 1: Wait for V24 after Error
.equ	gpGameFlash	= 3 		; 1: read game from Flash else V24
.equ	gpSndDebug	= 2     	; 1: send debug info
.equ gpSelfTest     = 1       ; 1: play all flash games on Init
.equ gpSingle     	= 0       ; 1: one step down until no more possible values
; GPIOR1 >1F, use in out 
.equ	myG1		= GPIOR1		; here those with less importance
.equ g1Simulator    = 4       ; 1: running in Simulator (not used)
.equ g1SolvAll      = 3       ; 1: dont stop after the first Solution

.equ g1ToEprom     	= 1       ; 1: write result to Eprom (#todo)


.IF  GameSize == 9
.equ  fldAnz = 9		; # of fields
.equ	 rcAnz = 3		; # of row/column
.equ  chkAnz = 8         ; # of adjacent fields to check

.ELIF GameSize == 81
.equ  fldAnz = 81		; # of xx +1
.equ	 rcAnz =   9
.equ  chkAnz = 20

.ELSE 
.WARNING "Please .SET GameSize" 
.ENDIF


;Data Segment	
.dseg
.org SRAM_START
; All arrays start with index 1, use [0] to help debug
fld: 	.BYTE  fldAnz+1	; value of field
fldEnd:
ref: 	.BYTE  fldAnz+1	; order to process fields 1..81 0=end
refEnd:
exc: 	.BYTE  10			; exlusion list one entry each for 0..9, 0 not used
excEnd:
chkDumm:	.BYTE  1			; to contain limiter
chk: 	.BYTE  chkAnz+1	;  list of fields to check for given +1 for terminating 0
chkEnd:
gamePL:	.BYTE  1			; ^to game in flash
gamePH:	.BYTE  1			; 
cur0P:	.BYTE  1			; Timer0 Setting
cur0A:	.BYTE  1			; 
bck:    	.BYTE  1      		; backtrack is a really looong list, re-use it for
dof: 	.BYTE  fldAnz+1	; contains temp. dof for each field 
srt:		.BYTE  fldAnz+1	; helps to sort the ref, contains the dof for corresponding ref
		.BYTE  400		; just a number to see RAM usage
bckEnd:
endInd:   .BYTE 1			; should not be overwritten
sav:		.BYTE  fldAnz+1	; save game area 


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
	sbi	myGP, gpErrWait
	sbi	myGP, gpGameFlash
	sbi	myGP, gpSndDebug	
	cbi	myGP, gPSelfTest	
	sbi	myGP, gpInfo

	ldi tmp, (0<<g1SolvAll)+(1<<g1ToEprom)
	out	myG1,tmp

; setup Serial
	ldi 	tmpL,25    ; 16Mhz: 25=38400(0.2%) 16=57600(2.1%) 8=115200(3.5%) 1=500.000 0=1.000.000
	clr	tmpH
	rcall V24Init

NoDebug:
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
; ports for PerFormance Indication
	PortOutD 2	; high during buildref 
	PortOutD 3	; Phases:  H Read L BuildDof H Sort L Solve H Validate L show results 
	PortOutD 4	; down/back indication
.MACRO PfiHigh
	sbi PORTD, @0
.ENDMACRO
.MACRO PfiLow
	cbi PORTD, @0
.ENDMACRO
.MACRO PfiTog
	sbi PIND, @0
.ENDMACRO

	PortOutD 6     ; (fixed) OCR0A toggle with 500Hz 
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

MainTest:
	SetZCode Games  ;This is the first Game to play
	rcall SelfTest

Main:
.IF  BuildSimulator == 1
	ldi tmp,'?' 
.ELSE 
	ldi tmp,'>'
	rcall V24Send
	rcall V24Receive
.ENDIF

LoopCmd:
	rcall DoCmd
	rjmp	Main

OneTest:
; runs one the test game starting from gameP,returns tmp 0=OK
	sbi	myGP,gpGameFlash	
	rcall ReadGame		; tmp 0 if OK
	tst 	tmp
	brne OneTestDone
	rcall SolveSud
	PfiHigh 3
	rcall ValidateFld	; tmp 0 if OK
	PfiLow 3
OneTestDone:
	sbis	myGP,gpSndDebug
	ret
	push tmp		;save result for further evaluation
	rcall V24SendByte
	rcall V24SendCR
	pop tmp
	ret

SelfTest:
; runs all test games starting from Z^
	sts gamePL,ZL
	sts gamePH,ZH
SelfTest10:
	rcall OneTest
	tst 	tmp
	breq SelfTest10
SelfTestDone:
	ret

txErr: .db '\n',"ErHand Cmd or CR ?",0,0,0
Error:
; something unexpected happended, Error Code x in tmp, tmpL tmpH numeric info
	push	tmp
	ldi  tmp,'E'		;Exnnnn 
	rcall V24Send
	pop	tmp
	rcall V24SendWordCh
	rcall V24SendCR
	sbis	myGP, gpErrWait
	ret	
; here if gpErrWait set:
	rcall V24SendIdx 	; can't harm to give some more info
	push tmp
	push ZL
	push ZH			; 
ErrorNext:
	setZCode txErr
	rcall V24SendString
	rcall V24Receive
	cpi tmp,13
	breq	ErrorDone
	rcall DoCmd
	rjmp ErrorNext
ErrorDone:
	pop ZH
	pop ZL
	pop tmp
	ret


txHlp: .db '\n'," a A c d D e E f g G.. h l n r s t T v y Y Z",'\n', 0,0

DoCmd:
; process command in tmp
; rjmped routines should ret thus back from this also
; 
; 
; 
	sbic	myGP,gpSndDebug
	rcall V24Send
	cbi	myGP, gpSingle

	cpi	tmp,'a' 	; all test simple
	brne C_a
	SetZCode Games
	rjmp	SelfTest
C_a:

	cpi	tmp,'A' 	; all test schwer
	brne C_aa
	SetZCode Schwer
	rjmp	SelfTest
C_aa:

	cpi	tmp,'b' 	; show backtrack
	brne C_b
	rjmp ShowBck
C_b:

	cpi	tmp,'d' 	; show Dof
	brne C_d
C_d10:
	rcall V24SendCR
	rjmp ShowDof
C_d:

	cpi	tmp,'D' 	; calculate Dof
	brne C_dd
	rcall BuildDof
	rjmp C_d10
C_dd:

C_e:	 ; show exc
C_ee: ; build exc

	cpi	tmp,'f'	; show field
	brne C_f
	rcall V24SendCR
	rjmp ShowFld
C_f:

	cpi	tmp,'g' 	; go solve current
	brne C_g
	rjmp	SolveSud
C_g:

	cpi	tmp,'G'	; game data to come
	brne C_gg
	cbi 	myGP, gpGameFlash ; from V24
	rjmp	ReadGame
C_gg:

	cpi	tmp,'h' 	; help
	brne C_h
	setZCode txHlp
	rjmp V24SendString
C_h:

	cpi	tmp,'l' 	; load 
	brne C_l
	rcall LoadGame
	ret
C_l:
 
	cpi	tmp,'n' 	; next game
	brne C_n
	rjmp	C_t20
C_n:

	cpi	tmp,'r' 	; show ref
	brne C_r
	rjmp	ShowRef
	ret
C_r:

	cpi	tmp,'s' 	; save 
	brne C_s
	rcall SaveGame
	ret
C_s:
	
	cpi	tmp,'t' 	; read first test games
	brne C_t
	SetZCode Games
C_t10:
	sts gamePL,ZL
	sts gamePH,ZH
C_t20:
	sbi	myGP,gpGameFlash	
	rcall ReadGame		; tmp 0 if OK
	rjmp	ShowFld
	 
C_t:
	cpi	tmp,'T' 	; read first schwer
	brne C_tt
	SetZCode Schwer
	rjmp	C_t10

C_tt:

	cpi	tmp,'v' 	; validate solution
	brne C_v
	rjmp ValidateFld
C_v:

	cpi	tmp,'y' 	; send debug
	brne C_y
	sbi myGp,gpErrWait
	sbi myGp,gpSndDebug
	ret
C_y:

	cpi	tmp,'Y' 	; no debug Data unless requested
	brne C_YY
	cbi myGp,gpErrWait
	cbi myGp,gpSndDebug
	ret
C_yy:

	cpi	tmp,'Z' 	; Soft-reset to reset all
	brne C_zz
	rjmp RESET
C_zz:

	cpi	tmp,'?' 	; Show error
	brne C_fr
	rjmp	Error
C_fr:

C_nix:
	ldi  tmp,'?'
	sbic	myGP,gpSndDebug
	rcall V24Send
	ret

LoadGame:
; sav->fld
	ldi tmpC, fldAnz
	SetXIdx 	sav, tmpC
	SetYIdx 	fld, tmpC
	rjmp	CopyXYC

SaveGame:
; fld->sav
	ldi tmpC, fldAnz
	SetXIdx 	fld, tmpC
	SetYIdx 	sav, tmpC
	rjmp	CopyXYC

CopyXYC:
; copy tmpC from x^to Y^
	ld tmp,X+
	st Y+,tmp
	dec tmpc
	brne CopyXYC
	ret

ShowDof:
; calculated Dof shown 
	push XL
	push XH
	push tmp
	ldi	tmp,1
	SetXIdx 	dof, tmp
	rcall	ShowFldDof
	pop tmp
	pop XH
	pop XL
	ret

ShowFld:
; shown 
	push XL
	push XH
	push tmp
	ldi	tmp,1
	SetXIdx 	fld, tmp
	rcall	ShowFldDof
	pop tmp
	pop XH
	pop XL
	ret

ShowFldDof:
; show the field or dof or save X^
	push tmpL
	push tmpH 	
	push tmpC 	
	ldi	tmpH,rcAnz
ShowSudLine:
	ldi	tmpL,rcAnz
ShowSudLine10:
	ld	tmp,X+
	subi tmp,-48       ;'0' 0x30 to '9'
	rcall V24Send
	dec	tmpL
	brne ShowSudLine10
	rcall V24SendCR
	dec  tmpH
	brne ShowSudLine
	pop tmpC
	pop tmpH 	
	pop tmpL 	
	ret

ShowRef:
;show the ref and sorted dof of it until the terminating 0
; first should be 'R' and 'B'
	rcall V24SendCR
	setYPtr	ref    
	rcall ShowRef10
	setYPtr	srt
ShowRef10:
	ld	tmp,Y+
	tst  tmp
	breq	ShowRef20
	rcall V24SendByte
	rjmp ShowRef10
ShowRef20:
	rcall V24SendCR
	ret

ShowBck:
;show the backtrack from Start to bckP, also terminate on 0
	rcall V24SendCR
	; current value of bckP 
	mov	tmp,bckPH
	rcall V24SendByteShort
	mov	tmp,bckPL
	rcall V24SendByte
	setYPtr	bck    
	; perhaps eval diff to bckP?
ShowBck10:
	ld	tmp,Y+
	tst  tmp
	brne ShowBck20
; unexpected \0
	ldi	tmp,'?'
	rcall V24Send
	rjmp	ShowBckDone
ShowBck20:
	rcall V24SendByte
	cp YL, bckPL
	brne ShowBck10
	cp YH, bckPH
	brne ShowBck10
ShowBckDone:
	rjmp V24SendCR	;which ret's



TIM0_COMPA:
; Interrupt-Handler Timer 0
	in   sregS, SREG
; 1ms counter
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

; avrdude -v -patmega328p -carduino -P\\.\COM6 -b57600 -D -V -Uflash:w:C:\path\sudoku.hex:i


