#
# Makefile for SDlib
#

PREFIX  = arm-none-eabi-
CC      = $(PREFIX)gcc
LD      = $(PREFIX)ld
AS      = $(PREFIX)as
AR      = $(PREFIX)ar
CP      = $(PREFIX)objcopy
OD      = $(PREFIX)objdump

# The name of the output file to generate.
LIBNAME ?= SDlib.a

CFLAGS  = -g -Wall -O2 -std=c99 -march=armv6 -mtune=arm1176jzf-s -nostdlib -nostartfiles -ffreestanding -I ./

SDOBJS  = emmc.o printf.o mmio.o emmc_timer.o mbox.o mbr.o libfs.o fat.o block.o vfs.o file_open.o helper.o

all: $(LIBNAME)

	
helper.o: helper.s 
	$(AS) helper.s -o helper.o

$(LIBNAME) :  $(SDOBJS)
	$(AR) rc $(LIBNAME) $(SDOBJS)

.c.o:
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o
	rm -f *.list
