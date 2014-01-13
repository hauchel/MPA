txHlp: .db 13,\
" 1..9    field value " 	,13, \
" 0 or .  empty field"  	,13, \
" Result "  	,13, \
" a all tests simple"	,13, \
" A all tests schwer"	,13, \
" b show backtrack"		,13, \
" c show checkfields"	,13, \
" d calc Dof"			,13, \
" D show Dof without calc"	,13, \
" e show exc"			,13, \
" f show fld"			,13, \
" g go solve current"	,13, \
" h this text"			,13, \
" i improve ref"		,13, \
" j jump to solve after game read"		,13, \
" J no jump"		,13, \
" l load"				,13, \
" n next test game"		,13, \
" r show ref",13, \
" R create ROM for ref"	,13, \
" t read first test games",13, \
" T read first schwer"	,13, \
" v validate current"	,13, \
" V sanity check array bounds"	,13, \
" w wait on Err"		,13, \
" W no wait on Err"		,13, \
" y send debug"		,13, \
" Y no debug"			,13, \
" Z jmp RESET"			,13, \
" # call Error Handler"	,13, 13,\
" Output:",13, \
"   > command prompt",13, \
"   ? sorry, what exactly do you want?",13, \
"   fnn game read complete with nn fields (n is 0x51)",13, \
"   . backtrack:",13, \
"     .01E7 42 B9 09 83 ..",13, \
"       ptr 42 dd dd dd ..",13, \
"              dd high bit 1 field number, B9 = 0x39 = 57"		,13, \
"              dd high bit 0 possible values remaining for field"	,13, \
"   T statistics in hex:"	,13, \
"     T 00 21 D4 N 03 53 3D"	,13, \
"     Time for solution in ms: 0x0021D4 =    8.660 sec"	,13, \
"                Number downs: 0x03533D = 217917 downs"	,13, \
"   E error "	,13,13, \
" Performance indication on ports:",13, \
"   D2  H Readgame LH BuildDof L IntoRef H SortRef L ImprRef H   Searching  L Solved ",13, \
"   D3 L           H Repl L               T Swap                H Dwn L Up ",13, \
"   D4 H BuildExc down L up, also toggle for each swap during Sort",13, \
" Also used for RX Debugging:",13, \
"   D3 H during V24Receive",13, \
"   D4 H during RX Interrupt Handler",13, \
0,0
