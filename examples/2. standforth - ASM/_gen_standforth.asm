;################################################
;; GLOBAL CONFIG
;;

;;===============================================
;; PART DEFINITION
.include "partdef.inc"

;;===============================================
;; REGISTER MAP
;.def dspL = r2 ; data stack pointer
;.def dspH = r3

.def destL = r4
.def destH = r5
.def sourceL = r6
.def sourceH = r7
.def countL = r8
.def countH = r9

.def ZZL = r20 ; акумулятор
.def ZZH = r21

.def tempIL = r10
.def tempIH = r11

.def temp	= r16
.def temp2	= r17
.def tempL	= r18
.def tempH	= r19
.def temp2L = r22
.def temp2H = r23

; free
; .def r0 =  ; використовується у операціях множення
; .def r1 =
; .def r12 =
; .def r13 =
; .def r14 =
; .def r15 =
 .def dspL = r24
 .def dspH = r25


;################################################
;; DATA SEGMENT
.dseg

DATA_STACK:		.byte 50
RETURN_STACK:	.byte 2

ENTRY_POINT:	.byte 60
PROG_START:		.byte 60
WORDS_START:	.byte 2

; Environment specific defs
.include "ev8031.asm"


;################################################
;; CHIP settings
; Define baud rate
;.equ USART_BAUD = 38400
.equ USART_UBBR_VALUE = 47

;################################################
;; MACRO and FUNCTIONS


;################################################
;; CODE SEGMENT
.cseg

	rjmp RESET

