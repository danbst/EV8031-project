#include <avr/io.h>
#include <stdlib.h>
#include <string.h>
#include <avr/pgmspace.h>
//#include <avr/signal.h>
#include <avr/interrupt.h>
#include <avr/wdt.h>
#include <avr/eeprom.h>
#include "bitdef.h"

unsigned char *lefti=(unsigned char *)0xa000;	
unsigned char *righti=(unsigned char *)0xa001;	
unsigned char *dotsi=(unsigned char *)0xA004;	
unsigned char *LED_REG=(unsigned char *)0xa006;
unsigned char *pA=(unsigned char *)0x8000;
unsigned char *pB=(unsigned char *)0x8001;
unsigned char *pC=(unsigned char *)0x8002;
// KEYBOARD
unsigned char *kbc0=(unsigned char *)0x9006;
unsigned char *kbc1=(unsigned char *)0x9005;
unsigned char *kbc2=(unsigned char *)0x9003;
// LED MATRIX
unsigned char *mrow=(unsigned char *)0x8002;
unsigned char *mcol=(unsigned char *)0x8000;
// DISPLAY CONTENT
unsigned char *DSP_REG=(unsigned char *)0x8001;
// DAC REGISTER
unsigned char *DAC_REG=(unsigned char *)0xF001;

unsigned char KEY_CODES[] = {1,4,7,10, 2,5,8,0, 3,6,9,11, 12};

volatile unsigned int delay_msec,need_zoom=500;

#include "delays.c"

SIGNAL(SIG_OUTPUT_COMPARE1A)
{
  PORTB ^= _10000000;					// debug output
  if (delay_msec) delay_msec--;				// delay counter
  if (need_zoom) { need_zoom--; PORTB ^= _01000000; }	// zoom processing
}

void hardware_init()
{
  DDRB = _11000000;
  MCUCR = _11000000;		// ext. RAM enable


  OCR1A = 114;			// period ~1ms
  TCCR1B = _00001011;		// CTC1, PS=64
  TIMSK |= (1 << OCIE1A);	// OCIE1A interrupt enable
  sei();

  *pA = 0x00;
  *pB = 0;
  *pC = 0xff;

  *LED_REG = 0;
  *dotsi = _00000011;
}

int main ()
{
    unsigned char keycounter;
    unsigned int kbdstate;
    unsigned char ledstate = _00000001;
    unsigned char dir = _11111111;

    unsigned char dac = _00000001;
    
    hardware_init();

    while (1){

    	kbdstate  = (~(*kbc0) & _00001111); 			// read column 0
    	kbdstate |= (~(*kbc1) & _00001111) << 4;		// read column 1
    	kbdstate |= (~(*kbc2) & _00001111) << 8;		// read column 2
    	 
    	for (keycounter=0;keycounter<12;keycounter++) {	// keyboard state processing
    	  if (kbdstate & 1) break;				// if LSB = 1 then break
    	  kbdstate = kbdstate >> 1;				// shift kbdstate to right 
    	}
    	
    	*righti = keycounter;	// show keycounter in hex-code on right part of 7segment indicator
    	      		// if key not pressed => 0x0c
    	*lefti = KEY_CODES[keycounter];

    	delay(100);
    
        *mrow = ledstate;//_10101010;
        *mcol = _11111111;

    	*LED_REG = ledstate;
        *DAC_REG = ~ledstate;
        *DSP_REG = _11111111;

        if (dir)
        {
            ledstate = (ledstate << 1);
        } else {
            ledstate = (ledstate >> 1);
        }

        if (ledstate == _10000000 || ledstate == _00000001){
            dir = ~dir;
        }

    }

}
