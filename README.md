Pi Forth Bare Metal

This project is formed of two existing projects.

https://github.com/organix/pijFORTHos

and 

https://github.com/rsta2/uspi

So my very great thanks for all their hard work.

It is far from complete at present.
Working:
Keyboard input 
Screen output
To be done:
improve keyboard code
improve Screen code
add method of loading and saving forth files
everything else

Build instructions
On linux with a working GCC cross compiler
	$ make

Note on a raspberry, or other systems you may need to change the PREFIX in the makefile

Installing
The ready build *kernel.img* image file is in the top directory.
Copy it on a SD(HC) card along with the firmware files
	bootcode.bin
	fixup.dat
	start.elf
which can be got from https://github.com/raspberrypi/firmware/tree/master/boot.
Put the SD(HC) card into your Raspberry Pi and start it.

Note the original pijFortos used a serial port and I have left that working. This allows loading and saving forth files via copy and paste to a serial terminal on a PC.
Connect at 9600 8N1

Note the forth is now very slow - PLEASE FIX - I find I can download code files to it only if I set a delay between lines. This is an advanced option in Gnome serial terminal.

