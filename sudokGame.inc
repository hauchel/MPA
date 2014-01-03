; sodoku solver, idea see bottom of file

BuildChk:
; build a list of fields to check from given fldnum (takes 14uS each step down)
; will be replaced by an hardcoded 81*20 array to speed up
; or by a cache of already calculated chk's
; 
; Y to  store data in chk
; Z to get data from LPM
; destroys: 	Y,Z, tmp*
; sets: 		chk
;
; determine its row/colum
	PfiHigh 2		; indicate Begin 

	SetYPtr chk		; first location to put chk
	SetZCode Fld2RC - 1
	add	ZL,fldNum
	adc	ZH,zero
	lpm	tmpH,Z	
	mov	tmpL,tmpH
	andi	tmpL, 0xF ; the column
	swap tmpH
	andi	tmpH, 0xF ; the row
	ldi	tmpC, rcAnz

; get all row fields except me
	mul	tmpH,tmpC 
	mov	tmp,resL	; the rightmost field
BuildChk10:
	cp	tmp,fldNum
	breq	BuildChk15
	st	y+,tmp	
BuildChk15:
	subi	tmp,1
	dec  tmpC
	brne   BuildChk10
; get all column fields except me
	ldi	tmp, (rcAnz-1)*(rcAnz)
	add  tmp,tmpL
BuildChk20:
	cp	tmp,fldNum
	breq	BuildChk25
	st	y+,tmp	
BuildChk25:
	subi	tmp,rcAnz
	brcs	BuildChk30 ; <0
	brne BuildChk20 ;
BuildChk30:
; get the remaining of the quad, reduce r/c  <4
	cpi	tmpL,4
	brcs	BuildChk35
	subi tmpL,3
	rjmp BuildChk30
BuildChk35:
	cpi	tmpH,4
	brcs	BuildChk40
	subi tmpH,3
	rjmp BuildChk35
BuildChk40:
; r/c are now between 1 and 3 convert to 1..9 in tmpL, 
	dec 	tmpH
	ldi	tmpC,3
	mul  tmpH,TmpC
	add	tmpL,resL
; index is 0, 4, 8
	dec  tmpL
	lsl	tmpL
	lsl	tmpL
	SetZCode quad
	add	ZL,tmpL
	adc	ZH,zero
; get the 4 remaining fieldnumbers
	ldi tmpC,4
BuildChk45:
	lpm	tmp,Z+
	add  tmp,fldnum
	st	Y+,tmp
	dec	tmpC
	brne BuildChk45
; Gott sei Dank:
	st	Y+,zero  ;the terminating 0
	PfiLow 2			; indicate End
	ret

BuildDof:
; for each fldNum whith value 0 calculate the number of possible values (aka dof)
; then sort these into ref
; destroys: 	Y,Z, tmp*  fldNum
; sets: 		dof
; error code D
	PfiLow 3
	ldi	fldNum,fldAnz  ;H
BuildDof10:			; for each fldNum decreasing
	setYIdx	fld,fldnum 
	ld	tmp,Y		; its value
	tst  tmp
	breq BuildDof15	; have to eval
	mov	tmpC,zero
	rjmp BuildDof40
BuildDof15:	 
	rcall BuildExc
	clr	 tmpC		; number	
	ldi	 tmpL,1		; starting point
	setYIdx	exc, tmpL
BuildDof20:			; count excluded value
	ld	tmpH,Y+		; the excluded value here
	tst	tmpH	
	breq BuildDof30
	inc	tmpC			;
BuildDof30:
	inc	tmpL
	cpi	tmpL,10
	brne BuildDof20	; next 
BuildDof40:			; fldnum has tmpC excluded values
; just a sanity check, must be 0 to 8 else solution not possible
	cpi	tmpC,9		; C set if 9>tmpC
	brcs	BuildDof45
	ldi	tmp,'D'
	rcall Error
