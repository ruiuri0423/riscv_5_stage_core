#!/bin/bash

FILE=$1

if [ -f $FILE.o ]; then
  echo “Remove $FILE.o“
  rm -f $FILE.o
fi

if [ -f $FILE.elf ]; then
  echo “Remove $FILE.elf“
  rm -f $FILE.elf
fi

if [ -f $FILE.bin ]; then
  echo “Remove $FILE.bin and $FILE.hex”
  rm -f $FILE.bin $FILE.hex
fi

riscv32-unknown-elf-as $FILE.S -o $FILE.o
riscv32-unknown-elf-ld -o $FILE.elf -T sections.ld $FILE.o
riscv32-unknown-elf-objcopy -O binary $FILE.elf $FILE.bin 
python3 ./makehex.py $FILE.bin 2048 > $FILE.hex

# generate assembly code by compiler
riscv32-unknown-elf-objdump -d $FILE.elf > $FILE.asm