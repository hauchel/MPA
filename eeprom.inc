;Misc EEPROM and Fuse related  


ReadFuses:
; Reurns Fuses in tmpL, tmpH and tmp
	push ZL
	push ZH
	in   sregEE,SREG
	cli
	clr ZL
	clr ZH
	ldi tmp, (1<<RFLB)|(1<<SELFPRGEN)
	out SPMCSR,tmp
	LPM tmpL,Z	;FBL at 0
	ldi	ZL,3
	out SPMCSR,tmp
	LPM tmpH,Z	;FBH at 3
	ldi	ZL,2
	out SPMCSR,tmp
	LPM tmp,Z	;FBH at 3
; restore ints
	out SREG,sregEE
	pop ZH
	pop ZL
	ret


EEPROM_Write:
; Write tmp to EEprom tmpH/L, uses sregEE
; Wait for completion of previous write
	sbic EECR,EEPE
	rjmp EEPROM_write
; Set up address in address register
	out EEARH, tmpH
	out EEARL, tmpL
; Disable Ints
	in   sregEE,SREG
	cli
; Write data to Data Register
	out EEDR,tmp
; Write logical one to EEMPE
	sbi EECR,EEMPE
; Start eeprom write by setting EEPE
	sbi EECR,EEPE
	out SREG,sregEE
	ret

EEPROM_Read:
; Read tmpL/H, uses sregEE to store current Int settings
; Wait for completion of previous write
	sbic EECR,EEPE
	rjmp EEPROM_read
	; Set up address in address register
	out EEARH, tmpH
	out EEARL, tmpL
; Disable Ints
	in   sregEE,SREG
	cli
; Start eeprom read by writing EERE
	sbi EECR,EERE
; Read data from Data Register
	in tmp,EEDR
	out SREG,sregEE
	ret

EEPROM_Save:
; writes ZL/H to tmpL/H with tmpC bytes (all destroyed)
	push tmp
EEPROM_Save0:
	ld 	tmp,Z+
	rcall EEPROM_write
	inc 	tmpL
	brne EEPROM_Save1
	inc 	tmpH
EEPROM_Save1:
	dec	tmpC
	brne	EEPROM_Save0
	pop tmp
	ret

EEPROM_Load:
; reads ZL/H to tmpL/H with tmpC bytes (all destroyed)
	push tmp
EEPROM_Load0:
	rcall EEPROM_read
	st 	Z+,tmp
	inc 	tmpL
	brne EEPROM_Load1
	inc 	tmpH
EEPROM_Load1:
	dec	tmpC
	brne	EEPROM_Load0
	pop tmp
	ret
