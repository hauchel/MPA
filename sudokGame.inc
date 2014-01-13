; sodoku solver routines
;
; ReadGame	Read the game from flash or V24
; SolveSudoku calls 
;   BuildDof 	build the dof (exactly 9-dof) and ref
;			this also sets fields with dof 8 as only one value is possible 
;              most easy games are already solved now.
;   SortRef	sort the ref so fields with hi dof are in front
;   ImprRef  	improve sequence in ref also those  
; try all possible solutions varying fields as given in ref
;
; BuildExc:
; ValidateGame:
; BuildChk:
; SudoSanity:  checks certain fields if they contain same value as expected


.MACRO SETZ2ROM 	; to avid code dilication
.IF  Statistics == 1		; ONLY ON PRO ****************************************
     ldi  ZL, LOW(romBeg*2-chkAnzRom)  ;fldNum starts with 1
     ldi  ZH, HIGH(romBeg*2-chkAnzRom)
	ldi  tmp,chkAnzRom
	mul  tmp,fldNum		
	add  ZL,resL
	adC 	ZH,resH

.ELSE
	ldi  ZL, LOW(romBeg*2-chkAnzRom) ;#TODO
.ENDIF					;****************************************
.ENDMACRO


SolveSudoku:
	PfiLow 2
; solve the game
; returns 0 OK else 
; Set Timer
.IF  Statistics == 1		; ONLY ON PRO ****************************************
	out	TCNT0,zero
	clr	cnt0L
	clr	cnt0H
	clr	cnt0X
.ENDIF					;****************************************
	rcall BuildDof
	rcall ImprRef
	rcall ImprRef
	rcall ImprRef
; now lets get serious:
SolveSudokuOnly:  ; call here after ref has been built, wrong timer values!
	PfiHigh 2
;clear counters
.IF  Statistics == 1		; ONLY ON PRO ****************************************
	clr	dwnL
	clr	dwnH
	clr	dwnX
	clr	dwnXX
.ENDIF					;****************************************
; to first entry in ref:
	ldi refP,1
	ldi bckPL, LOW(bck+1)
     ldi bckPH, HIGH(bck+1)
	rjmp	SudNext

BuildDof:
	PfiHigh 2
; for each fldNum whith value 0 calculate the number of possible values (aka dof)
; immediately replace those only 1 value possible 
; then sort these into ref
; destroys: Y everything
; sets: 		dof
; error code D
	ldi	fldNum,fldAnz  ;H
	clr	WL			; count of replaced fields, if <>0 restart as field was changed 
	

BuildDof10:			; for each fldNum decreasing
	setYIdx	fld,fldnum 
	ld	tmp,Y		; its value
	tst  tmp
	breq BuildDof15	; have to eval
	mov	tmpC,zero
	rjmp BuildDof60
BuildDof15:	 
	rcall BuildExc		; 
	clr	 tmpC		; number	
	ldi	 tmpL,1		; starting point
	setYIdx	exc, tmpL
BuildDof20:			; count excluded value
	ld	tmpH,Y+		; the excluded value here
	tst	tmpH			; 0 means the value in tmpL is possible
	breq BuildDof28	; 
	inc	tmpC		
	rjmp	BuildDof30	;
BuildDof28:
	mov	WH,tmpL		; WH remembers the last possible value
BuildDof30:
	inc	tmpL
	cpi	tmpL,10
	brne BuildDof20	; next 
BuildDof40:			; fldnum has tmpC excluded values
; just a sanity check, must be 0 to 8 else solution not possible
	cpi	tmpC,9		; C set if 9>tmpC
	brcs	BuildDof45
	ldi	tmp,'D'
	rjmp ErrHand
BuildDof45:
; if the dof is 8, immediately set the only possible value and indicate recalc required
	cpi	tmpC,8
	brne BuildDof60
	PfiHigh 3
	inc	WL 
; field fldNum value must be WH
	SetXIdx fld,fldnum
	st	X,WH
	; show
	sbis myGP, gpSndDebug
	rjmp BuildDof59
	ldi	tmp,'!'		;dof 9
	rcall V24Send
	mov	tmp,fldNum
	rcall V24SendByte
	mov	tmp,WH
	rcall V24SendByte
BuildDof59:
	PfiLow 3		
BuildDof60:			; store it in dof
	setYIdx	dof,fldnum
	st	Y,tmpC
	dec	fldNum
	brne BuildDof10	; next fldNum
	tst WL			; number of fields replaced
	breq	SortIntoRef
	sbic myGP, gpSndDebug
	rcall V24SendCR
	rjmp	BuildDof
;
; continue with 
;
SortIntoRef:
	PfiLow 2