BuildDof45:
	setYIdx	dof,fldnum
	st	Y,tmpC
	dec	fldNum
	brne BuildDof10	; next fldNum
	PfiHigh 3
	rcall ShowDof
;
; continue with 
;
SortDof:
; sort the fields with Dof in descending order into ref
; 
; Step1: From dof put all those <>0 into ref and srt:
;
	setXPtr	srt+1 	; X ^srt
	setYPtr	ref+1 	; Y ^ref
	setZPtr	dof+1 	; Z ^dof
	clr	tmpC			; count
	ldi	fldNum,1
Sort10:
	ld	tmp,z+
	tst  tmp		;my Dof
	breq Sort20
	st	Y+,fldNum
	st   X+,tmp
	inc  tmpC
Sort20:
	inc	fldNum
	cpi  fldNum,fldAnz+1	 
	brne	Sort10
	st	X,zero
	st  	Y,zero
	;tmpC contains the number of entries to sort
	cpi	tmpC,4
	brcs	SortDone		; not worth the effort
; example:
;	ldi	tmp,6
;	sts	srt+1,tmp   
;	sts	srt+3,tmp   
;	ldi	tmp,8
;	sts	srt+2,tmp   
;	ldi	tmp,7
;	sts	srt+4,tmp   
; Step2: sort ref/srt desc use easy bubblesort
;             [1]       [tmpC]                
; ref field#  12  23  33  45  0
; srt dof      6   8   6   7  0
;             X^
;   1    A        X^
;              H   L   swap if L>H
;              8   6   6   7
;   2                 X^
;   3                     X^
;   4
; after each iteration [tmpC] has the lowest value, so tmpC is dec'd
; also no further action required if there was no swap during a run
; Debug only:
Sort30:
	setXPtr	srt+1
	setYPtr	ref+1     ;
	ldi	tmp,1		; loop counter
	cbi	myGP, gpSwp	; no swap occured
Sort40:
	ld	tmpH,X+		
	ld	tmpL,X
	ld	WH,  Y+ 	     ; Y in sync with X
	cp	tmpH,tmpL		; carry is set if L>H
	brcc	Sort50		; no swap  
	sbi	myGP, gpSwp	; remember swap
	PfiTog 4			; and show
	st	-X,tmpL
	adiw	XL,1
	st	X,tmpH
	ld	WL,Y			; swap field number also
	st	-Y,WL
	adiw	YL,1
	st	Y,WH
Sort50:			
	inc  tmp
	cp	tmp,tmpC
	brne	Sort40
; one run completed
	sbis	myGP,gpSwp
	rjmp	SortDone
	dec  tmpC
	cpi	tmpC,1
	brne Sort30
SortDone:
	rcall showRef
	clr tmp 			; all ok
	PfiLow 3
	PfiLow 4
ret		
	

BuildExc:
; Build Exclusion list for given fldNum
; calls BuildChk to find fields to check
;
; clear the exclusion list (always 9)
	ldi	tmpC,9
	setYPtr exc+1
BuildExc1:
	st	Y+,zero
	dec	tmpC
	brne BuildExc1 
; build  the field list to check
	rcall BuildChk
	SetZptr chk		; Z points to the list if field numbers we have to compare it to
BuildExc10:
	ld	tmp,Z+		; this is the Field# to compare chk to
	tst	tmp			; if zero this comparison completed
	breq	BuildExcDone
	SetYIdx 	fld, tmp    
	ld   tmp,Y 		; Y now points to it, tmp is its value
	tst  tmp
	breq BuildExc10	; is zero
	SetYIdx 	exc, tmp  ; Store value in exclusion list
	st	Y,tmp  
	jmp	BuildExc10	; check next
BuildExcDone:
	ret


ValidateFld:
; check a field if its a solution 
; for each fldNum the value must be 1..9 and the Exclusion List must only be 0 for this 
	ldi	fldNum,fldAnz	;H
