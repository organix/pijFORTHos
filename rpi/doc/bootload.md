# _pijFORTHos_ Boot Process

As with any kernel on the RPi,
_pijFORTHos_ boots from an SD card
in the built-in SD card slot.
Basic instructions for preparing your SD card
are on the [home page](/README.md).
A more detailed description of the RPi boot process
is available on the [elinux.org wiki](http://elinux.org/RPi_Software#Overview).

## Memory Organization

The _pijFORTHos_ kernel starts at 0x00008000 on the RPi.
The FORTH data stack starts right before the kernel,
and grows toward lower memory addresses.
The FORTH return stack occupies the first 1k
of the uninitialized memory section.
User memory (where new FORTH word definitions are stored)
occupies the next 16k of uninitialized memory.
Built-in words do not consume any user memory.
They are provided in a pre-initialized data section,
forming the base of the dictionary.
The PAD and line-editing buffers reside past the end of user memory.
The entire run-time image for _pijFORTHos_ is less than 32k.

~~~
0x00000000  +----------------+
0x00001000  | v e c t o r s  |     | data stack       ^ |
0x00002000  |                |     +--------------------+ 0x00008000 .text
0x00003000  |                |    /| kernel code        |
0x00004000  |                |   / |                    |
0x00005000  |                |  /  +--------------------+ 0x00009960 .rodata
0x00006000  |                | /   | built-in words     |
0x00007000  | s t a c k   ^  |/    |         ...strings |
0x00008000  +----------------+     +--------------------+ 0x0000A580 .data
0x00009000  |                |     +--------------------+ 0x0000A5E0 .bss
0x0000A000  | k e r n e l    |     | return stack (1k)  |
0x0000B000  |                |     | user memory (16k)  | 0x0000A9E0 HERE
0x0000C000  |                |     |                    |
0x0000D000  |                |     |                    |
0x0000E000  |                |     |                    |
0x0000F000  |                |     |                    |
0x00010000  +----------------+     |                    |
0x00011000  |                |\    |                    |
0x00012000  | u p l o a d    | \   |                    |
0x00013000  |                |  \  +--------------------+ 0x0000E9E0 PAD
0x00014000  | b u f f e r    |   \ | scratch-pad (128b) |
0x00015000  |                |    \| linebuf (256b) ... |
0x00016000  |                |     +--------------------+ 0x00010000
0x00017000  |                |     | upload buffer...   |
0x00018000  +----------------+
~~~

### Bootloader

The bootloader has two main components.
An [XMODEM](http://en.wikipedia.org/wiki/XMODEM) file transfer routine
and automatic kernel relocation code.
The relocation code allows a new kernel image
to be uploaded at a different address
than where it is expected to finally run.

On the RPi, the kernel wants to execute starting at 0x00008000.
We can't upload to that address, of course,
because that's where the **current** kernel is running!
Instead, we upload to a buffer at 0x00010000
and start running the new kernel at that address.
The first bit of code executed is position independent.
It checks where it's running,
and if it's not at 0x00008000 it copies itself there.
When the relocation code finishes,
it re-boots itself by jumping to the place
where it was just copied.
This time, it will find that it's running at the right address
and can proceed normally to the kernel entry point.

In order for this scheme to work,
we have to ensure two things.
First, the kernel image must by smaller than (32k - 256) bytes,
to fit between 0x00008000 and 0x10000000.
Second, each kernel image must begin with this automatic-relocation code:
~~~
@ _start is the bootstrap entry point
        .text
        .align 2
        .global _start
_start:
        sub     r1, pc, #8      @ Where are we?
        mov     sp, r1          @ Bootstrap stack immediately before _start
        ldr     lr, =halt       @ Halt on "return"
        ldr     r0, =0x8000     @ Absolute address of kernel memory
        cmp     r0, r1          @ Are we loaded where we expect to be?
        beq     k_start         @ Then, jump to kernel entry-point
        mov     lr, r0          @ Otherwise, relocate ourselves
        ldr     r2, =0x7F00     @ Copy (32k - 256) bytes
1:      ldmia   r1!, {r3-r10}   @ Read 8 words
        stmia   r0!, {r3-r10}   @ Write 8 words
        subs    r2, #32         @ Decrement len
        bgt     1b              @ More to copy?
        bx      lr              @ Jump to bootstrap entry-point
halt:
        b       halt            @ Full stop
~~~

From FORTH you can UPLOAD a new kernel image and BOOT it.

    UPLOAD   \ initiate XMODEM file transfer
    BOOT     \ jump to upload buffer address

If the UPLOAD fails it reports a length of 0
and BOOT will print an error message.
