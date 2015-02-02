#
# Makefile for pijFORTHos -- Raspberry Pi JonesFORTH Operating System
#
PREFIX  = arm-none-eabi-
CC      = $(PREFIX)gcc
LD      = $(PREFIX)ld -v
AS      = $(PREFIX)as
CP      = $(PREFIX)objcopy
OD      = $(PREFIX)objdump

CFLAGS  = -g -Wall -O2 -nostdlib -nostartfiles -ffreestanding


KOBJS=	start.o jonesforth.o raspberry.o timer.o serial.o xmodem.o frameBuffer.o

all: kernel.img

start.o: start.s
	$(AS) start.s -o start.o

jonesforth.o: jonesforth.s
	$(AS) jonesforth.s -o jonesforth.o
	
frameBuffer.o: frameBuffer.s font.bin
	$(AS) frameBuffer.s -o frameBuffer.o

#raspberry.o: raspberry.c
#	$(CC) $(CFLAGS)-c raspberry.c -o raspberry.o

kernel.img: loadmap $(KOBJS)
	$(LD) $(KOBJS) -T loadmap -o pijFORTHos.elf
	$(OD) -D pijFORTHos.elf > pijFORTHos.list
	$(CP) pijFORTHos.elf -O ihex pijFORTHos.hex
	$(CP) --only-keep-debug pijFORTHos.elf kernel.sym
	$(CP) pijFORTHos.elf -O binary kernel.img

.c.o:
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o
	rm -f *.hex
	rm -f *.elf
	rm -f *.list
	rm -f *.sym
	rm -f *~ core