; sort the fields with Dof in descending order into ref
; 
; Step1: From dof put all those <>0 into ref and srt:
;
	setXPtr	srt+1 	; X ^srt
	setYPtr	ref+1 	; Y ^ref
	setZPtr	dof+1 	; Z ^dof
	clr	tmpC			; count
	ldi	fldNum,1
SortInto10:
	ld	tmp,z+
	tst  tmp			;my Dof
	breq SortInto20
	st	Y+,fldNum		
	st   X+,tmp
	inc  tmpC
SortInto20:
	inc	fldNum
	cpi  fldNum,fldAnz+1	 
	brne	SortInto10
	st	X,zero		; terminating 0 in ref and srt
	st  	Y,zero
	;tmpC contains the number of entries to sort
	sts	refLen,tmpC	
	tst	tmpC
	breq	SortDone		; already solved
  
SortRef:
	PfiHigh 2
	lds tmpC,refLen
	sbic myGp, gpSndDebug 
	rcall ShowRef			;before

; Step2: sort ref/srt desc by srt, use easy bubblesort, much room for improvements 
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
; On entry tempC (must be set) points to the end of ref/srt. 
; after each iteration [tmpC] has the lowest value, so tmpC is dec'd
; also no further action required if there was no swap during a run
; Debug only:
SortRef10:			; For each run
	setXPtr	srt+1
	setYPtr	ref+1     ;
	ldi	tmp,1		; loop counter
	cbi	myGP, gpSwp	; no swap occured
SortRef40:			; for each field
	ld	tmpH,X+		
	ld	tmpL,X
	ld	WH,  Y+ 	     ; Y in sync with X
	cp	tmpH,tmpL		; carry is set if L>H
	brcc	SortRef50		; no swap  
	sbi	myGP, gpSwp	; remember swap
	PfiTog 3			; and show
	st	-X,tmpL
	adiw	XL,1
	st	X,tmpH
	ld	WL,Y			; swap field number also
	st	-Y,WL
	adiw	YL,1
	st	Y,WH
SortRef50:			
	inc  tmp
	cp	tmp,tmpC
	brne	SortRef40		; next field
; one run completed
	sbis	myGP,gpSwp
	rjmp	SortDone
	dec  tmpC
	cpi	tmpC,1
	brne SortRef10
SortDone:
	clr tmp 			; all ok
	PfiLow 2
	PfiLow 3			; so it's defined
	sbic myGp, gpSndDebug 
	rcall ShowRef		;after
	ret		
; continue with 
;
ImprRef:
	PfiLow 2
; change field order in ref to get faster solutions (i assume...)
; Basic idea: identify all fields in ref which directly depend on the 
; first entry. Mark these by setting the higher nibble of the dof (1..7)
; sort , then redo with a lower mark
	lds tmp,	refLen		; no improvements on ref len 0
	tst tmp
	breq	ImprRefNix
	ldi  	refp,1		; for the entry in refp (with highest dof)
	SetXIdx 	srt, refP 
	SetYIdx 	ref, refP
	clr  tmpL
; loop thru to find first entry not improved
ImprRef3:
	ld 	fldNum, Y+		; contains the Field number to check
	ld	tmp, X+			; contains its dof (X/Y always in sync)
	mov  tmpH,tmpL			; save   L    H
	mov	tmpL,tmp            ;      curr  prev
	andi tmp,0xF0
	brne ImprRef3			; will leave loop latest at 0-terminator
	tst  tmpL
	breq ImprRefNix		; really 0
; fldNum is the first not improved, tmpL its dof, tmpH this of its pred
	andi tmpH,0xF0
	subi tmpH,0x10		
	tst  tmpH
	; 15 ?
	mov	auxH,tmpH			; the marker value to use
	or	tmpL,auxH			; Mark
	st	-X,tmpL			;	
	adiw X,1		
	SETZ2ROM 				; Z^ to fields possibly reachable from this
	movw WL,Z				; remember 
ImprRef10:				; For each subsequent field in ref
	ld 	tmpL,Y+			; get its number
	ld	auxL, X+			; and dof
	tst 	tmpL				; 
	breq ImprRefDone		; 0=ref completed
	movW ZL,WL			; Starting point in chk
ImprRef20:				; For each field in chk
	lpm	tmp,Z+			; this is the Field# to compare chk to
	tst tmp				
	breq ImprRef10			; chk at end, not found, don't mark
	cp tmpL,tmp			; 
	breq ImprRefMark		; is in chk, ergo mark
	brcs ImprRef10			; if tmp>tmpL (carry set) then not found
	rjmp	ImprRef20			; next chk
ImprRefMark:
	or	auxL,auxH			; Mark
	st   -X,auxL			; and store X jumping back 
	adiw	X,1				; 			 .. and forth
	rjmp	ImprRef10			; Next field in refptr
