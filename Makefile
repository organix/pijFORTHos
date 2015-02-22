#
# Makefile for pijFORTHos -- Raspberry Pi JonesFORTH Operating System
#
LIBRARIES := libuspi
PREFIX  = arm-none-eabi-
CC      = $(PREFIX)gcc
LD      = $(PREFIX)ld
AS      = $(PREFIX)as
CP      = $(PREFIX)objcopy
OD      = $(PREFIX)objdump

CFLAGS  = -g -Wall -O2 -std=c99 -march=armv6 -mtune=arm1176jzf-s -nostdlib -nostartfiles -ffreestanding -I ./

SDOBJS  = emmc.o printf.o mmio.o emmc_timer.o mbox.o 
KOBJS   = start.o sysinit.o jonesforth.o raspberry.o timer.o serial.o xmodem.o $(SDOBJS)
LIBS	= ./libuspi.a ./libuspienv.a

all: kernel.img

#start.o: start.S
#	$(AS) start.S -o start.o

jonesforth.o: jonesforth.s
	$(AS) jonesforth.s -o jonesforth.o
	
#frameBuffer.o: frameBuffer.s font.bin
#	$(AS) frameBuffer.s -o frameBuffer.o

kernel.img: loadmap $(KOBJS)
	$(LD) $(KOBJS) -T loadmap -o pijFORTHos.elf $(LIBS)
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