ValidateFld10:
	rcall BuildExc
	setYIdx	fld, fldNum	
	ld	tmpL,Y	; my value
	ldi	tmpC,1	; for the 9 values
	setYIdx	exc, tmpC	
ValidateFld20:
	ld	tmpH,Y+	; the excluded value here
	cp   tmpH,tmpC
	breq	ValidateFld30
; here the excluded value should be 0 and the index my value
	tst  tmpH
	brne	ValidateFldErr
	cp	tmpC , tmpL
	brne	ValidateFldErr		
ValidateFld30:
	inc	tmpC
	cpi	tmpC,10
	brne ValidateFld20
	dec fldNum	; next field to check
	brne ValidateFld10
	sbis myGp, gpSndDebug ; send result back
	ret
	ldi	tmp,'o'
	rcall V24Send
	ldi	tmp,'k'
ValidateFld35:
	rcall V24Send
	rcall V24SendCR
	clr	tmp	;return OK
	ret
ValidateFldErr:
; oha, for fldNum with value tmpL the excluded is tmpH at index tmpC
	sbis myGp, gpSndDebug
	ret
	ldi	tmp,'E' 
	rcall V24Send
	mov	tmp,fldNum
	rcall V24SendByte
	rcall V24SendCR
	mov	tmp,fldNum
	ori	tmp,0x80	;must not be 0 on err
	ret


SolveSud:
; solve a game
; returns 0 OK else 
; Set Timer
	out	TCNT0,zero
	clr	cnt0L
	clr	cnt0H
	clr	cnt0X
;clear counters
	clr	dwnL
	clr	dwnH
	clr	dwnX
	clr	dwnXX

;other
	ldi refP,1
	ldi bckPL, LOW(bck+1)
     ldi bckPH, HIGH(bck+1)
	rcall SudInfo
	rcall ShowRef
	rjmp	SudNext


SudAbort:				; interrupted by keyboard
	ldi	tmpH,0xff
	mov  tmpL,tmpH
	rcall V24SendWordHL
	rjmp SudSolution	; 

SudSolution:	;here if solution found
	out	TCNT0,zero   	; so there is time to get consistent counter values
	PfiLow 4			; indicate Done 
; Output Statistics
	push cnt0L
	push cnt0H
	rcall V24SendCR
	ldi tmp,'T'
	rcall V24SendSpc
	mov	tmp,cnt0X
	rcall V24SendByte
	pop	tmp
	rcall V24SendByte
	pop	tmp
	rcall V24SendByte
; and the 4 Counter values
	ldi	tmp,'N'
	rcall V24SendSpc
; topmost only of <>0
	cp	dwnXX,zero
	breq SudSolution10
	mov	tmp, dwnXX
	rcall V24SendByte
	rjmp	SudSolution11 ; must send all subsequent
SudSolution10:
	cp	dwnX,zero
	breq SudSolution20
SudSolution11:
	mov	tmp, dwnX
	rcall V24SendByte
SudSolution20:
	mov	tmp, dwnH
	rcall V24SendByte
	mov	tmp, dwnL
	rcall V24SendByte
	rcall V24SendCR
SudSolution50:
	rcall ShowFld
	ret

SudInfo:
; given on request:
	rcall ShowBck
	ret

SudNext:				; here when evaluating the next field ponted to in refP 
	PfiHigh 4			; indicate Down 
	rcall SudInfo		; remove
	inc	dwnL			; counter
	brne SudNext1
	inc	dwnH
	brne SudNext1
	; after 65536 downs some housekeeping:
	push tmp
	ldi  tmp,'.'
	sbic	myGP,gpSndDebug
	sts  UDR0,tmp			; brute force alive signal
	lds tmp, UCSR0A 		; char from V24?
	sbrc tmp, RXC0
	rjmp SudAbort			; emergency exit
