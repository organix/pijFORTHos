#
# Makefile for pijFORTHos -- Raspberry Pi JonesFORTH Operating System
#

AS=	$(CROSS) as
CC=	$(CROSS) gcc -g

KOBJS=	support.o jonesforth.o
TARGET = lnxforth

all: lnxforth

lnxforth: $(KOBJS)
	$(CC) $(KOBJS) -o $@

jonesforth.o: ../jonesforth-aarch64.s
	$(AS) -o $@ $<
.c.o:
	$(CC) -c $<

clean:
	rm -f *.o
	rm -f $(TARGET)
	rm -f *~ core
