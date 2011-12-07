#include <avr/interrupt.h>
#include <util/delay.h>
#include "bitdef.h"

unsigned char *lefti    =(unsigned char *)0xA000;	
unsigned char *righti   =(unsigned char *)0xA001;	
unsigned char *dotsi    =(unsigned char *)0xA004;	
unsigned char *LED_REG  =(unsigned char *)0xA006;
// Ports
unsigned char *pA       =(unsigned char *)0x8000;
unsigned char *pB       =(unsigned char *)0x8001;
unsigned char *pC       =(unsigned char *)0x8002;
// DAC REGISTER
unsigned char *DAC_REG  =(unsigned char *)0xF000;
// KEYBOARD
unsigned char *kbd0     =(unsigned char *)0x9006;
unsigned char *kbd1     =(unsigned char *)0x9005;
unsigned char *kbd2     =(unsigned char *)0x9003;
// keyboard keycodes
unsigned char KEY_CODES[] = {1,4,7,10, 2,5,8,0, 3,6,9,11, 12};

// digits for 7-segment indicator
unsigned char DEC_2_7SEG[] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x40};

// digits for 7-segment indicator
unsigned char MOTTO[] = {0x00, 0x00, 0x00, 0x00, 0x00,
                         0x1F, 0x24, 0x44, 0x44, 0x7F, 0x00,
                         0x78, 0x05, 0x05, 0x05, 0x7E, 0x00,
                         0x40, 0x40, 0x7F, 0x40, 0x40, 0x00,
                         0x3E, 0x41, 0x41, 0x41, 0x22, 0x00,
                         0x00, 0x00, 0x00, 0x00, 0x00};

// counter & delta
unsigned char counter = 2;
unsigned char delta  = 1;

void hardware_init()
{
    DDRB = _11000000;
    MCUCR = _11000000;		// ext. RAM enable
    
    // Enable external interrupts 0, 1
    GICR |= (1 << INT0) | (1 << INT1);
    sei();
    
    *pA = 0x00;
    *pB = 0;
    *pC = 0xFF;
    *LED_REG = 0;
    *dotsi = _00000000;
}

void dyn_display_digit(unsigned char digit){
    unsigned char pos = 3;
    unsigned char mod_res;

    do{
        mod_res = digit % 10;
        *pC = pos--;
        *pB = DEC_2_7SEG[mod_res];
        _delay_ms(20);
        digit = digit / 10;
    } while (digit);
    
    *pB = 0;
}

void matrix_display(unsigned char start){
    unsigned char pos = _00100000;
    do {
        pos = (pos >> 1);
        *pA = pos;
        *pC = ~MOTTO[start++];
        _delay_ms(10);
        *pA = 0;
    } while (pos);

    *pA = 0;
}

unsigned char scan_keyboard(){
    unsigned char keycounter;
    unsigned int kbdstate;

   	kbdstate  = (~(*kbd0) & _00001111); 			// read column 0
   	kbdstate |= (~(*kbd1) & _00001111) << 4;		// read column 1
   	kbdstate |= (~(*kbd2) & _00001111) << 8;		// read column 2
   	 
   	for (keycounter=0;keycounter<12;keycounter++) {	// keyboard state processing
   	  if (kbdstate & 1) break;				// if LSB = 1 then break
   	  kbdstate = kbdstate >> 1;				// shift kbdstate to right 
   	}

    return KEY_CODES[keycounter];
}

SIGNAL(SIG_INTERRUPT0){
    counter += delta;
}

SIGNAL(SIG_INTERRUPT1){
    counter -= delta;
}

int main () {
    
    hardware_init();

    unsigned char dir = 0xFF;
    unsigned char ledstate = _00000001;

    unsigned char key;
    unsigned char previous_key = 12;
    unsigned char mode = 0xFF;

    unsigned char matrix_position = 0;
    
    for (;;){

        key = scan_keyboard();         

        switch (key) {
            case 10: 
                counter = 0;
                break;
            case 11:
                if (key != previous_key) {
                    mode = ~mode;
                }
                break;
            default:
                if (key < 10){
                    delta = key;
                } 
        };
        previous_key = key;
        
        if (mode){
            dyn_display_digit(counter);
            _delay_ms(10);
        } else {
            matrix_display(matrix_position++);
            _delay_ms(10);

            if (matrix_position == 29) matrix_position = 0;
        }

    	*righti = delta;

        *LED_REG = ledstate;
        *DAC_REG = ~ledstate;    
        _delay_ms(10);

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

    return 0;
}
