cls
@c:\winavr\bin\avr-gcc -Wall -O2 -mmcu=atmega8515 -Wa,-ahlms=demo.lst -Wl,-Map=demo.map -funsigned-char demo.c -o demo.elf
@c:\winavr\bin\avr-objcopy -O ihex demo.elf demo.hex
@c:\winavr\bin\avr-objcopy -O ihex --only-section=".eeprom" --change-section-lma .eeprom=0 --set-section-flags=.eeprom=CONTENTS,ALLOC,LOAD demo.elf demo.eep
@c:\winavr\bin\avr-size demo.elf
@pause
