@@
@@ pijFORTHos -- Raspberry Pi JonesFORTH Operating System
@@
@@ This code is loaded at 0x00008000 on the Raspberry Pi ARM processor
@@ and is the first code that runs to boot the O/S kernel.
@@
@@ View this file with hard tabs every 8 positions.
@@	|	|	.	|	.	.	.	.  max width ->
@@      |       |       .       |       .       .       .       .  max width ->
@@ If your tabs are set correctly, the lines above should be aligned.
@@

#include "uspienv/sysconfig.h"


@ _start is the bootstrap entry point
	.text
	.align 2
	.global _start
_start:
	cps	#0x1F				/* set system mode */
	mov	sp, #MEM_KERNEL_STACK
	b	sysinit


@@
@@ Provide a few assembly-language helpers used by C code, e.g.: raspberry.c
@@
	.text
	.align 2

	.globl NO_OP
NO_OP:			@ void NO_OP();
	bx	lr

	.globl PUT_32
PUT_32:			@ void PUT_32(u32 addr, u32 data);
	str	r1, [r0]
	bx	lr

	.globl GET_32
GET_32:			@ u32 GET_32(u32 addr);
	ldr	r0, [r0]
	bx	lr

	.globl BRANCH_TO
BRANCH_TO:		@ void BRANCH_TO(u32 addr);
	bx	r0

	.globl SPIN
SPIN:			@ void SPIN(u32 count);
	subs	r0, #1		@ decrement count
	bge	SPIN		@ until negative
	bx	lr
	
@ for emmc.c	
.globl memory_barrier
memory_barrier:
	mov	r0, #0
	mcr	p15, #0, r0, c7, c10, #5
	mov	pc, lr
