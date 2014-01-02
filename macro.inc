; Some Macros to ease Port settings
.MACRO PortOutB ; num on B as output to zero
	sbi DDRB, @0
	cbi PORTB,  @0
.ENDMACRO

.MACRO PortPupB ; num on B as input with Pup
	cbi DDRB , @0
	sbi PORTB, @0
.ENDMACRO

.MACRO PortOutD ; num on D as output to zero
	sbi DDRD, @0
	cbi PORTD,  @0
.ENDMACRO

.MACRO PortPupD ; num on D as input with Pup
	cbi DDRD , @0
	sbi PORTD, @0
.ENDMACRO

.MACRO SetXPtr ; point X to RAM
	ldi     XL, LOW(@0)
     ldi     XH, HIGH(@0)
.ENDMACRO

.MACRO setXIdx ; point X to RAM plus offset
     ldi	XL, LOW(@0)
     ldi  XH, HIGH(@0)
	add	XL, @1
	brcc pc+2
	inc	XH
.ENDMACRO

.MACRO SetYPtr ; point Y to RAM
        ldi     YL, LOW(@0)
        ldi     YH, HIGH(@0)
.ENDMACRO

.MACRO setYIdx ; point Y to RAM plus offset
     ldi	YL, LOW(@0)
     ldi  YH, HIGH(@0)
	add	YL, @1
	brcc pc+2
	inc	YH
.ENDMACRO

.MACRO SetZPtr ;point Z to RAM
        ldi     ZL, LOW(@0)
        ldi     ZH, HIGH(@0)
.ENDMACRO

.MACRO SetZCode ;point X to Flash
        ldi     ZL, LOW(2*@0)
        ldi     ZH, HIGH(2*@0)
.ENDMACRO