ImprRefDone:
	rcall SortRef
ImprRefNix:
	PfiHigh 2
	ret
;

BuildExc:
; Build Exclusion list for given fldNum
;
; clear the exclusion list (always 9)
	PfiHigh 4
	ldi	tmpC,9
	setYPtr exc+1 	   ;0 not used
BuildExc1:
	st	Y+,zero
	dec	tmpC
	brne BuildExc1 
	SETZ2ROM
BuildExc10:			; For each field in chk
	lpm	tmp,Z+			; this is the Field# to compare chk to
	tst	tmp			; if zero this comparison completed
	breq	BuildExcDone
	SetYIdx 	fld, tmp    
	ld   tmp,Y 		; Y now points to it, tmp is its value
	tst  tmp
	breq BuildExc10	; is zero
	SetYIdx 	exc, tmp  ; Store value in exclusion list
	st	Y,tmp  
	rjmp	BuildExc10	; check next
BuildExcDone:
	PfiLow 4
	ret


ValidateGame:
; check a game if its a solution 
; for each fldNum the value must be 1..9 and the Exclusion List must only be 0 for this 
	ldi	fldNum,fldAnz	;H
ValidateGame10:
	rcall BuildExc
	setYIdx	fld, fldNum	
	ld	tmpL,Y	; my value
	tst  tmpL
	breq ValidateGame33   ; no validations if zero
	ldi	tmpC,1		
	setYIdx	exc, tmpC	
ValidateGame20:				; for the 9 values
	ld	tmpH,Y+			; the excluded value here
	cp   tmpH,tmpC
	breq	ValidateGame30
	tst  tmpH				; the excluded value should be 0 and the index my value
	brne	ValidateGameErr
	cp	tmpC , tmpL
	brne	ValidateGameErr		
ValidateGame30:				; next value to check
	inc	tmpC
	cpi	tmpC,10
	brne ValidateGame20
ValidateGame33:  			; next field to check
	dec fldNum	
	brne ValidateGame10
	sbis myGp, gpSndDebug ; send result back
	ret
	ldi	tmp,'o'
	rcall V24Send
	ldi	tmp,'k'
ValidateGame35:
	rcall V24Send
	rcall V24SendCR
	clr	tmp	;return OK
	PfiLow 3
	ret
ValidateGameErr:
; oha, for fldNum with value tmpL the excluded is tmpH at index tmpC
	PfiLow 3
	sbis myGp, gpSndDebug
	ret
	ldi	tmp,'E' 
	rcall V24Send
	mov	tmp,fldNum
	rcall V24SendByte	;field
	mov	tmp,tmpL
	rcall V24SendByte   ;Value
	mov	tmp,tmpC
	rcall V24SendByte   ;Index
	mov	tmp,tmpH
	rcall V24SendByte   ;excluded

	rcall V24SendCR
	mov	tmp,fldNum
	ori	tmp,0x80	;must not be 0 on err
	ret


SudInfo:
; given on request:
	rcall ShowBck
	ret

SudKey:				; called if interrupted by keyboard
	rcall V24Receive	; fetch char
SudKey10:
	ldi tmp,'S'
	mov tmpH,fldNum
	mov tmpL,refP
	rcall ErrHand ; result is compared in caller
	ret

SudSolution:	;here if solution found
	out	TCNT0,zero   	; so there is time to get consistent counter values
	PfiLow 4			; indicate Done 
	PfiHigh 3
; Output Statistics
.IF  Statistics == 1		; ONLY ON PRO ****************************************
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
.ENDIF				; END ONLY ON PRO ****************************************
SudSolution50:
; we proudly present:
	PfiHigh 4
	rcall ShowFld
	clr tmp			; indicate success
	ret

SudNext:				; here when evaluating the next field ponted to in refP 
	PfiHigh 3			; indicate Down 
	rcall V24ReceiveAvail ;char from V24?
	tst tmp
	breq SudNext02
	rcall SudKey		; user interaction
	cpi tmp,'q'		; if tmp is 'q' user reqested abort
	brne  SudNext02
	ret				; with my 
SudNext02:
.IF  Statistics == 1		; ONLY ON PRO ****************************************
	inc	dwnL			; counter
	brne SudNext1
	inc	dwnH
	brne SudNext1
	; after 65536 downs some housekeeping:
	ldi  tmp,'.'
	sbic	myGP,gpSndDebug
	sts  UDR0,tmp			; brute force alive signal
; if info is set, give it now
	sbic	myGP, gpInfo
	rcall SudInfo
	inc	dwnX
	brne SudNext1
	inc	dwnXX			; 16 Mio counter 
