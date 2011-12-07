#define nop()  asm volatile ("nop" ::)
void delay16(n) { unsigned int i=n; do { nop(); } while(--i); }

void delay (unsigned int msec)
{
  
  cli(); delay_msec = msec; sei();
  do {
    cli(); msec = delay_msec; sei();
  } while (msec);
}