; if info is set, give it now
	sbic	myGP, gpInfo
	rcall SudInfo
	inc	dwnX
	brne SudNext1
	inc	dwnXX			; 16 Mio counter 
SudNext1:			
	SetXIdx 	ref, refP 	; get Field # refP points to
	ld 	fldNum ,X			; contains the Field number to check
	tst  fldNum			; found a valid solution if 0 
	breq	SudSolution
	SetXIdx 	fld, fldNum	; X points to the field to vary, set it to 0
	st 	X,zero
	rcall BuildExc
	movw XL,bckPL			; transfer possible values to backtrack; X to bckList
	mov	tmp,fldNum	
	ori	tmp,0x80			; set high bit to indicate fieldnumber
	st	X+,tmp
	ldi	tmpC, 10
	setYIdx	exc,tmpC	; to 10 (out of range)
	clr	tmpL			; count of possible
ToBack:
; enter those possible (i.e. 0) to back
	dec	tmpC			; this is current value 
	breq	ToBackDone
	ld	tmp,-Y		; 0..9
	tst	tmp	
	brne	ToBack		; not possible
	st	X+,tmpC
	inc	tmpL
	rjmp	ToBack
ToBackDone:
	tst	tmpL
	breq	UndNuPrep		; no possible value found
	subi XL, 1  		; backtrack pointer is 1 to high
     sbci XH, 0
SudDown:
	movW bckPL,XL		; store backtrack pointer
	SetYIdx fld, fldNum ; store selected value in field
	ld	tmp,X	  	; field value from Backtrack-list 
	st	Y,tmp
	inc	refP			; eval next field
	rjmp SudNext

UndNuPrep:				
	PfiLow 4			; indicate Back
UndNu: ;No Solution for this field found, need to track back, X points to next possible
; Ex:    X val
; 82 09 88 09
; backtrack pointer 
	subi XL, 1  
     sbci XH, 0
; get Value of it
	ld	tmp,X
; if there is another possible value for same field use this
	sbrs	tmp,7
	rjmp SudDown
; no more for this field so need dec refP and update fldNum 
	andi tmp, 0x7F		;this is the current field
	SetYIdx 	fld, tmp
	st	Y,zero		; set it to zero
	dec refP
; if zero, there are no more Solutions
	breq SudEnd	
	SetYIdx 	ref, refP	;this is the now current fldNum
	ld	fldNum,Y
	rjmp	UndNu
SudEnd:
; no (more) Solutions
	ret


SudoInit:
; clear data area	
	clr 	zero
	rjmp SudoInit50 ; no cleaning
	setYptr	fld
	ldi 	tmp, 0xAA
	ldi	tmpC,255 ; or whatever
SudoInit10:
	st	Y+,tmp
	dec	tmpC
	brne	SudoInit10

SudoInit50:
; [0] of arrays is not used, put defined values there
	ldi  tmp,'F'
	sts	fld,tmp
	ldi  tmp,'R'
	sts	ref,tmp
	ldi  tmp,'B'
	sts	bck,tmp
	ldi  tmp,'X'
	sts	exc,tmp
	ldi  tmp,'C'
	sts	chkDumm,tmp
	ldi  tmp,'D'
	sts	dof,tmp
	ldi  tmp,'S'
	sts	srt,tmp
	ldi  tmp,'N'
	sts	endInd,tmp
	ret

ReadGame:
; read a Game either pointed to by GameP or via V24
; After succesful Read, pointer is stored in GameP, so next Game can be read
; then BuildDof (and SortDof) is executed, i.e after this gamesolving can start
; tmp contains result
; 0	 OK 
; F0  No free fields
; FF  misc read Error
;
	PfiHigh 3 
	lds ZL,gamePL
	lds ZH,gamePH
	mov	tmpL,ZL
	mov	tmpH,ZH
	rcall V24SendWordHL
; Read in
	clr	fldNum    ; points to current field-1
	setXPtr fld+1	; value stored in field by X,first goes to [1]