.ENDIF				; END ONLY ON PRO ****************************************
SudNext1:			
	SetXIdx 	ref, refP 	; get Field # refP points to
	ld 	fldNum ,X			; contains the Field number to check
	tst  fldNum			; found a valid solution if 0 
	breq	SudSolution
	SetXIdx 	fld, fldNum	; X points to the field to vary, set it to 0
	st 	X,zero
	rcall BuildExc
	movw XL,bckPL			; transfer possible values to backtrack; X to bckList
	                         ; seems to be faster to use reverse order of possible values (1..9) vs 9..1
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
	PfiLow 3			; indicate Back
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
	sts  chk,tmp
	ldi  tmp,'D'
	sts	dof,tmp
	ldi  tmp,'S'
	sts	srt,tmp
	ldi  tmp,'N'
	sts	endInd,tmp
	ret

SudoSanity10:
; compares tmpC and tmp
	rcall V24SendCR
	rcall V24SendSpc
	push  tmp
	mov   tmp,tmpC
	rcall V24SendByte
	pop   tmp
	cp	tmp,tmpc
	breq SudoSanity20
	ldi  tmp,'<'
	rcall V24Send
	ldi  tmp,'E'
	rcall V24Send
SudoSanity20:
	ret

SudoSanity:
; checks [0] of arrays
	push tmp
	push tmpC
	ldi  tmp,'F'
	lds	tmpc,fld
	rcall SudoSanity10
	ldi  tmp,'R'
	lds	tmpc,ref
	rcall SudoSanity10
	ldi  tmp,'B'
	lds	tmpc,bck
	rcall SudoSanity10
	ldi  tmp,'X'
	lds	tmpc,exc
	rcall SudoSanity10
	ldi  tmp,'C'
	lds	tmpc,  chk
	rcall SudoSanity10
	ldi  tmp,'D'
	lds	tmpc,dof
	rcall SudoSanity10
	ldi  tmp,'S'
	lds	tmpc,srt
	rcall SudoSanity10
	ldi  tmp,'N'
	lds	tmpc,endInd
	rcall SudoSanity10
	rcall V24SendCR
	pop tmpC
	pop tmp
	ret


.IF  Statistics == 1		; ONLY ON PRO #TODO****************************************
BuildChk:
; build a list of fields to check from given fldnum (takes 14uS each step down)
; is replaced by an hardcoded 81*20 array to speed up
; chk should be sorted ascending! 
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
	andi	tmpL, 0xF 	; the column
	swap tmpH
	andi	tmpH, 0xF 	; the row

; get all row fields except me
	ldi	tmpC, rcAnz
	mul	tmpH,tmpC 
	mov	tmp,resL		; the rightmost field
	subi tmp,rcAnz-1	; the leftmost field
BuildChk10:
	cp	tmp,fldNum
	breq	BuildChk15
	st	y+,tmp	
BuildChk15:
	inc  tmp
	dec  tmpC
	brne   BuildChk10

; get all column fields except me
	ldi	tmpC, rcAnz
	mov	tmp, tmpL		; the topmost field
BuildChk20:
	cp	tmp,fldNum
	breq	BuildChk25
	st	y+,tmp	
BuildChk25:
	subi	tmp, -rcAnz
	dec  tmpC
	brne BuildChk20 

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
BuildChk45:			; For each of the 4
	lpm	tmp,Z+
	add  tmp,fldnum
	st	Y+,tmp
	dec	tmpC
	brne BuildChk45	; next 4
; Gott sei Dank:
	st	Y,zero   	 	; the terminating 0
	PfiLow 2			; indicate End
.ENDIF
;
; continue with 
;
SortChk:
; Step2: sort ref/srt desc use easy bubblesort
;          [0]       [tmpC]                
; chk       12  23  33  45
;           X^
;   1 A         X^
;           H   L   swap if L<H
;           12  23  
;   2               X^
;   3                   X^
; after each iteration [tmpC] has the highest value, so tmpC is dec'd
; also no further action required if there was no swap during a run
	ldi  tmpC,20	
SortChk13:
	setXPtr	chk
	ldi	tmp,1		; loop counter
	cbi	myGP, gpSwp	; no swap occured
SortChk40:			; for each field in chk
	ld	tmpH,X+		
	ld	tmpL,X
	cp	tmpL,tmpH		; carry is set if H>L
	brcc	SortChk50		; no swap  
	sbi	myGP, gpSwp	; remember swap
	st	-X,tmpL
	adiw	XL,1
	st	X,tmpH
SortChk50:			
	inc  tmp
	cp	tmp,tmpC
	brne	SortChk40		; Next field
; one run completed
	sbis	myGP,gpSwp
	rjmp	SortChkDone	; no changes
	dec  tmpC
	brne SortChk13		; Next run
SortChkDone:
	ret		
