;
; SUDOKU Solver für Arduino. Ein Versuch
; use serial interface with 115200 8n2 (two is important to avoid overruns)
; using tabwidth 5
; Build Options

.include "m328pdef.inc"

.SET BuildSimulator = 0	; 1 if built for debugging
.SET GameSize = 81		; number of fields 9, 81 or 16(#todo)
.SET Statistics=1		; create statistic using 7 registers and performance


.NOLIST
.LISTMAC
.include "macro.inc"
.LIST
 
; register usage
.def	resL		= R0		; result of multiplication
.def	resH		= R1		; 
.def	zero		= R2		; fixed value zero
.def errTyp	= R3		; tracing support
.def	dwnL		= R4		; Down Counter
.def	dwnH		= R5		;    "
.def	dwnX		= R6		; 	"
.def	dwnXX	= R7		; 	"
.def	auxL		= R8		; aux, not preserved
.def	auxH		= R9		;	"     
.def	cnt0L	= R11   	; counts tim0
.def	cnt0H	= R12	;	"
.def	cnt0X	= R13	;    "
.def	sregEE	= R14	; save status during EEprom or V24 access
.def	sregS	= R15	; save status during interrupt
.def tmp 		= R16   	; general usage, not preserved
.def	tmpC		= R17   	;    "
.def	tmpL		= R18   	;    "
.def	tmpH		= R19   	;    "
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
.equ gpAutorun      = 5       ; 1: start solving after game is read (use go)
.equ gpErrWait		= 4		; 1: Wait for V24 after Error
.equ	gpGameFlash	= 3 		; 1: read game from Flash else V24
.equ	gpSndDebug	= 2     	; 1: send debug info

.equ gpSingle     	= 0       ; 1: one step down until no more possible values
; GPIOR1 >1F, use in out then sbrs sbrc
.equ	myG1		= GPIOR1		; here those with less importance
.equ g1SelfTest     = 7       ; 1: play all flash games on Init
.equ g1Simulator    = 4       ; 1: running in Simulator (#todo)
.equ g1SolvAll      = 3       ; 1: dont stop after the first Solution (#todo)
.equ g1ToEprom     	= 1       ; 1: write result to Eprom (#todo)

.equ  excAnz	=  10		; exclusion list always 0..9

.IF  GameSize == 9
.equ  fldAnz	= 9			; # of fields
.equ	 rcAnz 	= 3			; # of row/column
.equ  chkAnz 	= 8       	; # of adjacent fields to check
.equ  chkAnzRom=10			; # offset between two entries 
.ELIF GameSize == 81
.equ  fldAnz 	= 81		
.equ	 rcAnz 	=  9
.equ  chkAnz 	= 20
.equ  chkAnzRom= 22
.ELSE 
.WARNING "Please .SET GameSize" 
.ENDIF


;Data Segment	
.dseg
.org SRAM_START
; All arrays start with index 1, use [0] to help debug
fld: 	.BYTE  fldAnz+1	; value of field
fldEnd:
exc: 	.BYTE  excAnz		; exlusion list one entry each for 0..9, 0 not used
excEnd:
ref: 	.BYTE  fldAnz		; contains the changeable fields from 1..81,if 0=end
refEnd:
srt:		.BYTE  fldAnz		; helps to sort the ref, contains the dof for corresponding ref
srtEnd:
chk: 	.BYTE  chkAnz+1	; list of fields to check for given field, 0-terminated 
chkEnd:
errShw:				; Area 8 Byte shown during error handler:
gamePL:	.BYTE  1			; ^to game in flash next to read
gamePH:	.BYTE  1			; 
V24InL:	.BYTE  1			; V24 Buffer pointer
V24InH:	.BYTE  1			;	"
V24OutL:	.BYTE  1			;	"
V24OutH:	.BYTE  1			;	"
refLen:	.BYTE  1			; contains the number of ref entries (before the terminating  0), set by BuildDof
errShwEnd:			; End Area shown during error handler
cur0P:	.BYTE  1			; Timer0 Setting
cur0A:	.BYTE  1			; 
bck:    	.BYTE  1      		; backtrack is a really looong list, re-use it for
dof: 	.BYTE  fldAnz+1	;     contains temp. dof for each field 

		.BYTE  200		; just an estimated number of possible depth
bckEnd:					; This will be overwritten if backtrack gets too long 
endInd:   .BYTE 1			; should not be overwritten
sav:		.BYTE  fldAnz+1	; save game area

V24BufBeg: .BYTE  1        	; mark to find range issues
V24Buf: 	.BYTE  81	  		; input queue for V24
V24BufEnd:.BYTE   1

;Code Segment	
.cseg
; interrupt Jump Table atmega 328
.org 0x0000
	jmp RESET		; RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
.org 0x001C
	jmp TIM0_COMPA ; Timer0 Compare A Handler
.org 0x0024 
	jmp V24_RXC ; USART, RX Complete Handler


; and off we go:
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
	sbi	myGP, gpAutoRun	
	sbi	myGP, gpInfo

	ldi tmp, (0<<g1SolvAll)+(1<<g1ToEprom)+(0<< g1SelfTest)	
	out	myG1,tmp

; setup Serial
	ldi 	tmpL,8    ; 16Mhz: 25=38400(0.2%) 16=57600(2.1%) 8=115200(3.5%) 1=500.000 0=1.000.000
	clr	tmpH
	rcall V24Init

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

	rcall SudoInit
	SetZCode Games  ;This is the first Game to play
	sts gamePL,ZL
	sts gamePH,ZH

.IF BuildSimulator == 0 		;****** Not in Simulator ***
; Say Hi
	setZCode txVer
	rcall V24SendString
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

MainFlash:
; if playing from Flash and selftest do it now
	sbis	myGP,gpGameFlash
	rjmp	MainLoop
	in tmp,myG1
	sbrs	tmp,g1SelfTest
	rjmp	MainLoop
	rjmp	MainLoop			; no longer reqd
.ELSE 				 	;****** Simulator only ***
	cbi myGP,gpSndDebug
	ldi tmp,'T'
	rcall DoCmd
	ldi tmp,'d'
	rcall DoCmd
	ldi tmp,'i'
	rcall DoCmd
	ldi tmp,'i'
	rcall DoCmd
	ldi tmp,'i'
	rjmp MainLoop
.ENDIF   					;**************************


MainLoop:	

.IF BuildSimulator == 0 		;****** Not in Simulator ***
	rcall V24Xon;
	ldi tmp,'>'
	rcall V24Send
	rcall V24Receive
	rcall DoCmd
	rjmp	MainLoop
.ELSE 				 	;****** Simulator only ***
	ldi tmp,'i'
	rcall DoCmd
	rjmp MainLoop
.ENDIF   					;**************************


txErr: .db '\n',"ErrHand cmd, q, s or CR:",0
ErrHand:
; something unexpected happended, Error Code x in tmp, tmpL tmpH numeric info
; returns in tmp same errorcode or 'q' if user requested it
	mov errTyp,tmp
	ldi  tmp,'H'		;Exnnnn 
	rcall V24Send
	rcall V24SendWordCh
	sbis	myGP, gpErrWait
	ret	
; here if gpErrWait set:
	rcall V24SendIdx 	; can't harm to give some more info
; save registers used except tmp
	push tmpC
	push ZL
	push ZH			; 
	in 	ZL,SPL;
	in 	ZH,SPH;	; xx ZH ZL tmp RetH RetL
	adiw ZL,4	    ;have to ignore the currently pushed
ErrHandShowStack:		
	ld 	tmp,Z+
	rcall V24SendByte
	tst  ZL		; up to next FF
	brne ErrHandShowStack
	rcall V24SendCR
	SetZPtr errShw
	ldi tmpC,8
ErrHandShowData:
	ld 	tmp,Z+
	rcall V24SendByte
	dec tmpC
	brne ErrHandShowData			

ErrHandNext:
	setZCode txErr
	rcall V24Xon
	rcall V24SendString
	rcall V24Receive
; Special Chars to abort
	cpi tmp,13
	breq	ErrHandDone
	cpi tmp,'q'
	breq	ErrHand10 ;
	cpi tmp,'s'
	breq	ErrHand10 ;
; Regular
	rcall DoCmd
	rjmp ErrHandNext
ErrHandDone:
	rcall V24Send
	mov tmp,errTyp
ErrHand10:
	pop ZH
	pop ZL
	pop tmpC
ErrHandWeg:
	ret

DoCmd:
; process command in tmp
; rjmped routines should ret thus back from this also
; 
DoCmdWait:
	cbi	myGP, gpSingle	;switch single step off
	rcall V24SendBSpc ; command received 

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
	rcall V24SendCR
	rjmp ShowBck
C_b:

	cpi	tmp,'c' 	; show checkfields
	brne C_c
	rjmp ShowChk
C_c:

	cpi	tmp,'d' 	; build dof
	brne C_d
	rcall BuildDof
	rjmp ShowDof
C_d:

	cpi	tmp,'D' 	; show  dof without calc
	brne C_dd
	rjmp ShowDof
C_dd:

	cpi	tmp,'e' 	; show exc
	brne C_e
	rjmp ShowExc
C_e:

	cpi	tmp,'f'	; show field
	brne C_f
	rjmp ShowFld
C_f:

	cpi	tmp,'g' 	; go solve current
	brne C_g
	rjmp	SolveSudoku
C_g:

	cpi	tmp,'G'	; game data to come
	brne C_gg
	cbi 	myGP, gpGameFlash ; from V24
	ldi	tmp,' '	; readgame expects first char in tmp
	rjmp	ReadGame
C_gg:

	cpi	tmp,'h' 	; help
	brne C_h
;	setZCode txHlp
	rjmp V24SendString
C_h:

	cpi	tmp,'i' 	; improve ref
	brne C_i
	rjmp ImprRef
C_i:

	cpi	tmp,'j' 	; jump
	brne C_j
	sbi myGp,gpAutoRun
	ret
C_j:

	cpi	tmp,'J' 	; no jump
	brne C_jj
	cbi myGp,gpAutoRun
	ret
C_jj:

	cpi	tmp,'l' 	; load 6C
	brne C_l
	rcall LoadGame
	rjmp	ShowFld
C_l:
 
	cpi	tmp,'n' 	; next game
	brne C_n
	rjmp	C_t20
C_n:

	cpi	tmp,'o' 	; only this after ref has been built, wrong timergo solve current
	brne C_o
	rjmp	SolveSudokuOnly
C_o:

	cpi	tmp,'r' 	; show ref
	brne C_r
	rjmp	ShowRef
C_r:

	cpi	tmp,'R' 	; create ROM
	brne C_rr
	rjmp	CreateRom
C_rr:

	cpi	tmp,'s' 	; save 73
	brne C_s
	rjmp  SaveGame
	ret
C_s:
	
	cpi	tmp,'t' 	; read first test game 74
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
	rjmp ValidateGame
C_v:

	cpi	tmp,'V' 	; validate sanity
	brne C_vv
	rjmp SudoSanity
C_vv:

	cpi	tmp,'w' 	; wait on Err
	brne C_w
	sbi myGp,gpErrWait
	ret
C_w:

	cpi	tmp,'W' 	; no wait on Err
	brne C_ww
	cbi myGp,gpErrWait
	ret
C_ww:

	cpi	tmp,'y' 	; send debug 
	brne C_y
	sbi myGp,gpSndDebug
	ret
C_y:

	cpi	tmp,'Y' 	; no debug Data unless requested
	brne C_YY
	cbi myGp,gpSndDebug
	ret
C_yy:

	cpi	tmp,'Z' 	; Soft-reset to reset all
	brne C_zz
	rjmp RESET
C_zz:

	cpi	tmp,'#' 	; call
	brne C_laz
	rjmp	ErrHand
C_laz:

	cpi  tmp,10
	breq C_Done
	cpi  tmp,13
	breq C_Done

C_nix:
	cbi 	myGP, gpGameFlash	; from V24
	rcall V24SendCR
	rcall ReadGame	; assume it's first char of a game
	tst   tmp		; read succesful?
	breq	C_ReadOK
	ldi  tmp,'?'
	rcall V24Send
	ret
C_ReadOK:
	sbis	myGP,gpAutoRun
	ret
	rcall SolveSudoku
C_Done:
	ret



OneTest:
; runs one the test game starting from gameP,returns tmp 0=OK
	sbi	myGP,gpGameFlash	
	rcall ReadGame		; tmp 0 if OK
	tst 	tmp
	brne OneTestDone
	rcall ShowFld 
	rcall SolveSudoku
	tst 	tmp
	brne OneTestDone
	rcall ValidateGame	; tmp 0 if OK
OneTestDone:
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

txLG: .db ".Load:",0,0
LoadGame:
; sav->fld destroying regs
	setZCode txLG
	rcall V24SendString
	ldi tmpC, 1
	SetXIdx 	sav, tmpC
	SetYIdx 	fld, tmpC
	ldi tmpC,fldAnz
	rjmp	CopyXYC

txSG: .db ".Saved",13,0
SaveGame:
; fld->sav destroying regs
;	setZCode txSG
;	rcall V24SendString
	ldi tmpC, 1
	SetXIdx 	fld, tmpC
	SetYIdx 	sav, tmpC
	ldi tmpC,fldAnz
	rjmp	CopyXYC

CopyXYC:
; copy tmpC from x^to Y^ destroying regs
	ld tmp,X+
	st Y+,tmp
	dec tmpc
	brne CopyXYC
	ret

; Show routines use Y and tmpP should not change any regs as called from within debug mode
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
	push tmpL
	push tmpH 	
	push tmpC 	
	rcall V24SendCR
	ldi	tmpH,rcAnz
ShowSudLine:
	ldi	tmpL,rcAnz
ShowSudLine10:
	ld	tmp,Y+
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
	PushYtmp
	rcall V24SendCR
	setYPtr	ref    
	rcall ShowRef10
	setYPtr	srt
	rcall ShowRef10
	PopYtmp
	ret

ShowRef10:
	ld	tmp,Y+
; first is char R/S
	rcall V24SendSpc
ShowRef15:
	ld	tmp,Y+
	tst  tmp
	breq	ShowRefDone
	rcall V24SendByte
	rjmp ShowRef15
ShowRefDone:
	rcall V24SendCR
	ret


ShowExc:
;show the exclusion list
; first should be 'R' and 'B'
	PushYtmp
	push	tmpC
	rcall V24SendCR
	ldi	tmpC,excAnz	;10
	setYPtr exc    
ShowExc10:
	ld	tmp,Y+
	rcall V24SendByte
	dec tmpC
	brne ShowExc10
	pop tmpC
	PopYtmp
	ret

ShowChk:
;show the checklist from ROM
	push ZL
	push ZH
	push	fldNum
	push tmp
	rcall V24SendCR
	ldi  fldNum,1
ShowChk10:					; for each fldNum
     ldi  ZL, LOW(romBeg*2-chkAnzRom)  ;fldNum starts with 1
     ldi  ZH, HIGH(romBeg*2-chkAnzRom)
	ldi  tmp,chkAnzRom
	mul  tmp,fldNum		
	add  ZL,resL
	adC 	ZH,resH
	mov  tmp,ZH
	rcall V24SendByteShort
	mov  tmp,ZL
	rcall V24SendByte
	mov	tmp,fldNum
	rcall V24SendByte
ShowChk20:				; for each chk
	lpm	tmp,Z+
	rcall V24SendByte
	cpi tmp,fldAnz+1		;tmp is ge 82, 
	brcc	ShowChkDone		; something is wrong
	tst  tmp
	brne ShowChk20			; next chk
	rcall V24SendCR
	inc	fldNum
	cpi	fldNum,fldAnz+1
	brne	ShowChk10			; next fldNum
ShowChkDone:
	pop  tmp
	pop  fldNum
	pop  ZH
	pop  ZL
	ret

ShowBck:
;show the backtrack from Start to bckP, also terminate on 0
	push YL
	push YH
	push tmp
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
	rcall V24SendCR
	pop tmp
	pop YH
	pop YL
	ret
;   

ReadGame:
	PfiHigh 2 
; read a Game either pointed to by GameP or via V24
; After succesful Read, pointer is stored in GameP, so next Game can be read
; tmp contains result
; 0	 OK 
; F0  No free fields
; FF  misc read Error
; Error Code R
; when from V24 the char in tmp might be a field content
	lds ZL,gamePL
	lds ZH,gamePH
	ldi	tmpC, rcAnz	; send a CR if 9 chars recvd
; Read in
	clr	fldNum   	 	; points to current field-1
	setXPtr fld+1		; value stored in field by X,first goes to [1]
	sbis myGP, gpGameFlash
	rjmp	ReadGameReceived	; eval tmp from V24
	inc tmpC			; no char from flash
ReadGameNext:
; depending on selection
	sbic myGP, gpGameFlash
	rjmp	ReadGame17
	rcall V24Receive
ReadGameReceived:
	cpi	tmp,33
	brcs	ReadGameNext	; lt 33, ignore
	rcall V24Send		
	dec  tmpC			; new line for feedback?
	brne ReadGame19
	mov  tmpC,tmp		; save char
	rcall V24SendCR		
	mov	tmp,tmpC
	ldi	tmpC, rcAnz
	rjmp ReadGame19
ReadGame17: 			; from flash
	lpm	tmp,Z+

ReadGame19:
	cpi	tmp,'.'		; translates to '0'
	brne ReadGame20
	ldi	tmp,'0'
ReadGame20:
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
	PfiLow 2
	sbis myGP, gpGameFlash
	rcall V24Xoff	; tell serial to wait. After the last char received there are about 1.323 ms 
			; required to compensate for the additionaly sent CR's; Best to set a transmit Delay after CR
	ldi	tmp,'f'
	rcall V24Send
	mov	tmp,fldNum
	rcall V24SendByteShort
	rcall V24SendCR
	sbic myGP, gpGameFlash
	rjmp ReadGameDoneFlash
	; Here only if received via V24:
	rcall SaveGame		; to compare with
	clr  tmp
	ret
ReadGameDoneFlash: ; as the games in flash are aligned and have odd # of fields need to inc Z for next game
	adiw ZL,1
	sts 	gamePL,ZL
	sts 	gamePH,ZH
; Show game if debug
	sbic myGP,gpSndDebug
	rcall ShowFld
	clr  tmp
	ret
ReadGameErr:
	PfiLow 2
; indicate Err at Field Number
	ldi	tmp,'E'
	rcall V24Send
	mov	tmp,fldNum
	rcall V24SendByte
	mov	tmp,tmpL 		;incriminating char
	rcall V24Send
	rcall V24SendCR
	ldi	tmp,0xFF
	ret

.MACRO Prnt
     ldi     ZL, LOW(2*@0)
     ldi     ZH, HIGH(2*@0)
	rcall V24SendString
.ENDMACRO

.MACRO Pr0x 		;"0xNN,"
     ldi  tmp,'0'
	rcall V24Send
     ldi  tmp,'x'
	rcall V24Send
	mov	tmp,@0
	rcall V24SendByteShort
     ldi  tmp,','
	rcall V24Send
.ENDMACRO
; to write out the ChkFields
; 32k Memory 
;  Code   Data
;  .org   lpm Z                                 used
;  0000	0000		My Area´      Size  24576  <4000
;  3000   6000      ROM Data      Size   4096   1782
;  37FF	6FFF		End My Area  
;  3800			Bootloader    Size   4096
;  3FFF                           total 32768

txRom1: .db ".org 0x",0
txRom2: .db ".db ",0,0
txRom3: .db "0",'\n',0,0
CreateRom:
; from the exclusion list create a rom Image
	Prnt txrom1
	ldi tmpL, low(romBeg)   
	ldi tmpH, high(romBeg)
	rcall V24SendWordHL
	rcall V24SendCR
	ldi	FldNum,1
CreateRom10:			;for each field
	rcall  BuildChk
	prnt	txRom2
	setYptr chk
CreateRom20:			;for each target
	ld tmpL,Y+
	Pr0x tmpL
	tst tmpL
	brne CreateRom20	;next target
	prnt	txRom3
	inc 	fldNum
	cpi	fldNum,fldAnz+1
	brne CreateRom10	;next field
	ret

TIM0_COMPA:
; Interrupt-Handler Timer 0
; when receiving game we additionally send back \n after 9 fields 
; so we looose chars when receiving w/o break (regardless of baudrate)
;  
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
.include "rom.asm"

txVer: .db  "HH ",0




; avrdude -v -patmega328p -carduino -P\\.\COM6 -b57600 -D -V -Uflash:w:path\sudoku.hex:i