ReadGameNext:
; depending on selection
	sbic myGP, gpGameFlash
	rjmp	ReadGame17
	rcall V24Receive
;;	sbic myGP, gpSndDebug no feedback
;;	rcall V24Send
	rjmp ReadGame19
ReadGame17:  ;from flash
	lpm	tmp,Z+
ReadGame19:
	cpi	tmp,13	;CR ignore
	breq	ReadGameNext
	cpi	tmp,' '	; ignore spaces
	breq	ReadGameNext
	cpi	tmp,'.'	;translates to '0'
	brne ReadGame20
	ldi	tmp,'0'
ReadGame20:
	mov	tmpL,tmp		;preserve in case of error
	subi	tmp,48
	brcs	ReadGameErr	;tmp is less '0'
	cpi	tmp,10
	brcc	ReadGameErr	;tmp is ge 10
; here we have a valid number in tmp
	inc 	fldNum		
	cpi	fldNum,fldAnz	; stop if enuff
	breq ReadGameDone
	st	X+,tmp		; store in field
	rjmp ReadGameNext
ReadGameErr:
; indicate Err at Field Number
	ldi	tmp,'E'
	rcall V24Send
	mov	tmp,fldNum
	rcall V24SendByte
	mov	tmp,tmpL 		;incrminating char
	rcall V24Send
	rcall V24SendCR
	ldi	tmp,0xFF
	PfiLow 3 
	ret
ReadGameDone:
	ldi	tmp,'f'
	rcall V24Send
	mov	tmp,fldNum
	rcall V24SendByte
	rcall V24SendCR
; as the games in flash are aligned and have odd # of fields need to inc Z
	sbis myGP, gpGameFlash
	rjmp	BuildDof
	adiw ZL,1
	sts 	gamePL,ZL
	sts 	gamePH,ZH
	mov	tmpL,ZL
	mov	tmpH,ZH
	rcall V24SendWordHL
	clr	tmp
	rjmp	BuildDof

/** NOT USED ANY MORE, replaced by BuildDof
BuildRef:
; determine the seqence of fields to use in ref
; currently just in order of field number
	setXPtr	fld+1 	; value stored in field by X, first goes to [1]
	setYPtr	ref+1 	 
	ldi	fldNum,1
	clr  tmpC			; count free fields
BuildRef10:
	ld	tmp,X+
	tst	tmp
	brne BuildRef15	; nothing to do
	st	Y+,fldNum
	inc tmpC
BuildRef15:
	inc	fldNum
	cpi	fldNum,fldAnz+1	
	brne BuildRef10
	st	Y,zero
;should have at least 1 field available
	tst  tmpC
	brne BuildRef20
	ldi	tmp,0xF0
	ldi	tmp,'E'
	rcall V24Send
	clr tmp
	rcall V24SendByte	;E00
	ldi	tmp,0xF0
	ret
BuildRef20:
	clr  tmp	;all fine
	ret

; 
;
; fields are checked and stored in a reflist in order of dofs 
; ref P:  F G H 0  ; initially this list contains all empty fields
; to investigate a field  F an exclusion list is built showing the number
; 0    1  2  3 .6. 9
; sum  1  0  1 .1. 0  ; 1 means this value is not possible
; possible values except the last (9) are transferred to the backtrack list
; F 2 4 5 7 8  for the field number F the hi bit is set (129..210)
; the last possible value (9) is written to field
; next field:
; F 2..8 G 3 6
; and so on. If there are no possible values (exlist is all 1) for field H go back:
; F 2..8 G 3  and write 0 to field G (which contains 6)
; then  try next
; F 2..8 G H 8 
; if reflist is completed (0) then  the field contains a possible solution
; continue if solution count is activated.
; if backtrack list is empty, then no solution is possible
; Input 81 values 
; Output solved 81 values, not solved: X
*/
