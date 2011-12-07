cls
@c:\winavr\bin\avr-gcc -Wall -O2 -mmcu=atmega8515 -Wa,-ahlms=main.lst -Wl,-Map=main.map -funsigned-char main.c -o main.elf
@c:\winavr\bin\avr-objcopy -O ihex main.elf main.hex
@c:\winavr\bin\avr-objcopy -O ihex --only-section=".eeprom" --change-section-lma .eeprom=0 --set-section-flags=.eeprom=CONTENTS,ALLOC,LOAD main.elf main.eep
@c:\winavr\bin\avr-size main.elf
@pause
