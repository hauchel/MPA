; This file contains the lookup values for each sudoku field
; observe padding if odd number of .db's given

;For the 9 fields the offset to use to FldNum to get the not-covered fields
quad: 
.db rcAnz+1,     rcAnz+2,   2*rcAnz+1, 2*rcAnz+2
.db rcAnz-1,     rcAnz+1,   2*rcAnz-1, 2*rcAnz+1
.db rcAnz-2,     rcAnz-1,   2*rcAnz-2, 2*rcAnz-1
.db -rcAnz+1,   -rcAnz+2,   rcAnz+1,   rcAnz+2
.db -rcAnz-1,   -rcAnz+1,   rcAnz-1,   rcAnz+1
.db -rcAnz-2,   -rcAnz-1,   rcAnz-2,   rcAnz-1
.db -2*rcAnz+1, -2*rcAnz+2, -rcAnz+1,  -rcAnz+2
.db -2*rcAnz-1, -2*rcAnz+1, -rcAnz-1,  -rcAnz+1
.db -2*rcAnz-2, -2*rcAnz-1, -rcAnz-2,  -rcAnz-1



.IF GameSize==9 					;*******************************************
; Variant for 9 fields
;example Games need to pad X
Games: 
.db "..61.75.3X"
.db "73.52496.X"
.db "..61875.3X"
.db "548639.71X"
.db "ZZ"	; End of Games
Schwer:
.db "ZZ"
; Convert field# to Row (HiNib) and Column
Fld2RC: 
.db 0x11,0x12,0x13, 0x21,0x22,0x23, 0x31,0x32,0x33,0

.ELIF  GameSize==81   				;*******************************************
; Variant for 81 fields
Fld2RC: 
.db 0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29
.db 0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49
.db 0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69
.db 0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89
.db 0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0
;
; http://www.sudoku-kacker.de/47625.htm:
Games:
;17601  ms
.db "..654873.1876395245.3.7196.6759241.343.18.6522183.549785.41.37.79.8532463.47.2815X"
;31913: ms
.db "98754....36..8.9.74219.38..8...9..3219.3.87.627365..98.42.6.513..9.15.84.18432.7.X"
;47625: ms
.db "3..751....9..2..5.5...3.276..928.5.....39...47.3.648..172...6.5.4.....8...85.9..2X"
.db "ZZ"
Schwer:
;119144  14 sec
.db "5..6.8.7..13...9...........8..5...6..4..1.................9.4.16..2..............X"
;99291    3 sec
.db ".1...4..2..6....8......3...8.7.5......5..............4.3.2.1.........57..4.......X"
;113652  very long
.db "2.7......5..3..........4....4....1.3....2..........4...836.........7.52........9.X"
;81975 should be faster to solve
.db ".......538...6...........7....2..8.....7.5...1.........72..3......61.4...5.......X"
;69862 should be faster to solve
.db "89..51.3.6.3.........7.....9..3..2...72...58...4..8..9.....2.........8.6.5.41..27X"
.db "ZZ"

.ELSE 
.WARNING "Please define GameSize=9 or GameSize=81" 
.ENDIF
