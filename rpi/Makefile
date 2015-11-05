#
# Makefile for pijFORTHos -- Raspberry Pi JonesFORTH Operating System
#

AS=	$(CROSS)as
CC=	$(CROSS)gcc -g -Wall -O2 -nostdlib -nostartfiles -ffreestanding
LD=	$(CROSS)ld
OBJDUMP = $(CROSS)objdump
OBJCOPY = $(CROSS)objcopy

KOBJS=	start.o jonesforth.o raspberry.o timer.o serial.o xmodem.o

all: kernel.img

start.o: start.s
	$(AS) start.s -o start.o

jonesforth.o: ../jonesforth.s
	$(AS) -o $@ $<

kernel.img: loadmap $(KOBJS)
	$(LD) $(KOBJS) -T loadmap -o pijFORTHos.elf
	$(OBJDUMP) -D pijFORTHos.elf > pijFORTHos.list
	$(OBJCOPY) pijFORTHos.elf -O ihex pijFORTHos.hex
	$(OBJCOPY) --only-keep-debug pijFORTHos.elf kernel.sym
	$(OBJCOPY) pijFORTHos.elf -O binary kernel.img

.c.o:
	$(CC) -c $<

clean:
	rm -f *.o
	rm -f *.bin
	rm -f *.hex
	rm -f *.elf
	rm -f *.list
	rm -f *.img
	rm -f *~ core