.org 0x40
RESET:
	; Ініціалізація стеку повернень


	ldi temp, low(RETURN_STACK)
	out SPL, temp


	ldi temp, high(RETURN_STACK)
	out SPH, temp

	; Дозволити зовнішню пам’ять
	;  Заодно налаштувати зовнішні переривання


	ldi temp, MAGIC_MEMORY_INIT
	out MCUCR, temp


	; Копіювати прошивку з flash у RAM
	rcall copyFirmware

	; Дозволити переривання
	;`out SREG, 1<<INT_ENABLE  ;? замінити на sei?
	;`out GICR, 1<<INT0
	rcall coldStart
	;`store (TIB - START_CODE)*2 + WORDS_START,        (FORTH_PROG_START - START_CODE)*2 + WORDS_START


	ldi tempL, low(0x4000)
	ldi tempH, high(0x4000)
	sts (TIB-START_CODE)*2+WORDS_START,   tempL
	sts (TIB-START_CODE)*2+WORDS_START+1, tempH


	ldi tempL, low((FORTH_PROG_END-FORTH_PROG_START)*2)
	ldi tempH, high((FORTH_PROG_END-FORTH_PROG_START)*2)
	sts (CTIB-START_CODE)*2+WORDS_START,   tempL
	sts (CTIB-START_CODE)*2+WORDS_START+1, tempH

	;;;;;;;;;; UAARTTTT
UART_WAIT:
	rcall USART_vInit
	clr r15
	rcall USART_Receive



	ldi ZL, low(0x4000)
	ldi ZH, high(0x4000)
uart_loop:
	rcall USART_Receive
	sts LEDs, temp
	sts INDL, temp
	inc r14
	cpi temp, 13
	  breq need_interpret
	st Z+, temp
	rjmp uart_loop

need_interpret:
	rcall USART_Flush
	subi ZL, low(0x4000)
	sbci ZH, high(0x4000)
	sts (CTIB - START_CODE)*2 + WORDS_START, ZL
	sts (CTIB - START_CODE)*2 + WORDS_START+1, ZH


	ldi tempL, low(0)
	ldi tempH, high(0)
	sts (_IN-START_CODE)*2+WORDS_START,   tempL
	sts (_IN-START_CODE)*2+WORDS_START+1, tempH
	; Запустити асемблерний інтепретатор.



	ldi temp, (1<<URSEL)
	out UCSRC, temp


	ldi temp, 0
	out UCSRB, temp

	rjmp interpret

USART_Flush:
	sbis UCSRA, RXC
	ret
	in temp, UDR
	rjmp USART_Flush


USART_vInit:


	ldi temp, high(USART_UBBR_VALUE)
	out UBRRH, temp


	ldi temp, low(USART_UBBR_VALUE)
	out UBRRL, temp



	ldi temp, (1<<URSEL)|(3<<UCSZ0)
	out UCSRC, temp


	ldi temp, (1<<RXEN)|(1<<TXEN)
	out UCSRB, temp
ret

USART_Receive:
	; Wait for data to be received
	sbis UCSRA, RXC
	rjmp USART_Receive
	; Get and return received data from buffer
	in temp, UDR
	ret

USART_Transmit:
	; Wait for empty transmit buffer
	sbis UCSRA,UDRE
	rjmp USART_Transmit
	; Put data (r16) into buffer, sends the data
	out UDR, temp
	ret

USART_SendACK:
	ldi temp, 0x33
	rcall USART_Transmit
	ldi temp, 0x33
	rcall USART_Transmit
	ldi temp, 0x33
	rcall USART_Transmit
	ret

copyFirmware:


	ldi ZL, low(START_CODE*2)
	ldi ZH, high(START_CODE*2)


	ldi XL, low(WORDS_START)
	ldi XH, high(WORDS_START)


	ldi YL, low(END_CODE*2)
	ldi YH, high(END_CODE*2)
	sub YL, ZL ; Y = END_CODE - START_CODE
	sbc YH, ZH
	ldi temp, 0
	  start_loop:
		lpm tempL, Z+
		lpm tempH, Z+
		st X+, tempL
		st X+, tempH

		sbiw YL, 2
		cp YL, temp
		cpc YH, temp
		  brne start_loop
	ret


coldStart:
	; Ініціалізація стеку даних (в регістрах dspH:dspL)


	ldi dspL, low(DATA_STACK)
	ldi dspH, high(DATA_STACK)

	; Заповнити системні змінні Форту


	ldi tempL, low((END_CODE-START_CODE)*2+WORDS_START)
	ldi tempH, high((END_CODE-START_CODE)*2+WORDS_START)
	sts (_CP-START_CODE)*2+WORDS_START,   tempL
	sts (_CP-START_CODE)*2+WORDS_START+1, tempH


	ldi tempL, low((mem_NOOP-START_CODE)*2+WORDS_START)
	ldi tempH, high((mem_NOOP-START_CODE)*2+WORDS_START)
	sts (LATEST-START_CODE)*2+WORDS_START,   tempL
	sts (LATEST-START_CODE)*2+WORDS_START+1, tempH


	ldi tempL, low(10)
	ldi tempH, high(10)
	sts (BASE-START_CODE)*2+WORDS_START,   tempL
	sts (BASE-START_CODE)*2+WORDS_START+1, tempH
	ret



; Word structure
; - Name (padded spaces left to 2n+1 bytes)
; - Name length (1 byte)
; - Link (2 bytes)
; - CFA (2 bytes)
; - rest

START_CODE:

;FORTH_PROG_START: .db "   TEST2 0 >IN !  "

mem_LIT:	.dw itc_LIT
mem_ENTER:	.dw ENTER
mem_EXIT:	.dw EXIT
mem_DOVAR:	.dw DOVAR

; Використовується для виклику повернення у асемблерний інтерпретатор
mem_RET:	.dw gethere
mmRET:		.dw (mem_RET - START_CODE)*2 + WORDS_START

;;;;;; АСЕМБЛЕРНІ СЛОВА!!! ;;;;;;;;


				.db "+", 1
				.dw 0
	mem_PLUS:		.dw itc_PLUS
	

				.db "-", 1
				.dw (mem_PLUS - START_CODE)*2 + WORDS_START
	mem_MINUS:		.dw itc_MINUS
	

				.db " R>", 2
				.dw (mem_MINUS - START_CODE)*2 + WORDS_START
	mem_TO_R:		.dw itc_TO_R
	

				.db " @R", 2
				.dw (mem_TO_R - START_CODE)*2 + WORDS_START
	mem_TO_FETCH:		.dw itc_R_FETCH
	

				.db " >R", 2
				.dw (mem_TO_FETCH - START_CODE)*2 + WORDS_START
	mem_R_FROM:		.dw itc_R_FROM
	

				.db "PUD", 3
				.dw (mem_R_FROM - START_CODE)*2 + WORDS_START
	mem_DUP:		.dw itc_DUP
	

				.db " PORD", 4
				.dw (mem_DUP - START_CODE)*2 + WORDS_START
	mem_DROP:		.dw itc_DROP
	

				.db " PAWS", 4
				.dw (mem_DROP - START_CODE)*2 + WORDS_START
	mem_SWAP:		.dw itc_SWAP
	

				.db " REVO", 4
				.dw (mem_SWAP - START_CODE)*2 + WORDS_START
	mem_OVER:		.dw itc_OVER
	

				.db "@", 1
				.dw (mem_OVER - START_CODE)*2 + WORDS_START
	mem_AT:		.dw itc_AT
	

				.db "!", 1
				.dw (mem_AT - START_CODE)*2 + WORDS_START
	mem_EXCLAM:		.dw itc_EXCLAM
	

				.db " !C", 2
				.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START
	mem_C_EXCLAM:		.dw itc_C_EXCLAM
	

				.db " @C", 2
				.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
	mem_C_AT:		.dw itc_C_AT
	

				.db " *2", 2
				.dw (mem_C_AT - START_CODE)*2 + WORDS_START
	mem_2STAR:		.dw itc_2STAR
	

				.db " /2", 2
				.dw (mem_2STAR - START_CODE)*2 + WORDS_START
	mem_2SLASH:		.dw itc_2SLASH
	

				.db "0", 1
				.dw (mem_2SLASH - START_CODE)*2 + WORDS_START
	mem_0:		.dw itc_0
	

				.db " 1-", 2
				.dw (mem_0 - START_CODE)*2 + WORDS_START
	mem_FFFF:		.dw itc_FFFF
	

				.db "PAWSC", 5
				.dw (mem_FFFF - START_CODE)*2 + WORDS_START
	mem_CSWAP:		.dw itc_CSWAP
	

				.db "DNA", 3
				.dw (mem_CSWAP - START_CODE)*2 + WORDS_START
	mem_AND:		.dw itc_AND
	

				.db "ROX", 3
				.dw (mem_AND - START_CODE)*2 + WORDS_START
	mem_XOR:		.dw itc_XOR
	

				.db " RO", 2
				.dw (mem_XOR - START_CODE)*2 + WORDS_START
	mem_OR:		.dw itc_OR
	

				.db " TREVNI", 6
				.dw (mem_OR - START_CODE)*2 + WORDS_START
	mem_INVERT:		.dw itc_INVERT
	

				.db "=", 1
				.dw (mem_INVERT - START_CODE)*2 + WORDS_START
	mem_EQUAL:		.dw itc_EQUAL
	

				.db "2EREH", 5
				.dw (mem_EQUAL - START_CODE)*2 + WORDS_START
	mem_HERE2:		.dw itc_HERE
	

				.db " DLOC", 4
				.dw (mem_HERE2 - START_CODE)*2 + WORDS_START
	mem_COLD:		.dw itc_COLD
	


				.db "NEKOT", 5
				.dw (mem_COLD - START_CODE)*2 + WORDS_START
	mem_TOKEN:		.dw itc_TOKEN
	

				.db "ESREVER", 7
				.dw (mem_TOKEN - START_CODE)*2 + WORDS_START
	mem_REVERSESTR:		.dw itc_REVERSESTR
	

				.db "REBMUN>", 7
				.dw (mem_REVERSESTR - START_CODE)*2 + WORDS_START
	mem_NUMBER:		.dw itc_NUMBER
	

;;;;;;; Змінні ;;;;;;;;
_CP:	.dw 0


				.db "BIT", 3
				.dw (mem_NUMBER - START_CODE)*2 + WORDS_START
	mem_TIB:		.dw DOCONST
	TIB:	.dw 0


				.db " BIT#", 4
				.dw (mem_TIB - START_CODE)*2 + WORDS_START
	mem_CTIB:		.dw DOCONST
	CTIB:	.dw 0


				.db "NI>", 3
				.dw (mem_CTIB - START_CODE)*2 + WORDS_START
	mem__IN:		.dw DOCONST
	_IN:	.dw 0


				.db " ESAB", 4
				.dw (mem__IN - START_CODE)*2 + WORDS_START
	mem_BASE:		.dw DOCONST
	BASE:	.dw 10


				.db " TSETAL", 6
				.dw (mem_BASE - START_CODE)*2 + WORDS_START
	mem_LATEST:		.dw DOCONST
	LATEST:	.dw 0


				.db "ETATS", 5
				.dw (mem_LATEST - START_CODE)*2 + WORDS_START
	mem_STATE:		.dw DOCONST
	STATE:	.dw 0

;;;;;; ФОРТ-слова!!! ;;;;;;;;;;;



				.db " SDEL>-", 6
				.dw (mem_STATE - START_CODE)*2 + WORDS_START
	mem_LEDS:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw LEDs

		.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "DNI>-", 5
				.dw (mem_LEDS - START_CODE)*2 + WORDS_START
	mem_IND:		.dw ENTER
	
		.dw (mem_CSWAP - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw INDICATOR

		.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " LDNI>-", 6
				.dw (mem_IND - START_CODE)*2 + WORDS_START
	mem_INDL:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw INDL

		.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " HDNI>-", 6
				.dw (mem_INDL - START_CODE)*2 + WORDS_START
	mem_INDH:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw INDH

		.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "PDDNI>-", 7
				.dw (mem_INDH - START_CODE)*2 + WORDS_START
	mem_INDDP:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw INDDP

		.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "Atrop>-", 7
				.dw (mem_INDDP - START_CODE)*2 + WORDS_START
	mem_PORTA:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw PA_REG

		.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START


				.db "Btrop>-", 7
				.dw (mem_PORTA - START_CODE)*2 + WORDS_START
	mem_PORTB:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw PB_REG

		.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START


				.db "Ctrop>-", 7
				.dw (mem_PORTB - START_CODE)*2 + WORDS_START
	mem_PORTC:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw PC_REG

		.dw (mem_C_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "1", 1
				.dw (mem_PORTC - START_CODE)*2 + WORDS_START
	mem_1:		.dw ENTER
	
		.dw (mem_0 - START_CODE)*2 + WORDS_START
		.dw (mem_FFFF - START_CODE)*2 + WORDS_START
		.dw (mem_MINUS - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " ETAGEN", 6
				.dw (mem_1 - START_CODE)*2 + WORDS_START
	mem_NEGATE:		.dw ENTER
	
		.dw (mem_INVERT - START_CODE)*2 + WORDS_START
		.dw (mem_1 - START_CODE)*2 + WORDS_START
		.dw (mem_PLUS - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " LLEC", 4
				.dw (mem_NEGATE - START_CODE)*2 + WORDS_START
	mem_CELL:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw 2
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "+LLEC", 5
				.dw (mem_CELL - START_CODE)*2 + WORDS_START
	mem_CELLPLUS:		.dw ENTER
	
		.dw (mem_CELL - START_CODE)*2 + WORDS_START
		.dw (mem_PLUS - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "SLLEC", 5
				.dw (mem_CELLPLUS - START_CODE)*2 + WORDS_START
	mem_CELLS:		.dw ENTER
	
		.dw (mem_2STAR - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " EREH", 4
				.dw (mem_CELLS - START_CODE)*2 + WORDS_START
	mem_HERE:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw (_CP - START_CODE)*2 + WORDS_START

		.dw (mem_AT - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "TOLLA", 5
				.dw (mem_HERE - START_CODE)*2 + WORDS_START
	mem_ALLOT:		.dw ENTER
	
		.dw (mem_HERE - START_CODE)*2 + WORDS_START
		.dw (mem_PLUS - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw (_CP - START_CODE)*2 + WORDS_START

		.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db ",", 1
				.dw (mem_ALLOT - START_CODE)*2 + WORDS_START
	mem_COMMA:		.dw ENTER
	
		.dw (mem_HERE - START_CODE)*2 + WORDS_START
		.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_CELL - START_CODE)*2 + WORDS_START
		.dw (mem_ALLOT - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "TOR", 3
				.dw (mem_COMMA - START_CODE)*2 + WORDS_START
	mem_ROT:		.dw ENTER
	
		.dw (mem_TO_R - START_CODE)*2 + WORDS_START
		.dw (mem_SWAP - START_CODE)*2 + WORDS_START
		.dw (mem_R_FROM - START_CODE)*2 + WORDS_START
		.dw (mem_SWAP - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "[", 129
				.dw (mem_ROT - START_CODE)*2 + WORDS_START
	mem_LEFTBRACKET:		.dw ENTER
	
		.dw (mem_0 - START_CODE)*2 + WORDS_START
		.dw (mem_STATE - START_CODE)*2 + WORDS_START
		.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "]", 1
				.dw (mem_LEFTBRACKET - START_CODE)*2 + WORDS_START
	mem_RIGHTBRACKET:		.dw ENTER
	
		.dw (mem_1 - START_CODE)*2 + WORDS_START
		.dw (mem_STATE - START_CODE)*2 + WORDS_START
		.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " )ETAERC(", 8
				.dw (mem_RIGHTBRACKET - START_CODE)*2 + WORDS_START
	mem_CREATE:		.dw ENTER
	
		.dw (mem_TOKEN - START_CODE)*2 + WORDS_START
		.dw (mem_HERE - START_CODE)*2 + WORDS_START
		.dw (mem_REVERSESTR - START_CODE)*2 + WORDS_START
		.dw (mem_CELLS - START_CODE)*2 + WORDS_START
		.dw (mem_ALLOT - START_CODE)*2 + WORDS_START

		.dw (mem_LATEST - START_CODE)*2 + WORDS_START
		.dw (mem_AT - START_CODE)*2 + WORDS_START
		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_HERE - START_CODE)*2 + WORDS_START
		.dw (mem_LATEST - START_CODE)*2 + WORDS_START
		.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " TNATSNOC", 8
				.dw (mem_CREATE - START_CODE)*2 + WORDS_START
	mem_CONSTANT:		.dw ENTER
	
		.dw (mem_CREATE - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw DOVAR

		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db " ELBAIRAV", 8
				.dw (mem_CONSTANT - START_CODE)*2 + WORDS_START
	mem_VARIABLE:		.dw ENTER
	
		.dw (mem_CREATE - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw DOCONST

		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw 2
		.dw (mem_ALLOT - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db ":", 1
				.dw (mem_VARIABLE - START_CODE)*2 + WORDS_START
	mem_COLON:		.dw ENTER
	
		.dw (mem_TOKEN - START_CODE)*2 + WORDS_START
		.dw (mem_HERE - START_CODE)*2 + WORDS_START
		.dw (mem_REVERSESTR - START_CODE)*2 + WORDS_START
		.dw (mem_CELLS - START_CODE)*2 + WORDS_START
		.dw (mem_ALLOT - START_CODE)*2 + WORDS_START

		.dw (mem_LATEST - START_CODE)*2 + WORDS_START
		.dw (mem_AT - START_CODE)*2 + WORDS_START
		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_HERE - START_CODE)*2 + WORDS_START
		.dw (mem_LATEST - START_CODE)*2 + WORDS_START
		.dw (mem_EXCLAM - START_CODE)*2 + WORDS_START

		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw ENTER

		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_RIGHTBRACKET - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "EMANON:", 7
				.dw (mem_COLON - START_CODE)*2 + WORDS_START
	mem_NONAME:		.dw ENTER
	
		.dw (mem_HERE - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw ENTER

		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_RIGHTBRACKET - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db ";", 129
				.dw (mem_NONAME - START_CODE)*2 + WORDS_START
	mem_SEMICOLON:		.dw ENTER
	
		.dw (mem_LEFTBRACKET - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START
		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START

		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



				.db "LARETIL", 135
				.dw (mem_SEMICOLON - START_CODE)*2 + WORDS_START
	mem_LITERAL:		.dw ENTER
	
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw (mem_LIT - START_CODE)*2 + WORDS_START
		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_COMMA - START_CODE)*2 + WORDS_START
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START

















				.db " POON", 4
				.dw (mem_LITERAL - START_CODE)*2 + WORDS_START
	mem_NOOP:		.dw ENTER
	
		.dw (mem_EXIT - START_CODE)*2 + WORDS_START



FORTH_PROG_START:
;	.db " 1              "
;	.db " DUP LEDS C! 2* "
;	.db " DUP LEDS C! 2* "
;	.db " DUP LEDS C! 2* "
;	.db " DUP LEDS C! 2* "
;	.db " DUP LEDS C! 2* "
;	.db " DUP LEDS C! 2* "
;	.db " DUP LEDS C! 2* "
;	.db " DUP LEDS C! 2* "
;	.db " BASE @ "
;	.db "   DUP >INDL "
;	.db "   1 2* 2* BASE ! "
;	.db "   BASE @ >INDH "
;	.db " BASE !"
;	.db " 0 >IN  !    "

FORTH_PROG_END:;   .db "  ", 0 , 0



END_CODE:

;;;;;;; CORE ;;;;;;;
; IP     - XH:XL
; W+2    - YH:YL
; DSP    - dspH:dspL

NEXT:
	ld YL, X+
	ld YH, X+
	ld ZL, Y+
	ld ZH, Y+
	ijmp

ENTER:
	push XL
	push XH
	movw XL, YL
	rjmp NEXT

EXIT:
	pop XH
	pop XL
	rjmp NEXT

mRET:
	ret

ds_PUSH_ZZ:
	movw ZL, dspL
	st Z+, ZZL
	st Z+, ZZH
	movw dspL, ZL
	ret

ds_POP_ZZ:
	movw ZL, dspL
	ld ZZH, -Z
	ld ZZL, -Z
	movw dspL, ZL
	ret

DOVAR:
	movw ZL, YL
	ld ZZL, Z+
	ld ZZH, Z+
	rcall ds_PUSH_ZZ
	rjmp NEXT

DOCONST:
	movw ZZL, YL
	rcall ds_PUSH_ZZ
	rjmp NEXT

;;;;;;;;;;;;;;;;;;;;





itc_COLD:
	rcall coldStart

	; Ініціалізація стеку повернень


	ldi temp, low(RETURN_STACK)
	out SPL, temp


	ldi temp, high(RETURN_STACK)
	out SPH, temp

	rjmp interpret

itc_DUP:
	rcall _DUP
	rjmp NEXT
_DUP:
	movw ZL, dspL
	ld ZZH, -Z
	ld ZZL, -Z
	adiw ZL, 2
	st Z+, ZZL
	st Z+, ZZH
	movw dspL, ZL
	ret

itc_DROP:
	rcall _DROP
	rjmp NEXT
_DROP:
	movw ZL, dspL
	subi ZL, 2
	sbci ZH, 0
	movw dspL, ZL
	ret

itc_OVER:
	rcall _OVER
	rjmp NEXT
_OVER:
	movw ZL, dspL
	subi ZL, 4
	sbci ZH, 0
	ld ZZH, Z+
	ld ZZL, Z+
	movw ZL, dspL
	st Z+, ZZL
	st Z+, ZZH
	movw dspL, ZL
	ret

itc_SWAP:
	rcall _SWAP
	rjmp NEXT
_SWAP:
	movw ZL, dspL
	ld tempH, -Z
	ld tempL, -Z
	ld ZZH, -Z
	ld ZZL, -Z
	st Z+, tempL
	st Z+, tempH
	st Z+, ZZL
	st Z+, ZZH
	movw dspL, ZL
	ret

itc_CSWAP:
	rcall _CSWAP
	rjmp NEXT
_CSWAP:
	movw ZL, dspL
	ld tempH, -Z
	ld tempL, -Z
	st Z+, tempH
	st Z+, tempL
	movw dspL, ZL
	ret

itc_ROT:
	rcall _ROT
	rjmp NEXT
_ROT:
	rcall _SWAP
	pop ZZH
	pop ZZL
	rcall ds_PUSH_ZZ
	rcall _SWAP
	ret

itc_R_FETCH:
	pop  ZZH
	pop  ZZL
	push ZZL
	push ZZH
	rcall ds_PUSH_ZZ
	rjmp NEXT


itc_TO_R:
	rcall ds_POP_ZZ
	push ZZL
	push ZZH
	rjmp NEXT
_TO_R:
	rcall ds_POP_ZZ
	pop tempH
	pop tempL
	push ZZH
	push ZZL
	push tempL
	push tempH
	ret

itc_R_FROM:
	pop ZZH
	pop ZZL
	rcall ds_PUSH_ZZ
	rjmp NEXT
_R_FROM:
	pop tempH
	pop tempL
	pop ZZL
	pop ZZH
	push tempL
	push tempH
	rcall ds_PUSH_ZZ
	ret


itc_EXCLAM:
	rcall _EXCLAM
	rjmp NEXT
_EXCLAM:
	movw tempL, XL
	movw XL, dspL
	ld ZH, -X
	ld ZL, -X
	ld ZZH, -X
	ld ZZL, -X
	st Z+, ZZL
	st Z+, ZZH
	movw dspL, XL
	movw XL, tempL
	ret

itc_AT:
	rcall _AT
	rjmp NEXT
_AT:
	rcall ds_POP_ZZ
	movw ZL, ZZL
	ld ZZL, Z+
	ld ZZH, Z+
	rcall ds_PUSH_ZZ
	ret

itc_LIT:
	rcall _LIT
	rjmp NEXT
_LIT:
	ld ZZL, X+
	ld ZZH, X+
	rcall ds_PUSH_ZZ
	ret

itc_PLUS:
	rcall _PLUS
	rjmp NEXT
_PLUS:
	rcall ds_POP_ZZ
	mov temp2L, ZZL
	mov temp2H, ZZH
	rcall ds_POP_ZZ
	add ZZL, temp2L
	adc ZZH, temp2H
	rcall ds_PUSH_ZZ

	ret

itc_MINUS:
	rcall _MINUS
	rjmp NEXT
_MINUS:
	rcall ds_POP_ZZ
	mov temp2L, ZZL
	mov temp2H, ZZH
	rcall ds_POP_ZZ
	sub ZZL, temp2L
	sbc ZZH, temp2H
	rcall ds_PUSH_ZZ
	ret

itc_AND:
	rcall _AND
	rjmp NEXT
_AND:
	rcall ds_POP_ZZ
	mov temp2L, ZZL
	mov temp2H, ZZH
	rcall ds_POP_ZZ
	and ZZL, temp2L
	and ZZH, temp2H
	rcall ds_PUSH_ZZ
	ret

itc_OR:
	rcall _OR
	rjmp NEXT
_OR:
	rcall ds_POP_ZZ
	mov temp2L, ZZL
	mov temp2H, ZZH
	rcall ds_POP_ZZ
	or ZZL, temp2L
	or ZZH, temp2H
	rcall ds_PUSH_ZZ
	ret

itc_XOR:
	rcall _XOR
	rjmp NEXT
_XOR:
	rcall ds_POP_ZZ
	mov temp2L, ZZL
	mov temp2H, ZZH
	rcall ds_POP_ZZ
	eor ZZL, temp2L
	eor ZZH, temp2H
	rcall ds_PUSH_ZZ
	ret

itc_NEG:
	rcall _NEG
	rjmp NEXT
_NEG:
	rcall _INV
	ldi ZZL, 1
	clr ZZH
	rcall ds_PUSH_ZZ
	rcall _PLUS
	ret

itc_INV:
	rcall _INV
	rjmp NEXT
_INV:
	rcall ds_POP_ZZ
	com ZZL
	com ZZH
	rcall ds_PUSH_ZZ
	ret



itc_HERE:
	rcall _HERE
	rjmp NEXT
_HERE:
	ldi ZL, low((_CP - START_CODE)*2 + WORDS_START)
	ldi ZH, high((_CP - START_CODE)*2 + WORDS_START)
	ld ZZL, Z+
	ld ZZH, Z+
	rcall ds_PUSH_ZZ
	ret

itc_ALLOT:
	rcall _ALLOT
	rjmp NEXT
_ALLOT:
	ldi ZL, low((_CP - START_CODE)*2 + WORDS_START)
	ldi ZH, high((_CP - START_CODE)*2 + WORDS_START)
	ld ZZL, Z+
	ld ZZH, Z+
	rcall ds_PUSH_ZZ
	rcall _PLUS
	rcall ds_POP_ZZ
	ldi ZL, low((_CP - START_CODE)*2 + WORDS_START)
	ldi ZH, high((_CP - START_CODE)*2 + WORDS_START)
	st Z+, ZZL
	st Z+, ZZH
	ret

itc_EXECUTE:
	rcall _EXECUTE
	rjmp NEXT
_EXECUTE:
	rcall ds_POP_ZZ
	movw YL, ZZL
	ld ZL, Y+
	ld ZH, Y+
	ijmp
	ret


itc_COLON:
	rcall _COLON
	rjmp NEXT
_COLON:
	ret

itc_SEMICOLON:
	rcall _SEMICOLON
	rjmp NEXT
_SEMICOLON:
	ret



itc_EQUAL:
	rcall ds_POP_ZZ
	mov temp2L, ZZL
	mov temp2H, ZZH
	rcall ds_POP_ZZ
	cp ZZL, temp2L
	cpc ZZH, temp2H
	brne itc_0
	rjmp itc_FFFF


itc_0:
	clr ZZL
	clr ZZH
	rcall ds_PUSH_ZZ
	rjmp NEXT

itc_FFFF:
	ser ZZL
	ser ZZH
	rcall ds_PUSH_ZZ
	rjmp NEXT

itc_C_AT:
	rcall _C_AT
	rjmp NEXT
_C_AT:
	rcall ds_POP_ZZ
	movw ZL, ZZL
	ld ZZL, Z
	clr ZZH
	rcall ds_PUSH_ZZ
	ret

itc_C_EXCLAM:
	rcall _C_EXCLAM
	rjmp NEXT
_C_EXCLAM:
	movw tempL, XL
	movw XL, dspL
	ld ZH, -X
	ld ZL, -X
	ld ZZH, -X
	ld ZZL, -X
	st Z, ZZL
	movw dspL, XL
	movw XL, tempL
	ret

itc_2STAR:
	rcall _2STAR
	rjmp NEXT
_2STAR:
	rcall ds_POP_ZZ
	lsl ZZL
	rol ZZH
	rcall ds_PUSH_ZZ
	ret

itc_INVERT:
	rcall _INVERT
	rjmp NEXT
_INVERT:
	rcall ds_POP_ZZ
	com ZZL
	com ZZH
	rcall ds_PUSH_ZZ
	ret

itc_2SLASH:
	rcall _2SLASH
	rjmp NEXT
_2SLASH:
	rcall ds_POP_ZZ
	asr ZZh
	ror ZZl
	rcall ds_PUSH_ZZ
	ret






; Змінює >IN - пропускає прогалики і 0. Якщо кінець рядку, то >IN = #TIB
trailing:


	lds sourceL, (TIB-START_CODE)*2+WORDS_START
	lds sourceH, (TIB-START_CODE)*2+WORDS_START+1


	lds countL, (_IN-START_CODE)*2+WORDS_START
	lds countH, (_IN-START_CODE)*2+WORDS_START+1


	lds tempL, (CTIB-START_CODE)*2+WORDS_START
	lds tempH, (CTIB-START_CODE)*2+WORDS_START+1

	add tempL, sourceL ; temp = TIB + CTIB   equ    end of line
	adc tempH, sourceH

	movw ZL, sourceL
	add ZL, countL     ; Z = TIB + _IN    equ   current
	adc ZH, countH

	check_if_line_ended:
		cp ZL, tempL
		; brne is_current_char_space
		cpc ZH, tempH
		 brne is_current_char_space
		; oh no! line ended!
		rjmp finish_trailing
	is_current_char_space:
		ld temp, Z+
	  	cpi temp, 32
		 breq check_if_line_ended
	  	cpi temp, 0
		 breq check_if_line_ended
		; current char is not space!
		sbiw ZL, 1
  finish_trailing:
	sub ZL, sourceL
	sbc ZH, sourceH
	movw countL, ZL

	ldi ZL, low((_IN - START_CODE)*2 + WORDS_START)
	ldi ZH, high((_IN - START_CODE)*2 + WORDS_START)
	st Z+, countL
	st Z+, countH

	ret


; Копіює рядок з одного місця в інше, обертаючи його дзеркально
; ( addr-from addr-to -- len-in-cells )
itc_REVERSESTR:
	rcall ds_POP_ZZ
	movw destL, ZZL
	rcall ds_POP_ZZ
	movw sourceL, ZZL

	rcall reversestr

	movw ZZL, countL
	rcall ds_PUSH_ZZ
	rjmp NEXT
reversestr:
	movw ZL, sourceL
	clr countH
	ld countL, Z
	lsr countL
	inc countL

	lsl countL
	add destL, countL
	adc destH, countH
	lsr countL

	clr temp
	push XL
	push XH
	movw XL, sourceL
	movw ZL, destL
	rev_for_each:
		ld tempL, X+
		ld tempH, X+
		st -Z, tempL
		st -Z, tempH
		inc temp
		cpse temp, countL
	rjmp rev_for_each
	pop XH
	pop XL
	ret


itc_TOKEN:


	lds tempL, (_CP-START_CODE)*2+WORDS_START
	lds tempH, (_CP-START_CODE)*2+WORDS_START+1


	subi tempL, low(-1000)
	sbci tempH, high(-1000)
	movw destL, tempL
	rcall word



	lds ZZL, (_CP-START_CODE)*2+WORDS_START
	lds ZZH, (_CP-START_CODE)*2+WORDS_START+1


	subi ZZL, low(-1000)
	sbci ZZH, high(-1000)
	rcall ds_PUSH_ZZ
	rjmp NEXT
word:
	rcall trailing
	push XL
	push XH



	lds sourceL, (TIB-START_CODE)*2+WORDS_START
	lds sourceH, (TIB-START_CODE)*2+WORDS_START+1


	lds countL, (_IN-START_CODE)*2+WORDS_START
	lds countH, (_IN-START_CODE)*2+WORDS_START+1


	lds tempL, (CTIB-START_CODE)*2+WORDS_START
	lds tempH, (CTIB-START_CODE)*2+WORDS_START+1

	add tempL, sourceL
	adc tempH, sourceH

	movw ZL, sourceL
	add ZL, countL
	adc ZH, countH

	movw XL, destL
	adiw XL, 1

	check_if_line_ended_word:
		cp ZL, tempL
		 ;brne is_current_char_space_word
		cpc ZH, tempH
		 brne is_current_char_space_word
		; oh no! line ended!
		rjmp finish_word
	is_current_char_space_word:
		ld temp, Z+
	  	cpi temp, 32
		 breq endd
	  	cpi temp, 0
		 breq endd
		st X+, temp
		rjmp check_if_line_ended_word
	endd:
		; current char is not space!
		sbiw XL, 1
		sbiw ZL, 1
  finish_word:
	sub ZL, sourceL
	sbc ZH, sourceH
	movw countL, ZL
	sub XL, destL
	sbc XH, destH

	movw ZL, destL
	st Z+, XL

	ldi ZL, low((_IN - START_CODE)*2 + WORDS_START)
	ldi ZH, high((_IN - START_CODE)*2 + WORDS_START)
	st Z+, countL
	st Z+, countH
	pop XH
	pop XL
	ret

interpret:
	rcall trailing



	lds countL, (_IN-START_CODE)*2+WORDS_START
	lds countH, (_IN-START_CODE)*2+WORDS_START+1


	lds tempL, (CTIB-START_CODE)*2+WORDS_START
	lds tempH, (CTIB-START_CODE)*2+WORDS_START+1

	cp tempL, countL
	 brne noteol
	cp tempH, countH
	 brne noteol

	;rcall USART_SendACK
	rjmp UART_WAIT ; EOL, wait for input!
    looop:
		ldi temp, 0xFF
		sts LEDs, temp
		rjmp looop ; EOL!!!

   noteol:


	lds destL, (_CP-START_CODE)*2+WORDS_START
	lds destH, (_CP-START_CODE)*2+WORDS_START+1
	movw tempL, destL


	subi tempL, low(-200)
	sbci tempH, high(-200)
	movw destL, tempL
    rcall word

	push XH
	push XL
		rcall find
	pop XL
	pop XH

	rcall ds_POP_ZZ
	;rjmp intepret_execute

	movw ZL, ZZL
	sbiw ZL, 3
	ld temp, Z
	andi temp, 0x80
	cpi temp, 0
	  brne intepret_execute

	ldi ZL, low((STATE - START_CODE)*2 + WORDS_START)
	ldi ZH, high((STATE - START_CODE)*2 + WORDS_START)
	ld temp, Z
	cpi temp, 0
	  breq intepret_execute

interpret_compile:
	rcall ds_PUSH_ZZ
	ldi ZZL, low((mem_COMMA - START_CODE)*2 + WORDS_START)
	ldi ZZH, high((mem_COMMA - START_CODE)*2 + WORDS_START)

intepret_execute:
	; EXECUTE
	ldi XL, low((mmRET - START_CODE)*2 + WORDS_START)
	ldi XH, high((mmRET - START_CODE)*2 + WORDS_START)
	movw YL, ZZL
	ld ZL, Y+
	ld ZH, Y+
	ijmp

gethere:
	rjmp interpret


;source, dest (LINK)
compare:
	movw XL, sourceL
	movw ZL, destL
	ld temp2, X
	inc temp2
	compare_each:
		ld tempL, X+
		ld tempH, -Z
		andi tempH, 0b01111111
		cp tempL, tempH
		  brne notequal
		dec temp2
		cpi temp2, 0
		 breq equal
	rjmp compare_each


find:
	lds ZL, (LATEST - START_CODE)*2 + WORDS_START
	lds ZH, (LATEST - START_CODE)*2 + WORDS_START+1
	lds sourceL, (_CP - START_CODE)*2 + WORDS_START
	lds sourceH, (_CP - START_CODE)*2 + WORDS_START+1
	movw tempL, sourceL


	subi tempL, low(-200)
	sbci tempH, high(-200)
	movw sourceL, tempL
	cycle:
		movw ZZL, ZL
		ld temp2H, -Z
		ld temp2L, -Z
		movw destL, ZL
		rjmp compare
	equal:
		; ZZL - CFA of found word
		rcall ds_PUSH_ZZ
		ret
	notequal:
		cpi temp2L, 0
		 brne continue
		cp temp2L, temp2H
		 brne continue
		rjmp notfound
	continue:
		movw ZL, temp2L
		rjmp cycle
		ret


notfound:
		ldi temp, 0x82
		sts LEDs, temp
		rjmp notfound






itc_NUMBER:


	lds tempL, (BASE-START_CODE)*2+WORDS_START
	lds tempH, (BASE-START_CODE)*2+WORDS_START+1
	clr destL ; result
	clr destH
	ldi temp2L, 1
	clr temp2H
	rcall ds_POP_ZZ
	movw ZL, ZZL
	ld countL, Z+
	clr countH
	add ZL, countL
	adc ZH, countH
	  parse_LOOP:
		ld temp, -Z
		subi temp, 0x30
		cpi temp, 10
		 brge maybe_alphabet
		rjmp operatio
		 maybe_alphabet:
		  subi temp, 7
		operatio:
		cpi temp, 0
		 brlt number_error
		cp temp, tempL
		 brge number_error

		; dest += temp * temp2 (8bit*16bit)
			push temp2L
			push temp2H
			mul temp2L, temp ; Multiply LSB
			mov ZZL, R0 ; copy result to result register
			mov ZZH, R1
			mul temp2H, temp ; Multiply MSB
			add ZZH, R0 ; add LSB result to result byte 2
			add destL, ZZL
			adc destH, ZZH
			pop temp2H
			pop temp2L

		; temp2 = temp2 * tempL (16bit*8bit)
			mul temp2L, tempL ; Multiply LSB
			mov ZZL, R0 ; copy result to result register
			mov ZZH, R1
			mul temp2H, tempL ; Multiply MSB
			add ZZH, R0 ; add LSB result to result byte 2
			movw temp2L, ZZL
		inc countH
		cpse countL, countH
	  rjmp parse_LOOP
	movw ZZL, destL
	rcall ds_PUSH_ZZ
	rjmp NEXT

number_error:
	rjmp notfound
