.include "m8515def.inc"

; Register definitions.
.def	temp = r16
.def	int0_counter = r17
.def	int1_counter = r18

; Constants.
.equ	INIT_LED_MASK = 0x01

.dseg

; Variables.
counter:	.byte	1				; simple counter
led_mask:	.byte	1					

; Acccess to the some devices on board is implemented through read/write 
; from/to the external RAM. Of course we have to enable it at the program 
; start. For device addresses consult the board's documentation.

; Here we place some fake variables which in fact are the ports to 
; acccess the board's peripherals.
.org	0xA006
led_reg:	.byte	1				; LEDs

.org	0xA000
left_ind:	.byte	1				; left static 7-segment LED indicator
right_ind:	.byte	1				; right static 7-segment LED indicator

.cseg

.org	0x0000
reset:
	rjmp		reset_handler

.org	INT0addr
	rjmp		int0_handler

.org	INT1addr
	rjmp		int1_handler

main:
; Stack initialization.
	ldi		temp, low(RAMEND)
	out		SPL, temp
	ldi		temp, high(RAMEND)
	out		SPH, temp

; Variables initialization.
	clr		temp
	clr		int0_counter
	clr		int1_counter
	sts		counter, temp			; counter = 0

	ldi		temp, INIT_LED_MASK
	sts		led_mask, temp			; led_mask = INIT_LED_MASK

endless_loop:
		
	;lds		temp, counter
	ldi		XL, low(left_ind)
	ldi		XH, high(left_ind)		
	st		X+, int0_counter				; left_ind = counter
	st		X, int0_counter					; right_ind = counter
	
	;inc		temp					; counter++
	sts		counter, temp	

	lds		temp, led_mask
	ldi		XL, low(led_reg)		
	ldi		XH, high(led_reg)
	st		X, temp					; led_reg = led_mask

	lsl		temp					; led_mask = led_mask << 1;

	tst		temp					
	brbc		1, next_iter			; if (led_mask != 0) goto next_iter

	ldi		temp, INIT_LED_MASK		; led_mask = INIT_LED_MASK
next_iter:

	sts		led_mask, temp

; Some delay.
	ldi		temp, 0x00

endless_loop_delay_loop:	

	rcall		delay
	rcall		delay
	rcall		delay

	dec		temp
	brne		endless_loop_delay_loop

; Repeat once again.
	rjmp		endless_loop	

; Simple and stupid delay function.
delay:
	push		temp

	ldi		temp, 0x00

delay_loop:
	dec		temp
	brne		delay_loop

	pop		temp

	ret

reset_handler:
; Enable external RAM.
	ldi		temp, 0xCF	
	out		MCUCR, temp
	ldi		temp, 0xF0
	out		GICR, temp
;	sei
	ldi		temp, 0x80
	out		SREG,  temp
; Jump to the 'main' function.
	rjmp		main

int0_handler:
	inc		int0_counter
	reti

int1_handler:
	;inc		int1_counter
	dec		int0_counter
	reti

