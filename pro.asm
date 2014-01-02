;*************************************************************************
; ATMega 328P first steps
; IN   OUT SBIS SBIC CBI SBI
; LDS  STS combined with SBRS, SBRC, SBR, and CBR
; Ports
;  0 7 PD0
;  8   PB0
; 13   PB5  Sclock(LED)
;*************************************************************************
.NOLIST
.include "m168def.inc"
.LIST
.LISTMAC
 

; register usage
.def	resL		= R0	; result of multiplication
.def	resH		= R1	; 
.def	cnt3		= R2	; 
.def	val1		= R3	; Current Number
.def	one			= R4	; Fixed Value one
.def	three		= R5	; Fixed Value three
.def	cntUpL		= R6	; 
.def	cntUpH		= R7	; 
.def	cntDnL 		= R8	; 
.def	cntDnH		= R9	; 
.def	top			= R10	; 
.def	AdVal2		= R11   ; Value of last conversion
.def	AdVal3	 	= R12	; Value of last conversion
.def	cntOn	 	= R13	; Counter
.def	sregS		= R15	; saves status during interrupt
.def 	tmp 		= R16   ; general usage, not preserved
.def	tmpL		= R17   ;
.def	tmpH		= R18   ;
.def	acc 		= R19	; accu
.def	SndDur		= R20	; Duration to Send, 0 = off
.def	active		= R21	; 0 to 3 
.def	ButCnt		= R22	; 0 Led off else Led on (decremented)
.def	recv		= R23	; 
.def	usepowH		= R24	; 
;.def	usepowH		= R25	; 
; XL				= R26 	; used to save 
; XH				= R27	; 
; YL				= R28   ; points to current 
; YH				= R29	; 
; ZL				= R30
; ZH				= R31	

;Data Segment	
.dseg
	.org SRAM_START
ribu:		.BYTE 20	  ; must be first (0) and same High Adress (YH)
ribuEnd:	
save:   	.BYTE 20	  ;has to be even, and same High Adress (YH)
results:    .BYTE 256     ;
;Code Segment	
.cseg
; interrupt Jump Table atmega168
	.org 0x0000
 	rjmp RESET 					;  1 RESET External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset


.MACRO PortOutB ; num on B as output to zero
	sbi DDRB, @0
	cbi PORTB,  @0
.ENDMACRO

.MACRO PortInPB ; num dir prt as input with Pup
	cbi DDRB , @0
	sbi PORTB, @0
.ENDMACRO


.MACRO PortOutD ; num on D as output to zero
	sbi DDRD, @0
	cbi PORTD,  @0
.ENDMACRO

.MACRO PortInPD ; num dir prt as input with Pup
	cbi DDRD , @0
	sbi PORTD, @0
.ENDMACRO

.MACRO DHigh ; num dir prt as input with Pup
	sbi PORTD, @0
.ENDMACRO

.MACRO DLow ; num dir prt as input with Pup
	cbi PORTD, @0
.ENDMACRO


; Start of Program
	.org 0x0050
RESET:
;here we go:
	ldi tmp, high(RAMEND); Main program start
	out SPH,tmp ; Set Stack Pointer to top of RAM
	ldi tmp, low(RAMEND)
	out SPL,tmp
; enable output
	PortOutD 2 
	PortOutD 3 
	PortOutB 5
	 	   
	rcall V24Init
	ldi tmp,'>'
	rcall V24Send
	rcall Clear
	rjmp Loop

debug:
	ldi tmp,5
	rcall NumIn
	ldi tmp,6
	rcall NumIn
	ldi tmp,7
	rcall NumIn
	rcall DoOne
	rjmp debug

Loop:
	rcall V24Receive
	rcall DoCmd
	rjmp  Loop


DoCmd:
; called routines should ret thus back from this also
	rcall V24Send
	cpi tmp,'c'
	brne C_c
	rcall Clear
	rjmp Show
C_c:
	cpi tmp,'o'
	brne C_o
	rcall DoOne
	rjmp ShowCnts
C_o:
	cpi tmp,'p'   ;performance
	brne C_p
	rcall Clear
	ldi   tmp,7
	rcall	NumIn
	ldi   tmp,7
	rcall	NumIn
	ldi   tmp,7
	rcall	NumIn
	ldi   tmp,7
	rcall	NumIn
	rjmp DoOne
C_p:
	cpi tmp,'s'
	brne C_s
	rjmp Show
C_s:

	cpi tmp,'u'
	brne C_u
	rjmp ShowCnts
C_u:
;check for numbers, has to be last as temp is destroyed:
	subi	tmp,48
	brcs	C_nix			;tmp is 47 or less
	cpi		tmp,10
	brcc	C_nix			;tmp is ge 10
	rcall	NumIn
	rjmp Show
C_nix:
	ldi  tmp,'?'
	rjmp V24Send
;	

; do one calculation
DoOne:
	clr cntUpL
	clr cntUpH
	clr cntDnL
	clr cntDnH
	DHigh 2
One_again:
	ldi YL, low(ribu)	
	ld  acc,Y
	sbrc acc,0		;check lowest bit
	rjmp One_up
One_down:
	mov YL,top ; dec before load below
	clc
	ld  acc,-Y  ; see if topmost is zero
	tst acc
	brne One_down_2
	dec top
	; 
One_down_1:
	ld  acc,-Y
One_down_2:	
	ror acc
	st   Y,acc
	tst YL
	brne One_down_1
; check one
	cp 	acc,one
	breq One_done
One_down3:
	inc  cntDnL
	brne One_again 
	inc  cntDnH
	rjmp One_again  
One_done:
	cp  top,one
	brne  One_down3
	DLow 2
	ret
One_up:
	mov tmpL,three
	mov tmpH, one
	rcall MultAdd
	inc  cntUpL
	brne One_down  ; must be even
	inc  cntUpH
	rjmp One_down  


MultAdd:
; multiply by tmpL, and add tmpH, destroys tmpH,acc
;       
; resL resH
; 
;
	ldi YL, low(ribu)
Mult_1:
	ld  acc,Y
	mul acc,tmpL
	add resL, tmpH ; from previous mult
	st  Y+, resL
	mov tmpH,resH  ; for next
	brcc Mult_2
	inc tmpH
Mult_2:
; do we have to inc top?
	cp  YL,top
	brne Mult_1
	; have to increase top?
	tst resH
	breq Mult_Done
	inc top
	st  Y, resH
Mult_Done:
	ret

; Process number in tmp
NumIn:
	ldi tmpL,10
	mov tmpH,tmp
	rcall MultAdd
	ret

; Clear Data
Clear:
	ldi YH, high(ribu)
	ldi YL, low(ribu)
	mov top,YL
	inc top
	ldi tmp,0
	st  Y,tmp
	ldi tmp,3
	mov three,tmp
	ldi tmp,1
	mov one,tmp
	ret

; Show Data
ShowCnts:
	mov	  tmp, cntDnH
	rcall V24SendByteShort
	mov	  tmp, cntDnL
	rcall V24SendByte
	mov	  tmp, cntUpH
	rcall V24SendByteShort
	mov	  tmp, cntUpL
	rcall V24SendByte
	rcall V24SendCr
	ret

; Show Data
Show:
	push  YL
	mov	  tmp, top
	rcall V24SendByte
	ldi   YL, low(ribu)
Show_1:
	ld    tmp,Y+
	rcall V24SendByte
	cp	YL,top
	brne Show_1
	rcall V24SendCr
	pop YL
	ret

.include "V24.inc"
