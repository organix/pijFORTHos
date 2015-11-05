# Raspberry Pi JonesFORTH O/S

A bare-metal operating system for Raspberry Pi,
based on [_Jonesforth-ARM_](https://github.com/M2IHP13-admin/JonesForth-arm).

_Jonesforth-ARM_ is an ARM port, by M2IHP'13 class members listed in `AUTHORS`, of _x86 JonesForth_.

_x86 JonesForth_ is a Linux-hosted FORTH presented in a Literate Programming style
by Richard W.M. Jones <rich@annexia.org> originally at <http://annexia.org/forth>.
Comments embedded in the original provide an excellent FORTH implementation tutorial.
See the `/annexia/` directory for a copy of this original source.

The algorithm for our unsigned DIVMOD instruction is extracted from 'ARM
Software Development Toolkit User Guide v2.50' published by ARM in 1997-1998

Firmware files to make bootable images are maintained at <https://github.com/raspberrypi/firmware>.
See the `/firmware/` directory for local copies used in the build process.


## What is this ?

_pijFORTHos_ is a bare-metal FORTH interpreter for the Raspberry Pi.
It follows the general strategy given by David Welch's
[excellent examples](https://github.com/dwelch67/raspberrypi).
A simple [bootloader](/doc/bootload.md#bootloader) is built in,
supporting XMODEM uploads of new bare-metal kernel images.

The interpreter uses the RPi serial console (115200 baud, 8 data bits, no parity, 1 stop bit).
If you have _pijFORTHos_ on an SD card in the RPi,
you can connect it to another machine (even another RPi)
using a [USB-to-Serial cable](http://www.adafruit.com/products/954).
When the RPi is powered on (I provide power through the cable),
a terminal program on the host machine allows access to the FORTH console.


## Build and run instructions

_**NOTE**: HEAD is in active development, for a stable version the latest release is recommended._

If you are building on the RPi, just type:

    $ make clean all

If you're cross-compiling, type:

    $ CROSS=arm-linux-gnueabi- clean all

...where CROSS corresponds to the ARM cross-compiler
toolchain you have installed.

If you can't compile (or cross-compile) from source,
you can use the pre-built `kernel.img` file.

Next, copy the firmware and kernel to a blank SD card, for example:

    $ cp firmware/* /media/<SD-card>/
    $ cp kernel.img /media/<SD-card>/

The end state for the SD card is to have a FAT32 filesystem on it with the following files:

    bootcode.bin
    start.elf
    kernel.img

Put the prepared SD card into the RPi,
connect the USB-to-Serial cable
(see [RPi Serial Connection](http://elinux.org/RPi_Serial_Connection) for more details),
and power-up to the console.

To get to the console, you'll need to connect. Here are two ways to try:

    $ minicom -b 115200 -o -D <device>

Where `<device>` is something like `/dev/ttyUSB0` or similar
(wherever you plugged in your USB-to-Serial cable).

Alternatively, if `minicom` is not working for you, try using `screen`:

    $ screen <device> 115200

Where `<device>` is, again, something like `/dev/ttyUSB0`.

The console will be waiting for an input, press `<ENTER>`. You should then see:

    pijFORTHos <version> sp=0x00008000


## Where to go from HERE ?

With FORTH REPL running, try typing:

    HEX 8000 DECIMAL 128 DUMP

You should see something like:

    00008000  08 10 4f e2 01 d0 a0 e1  80 e0 9f e5 02 09 a0 e3  |..O.............|
    00008010  01 00 50 e1 44 06 00 0a  00 e0 a0 e1 7f 2c a0 e3  |..P.D........,..|
    00008020  f8 07 b1 e8 f8 07 a0 e8  20 20 52 e2 fb ff ff ca  |........  R.....|
    00008030  1e ff 2f e1 fe ff ff ea  1e ff 2f e1 00 10 80 e5  |../......./.....|
    00008040  1e ff 2f e1 00 00 90 e5  1e ff 2f e1 b0 10 c0 e1  |../......./.....|
    00008050  1e ff 2f e1 b0 00 d0 e1  1e ff 2f e1 00 10 c0 e5  |../......./.....|
    00008060  1e ff 2f e1 00 00 d0 e5  1e ff 2f e1 0e 00 a0 e1  |../......./.....|
    00008070  1e ff 2f e1 10 ff 2f e1  ff 5f 2d e9 f8 07 b1 e8  |../.../.._-.....|

For something a little more interesting, try the [GPIO Morse Code](/doc/blinker.md) tutorial.

The [FORTH reference](/doc/forth.md) page describes the FORTH words available in _pijFORTHos_.

The [Bootloader](/doc/bootload.md) page describes the memory layout and boot process.

There is a persistent thread on the Rasberry Pi forums with a useful collection of
[bare-metal resources](http://www.raspberrypi.org/forums/viewtopic.php?f=72&t=72260),
including ARM CPU programming references and peripheral register descriptions.
