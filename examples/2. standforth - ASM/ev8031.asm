.org 0x8000
	PA_REG:	.byte 1
	PB_REG:	.byte 1
	PC_REG:	.byte 1
	TRIS:	.byte 1
	.equ TRISC = 2

.org 0x8004
	LCD_CMD:	.byte 1
	LCD_DATA:	.byte 1

.org 0x9000
	US_REG:	.byte 1
	.equ KL0 = 0
	.equ KL1 = 1
	.equ KL2 = 2
	.equ KL3 = 3
	.equ RI  = 4
	.equ DCD = 5
	.equ DSR = 6
	.equ CTS = 7

.org 0x9001
	UC_REG:	.byte 1
	.equ CFG0 = 0
	.equ CFG1 = 1
	.equ RTS = 2
	.equ DTR = 3

.org 0xA000
	INDICATOR:
	INDH:	.byte 1
	INDL:	.byte 1
			.byte 1
			.byte 1
	INDDP:	.byte 1
			.byte 1
	LEDs:	.byte 1

.org 0xA007
	SYS_CTL:	.byte 1

.org 0xB000
	DISPLAYB:	.byte 1

.org 0xF000
	DAC:		.byte 1
