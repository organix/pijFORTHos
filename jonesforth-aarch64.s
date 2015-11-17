/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// jonesforth-aarch64.s - a port of Jonesforth to AArch64
//
// Based on jonesforth-arm.s. Just a dumb conversion today. We can do better.
//
// Copyright (C) 2015 Andrei Warkentin <andrey.warkentin@gmail.com>	
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU Lesser General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option) any
// later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        .set JONES_VERSION,47

//
// Reserve three special registers. These are reserved out of the
// callee-saved registers, making interop with C a bit easier.	
// DSP (x19) points to the top of the data stack.
// RSP (x20) points to the top of the return stack
// FIP (x21) points to the next FORTH word that will be executed
//	
DSP     .req    x19
RSP     .req    x20
FIP     .req    x21
lr      .req    x30

//
// Temporary scratch storage (also out of callee-saved regs,
// to make C interop a bit easer.
//	
// SCRATCH0 (x22) is temporary storage
// SCRATCH1 (x23) is temporary storage
// SCRATCH2 (x24) is temporary storage
// SCRATCH3 (x25) is temporary storage
// SCRATCH4 (x26) is temporary storage
// SCRATCH5 (x27) is temporary storage
// SCRATCH6 (x28) is temporary storage
//
SCRATCH0 .req x22
SCRATCH1 .req x23
SCRATCH2 .req x24
SCRATCH3 .req x25
SCRATCH4 .req x26
SCRATCH5 .req x27
SCRATCH6 .req x28

// Define macros to push and pop from the data and return stacks

        .macro PUSHRSP reg
        str     \reg, [RSP, #-8]!
        .endm

        .macro POPRSP reg
        ldr     \reg, [RSP], #8
        .endm

        .macro PUSHDSP reg
        str     \reg, [DSP, #-8]!
        .endm

        .macro POPDSP reg
        ldr     \reg, [DSP], #8
        .endm

        .macro PUSH2 reg                // ( -- x1 x0 )
        str     x0, [\reg, #-8]!
        str     x1, [\reg, #-8]!
        .endm

        .macro POP2 reg                 // ( x1 x0 -- )
        ldr     x1, [\reg], #8
        ldr     x0, [\reg], #8
        .endm

        .macro PUSH3 reg                // ( -- x2 x1 x0 )
        str     x0, [\reg, #-8]!
        str     x1, [\reg, #-8]!
	str     x2, [\reg, #-8]!
        .endm

        .macro POP3 reg                 // ( x2 x1 x0 -- )
        ldr     x2, [\reg], #8
        ldr     x1, [\reg], #8
        ldr     x0, [\reg], #8
        .endm

	.macro PUSH4 reg                // ( -- x3 x2 x1 x0 )
        str     x0, [\reg, #-8]!
        str     x1, [\reg, #-8]!
	str     x2, [\reg, #-8]!
	str     x3, [\reg, #-8]!
        .endm

        .macro POP4 reg                 // ( x3 x2 x1 x0 -- )
        ldr     x3, [\reg], #8
        ldr     x2, [\reg], #8
        ldr     x1, [\reg], #8
        ldr     x0, [\reg], #8
        .endm

	.macro DSP_TO_SP_FOR_ABI_CALL
	mov SCRATCH0, DSP
	tst SCRATCH0, #0xF
	beq 1f
	sub SCRATCH0, SCRATCH0, #0x8
1:	mov sp, SCRATCH0
	.endm

// _NEXT is the assembly subroutine that is called
// at the end of every FORTH word execution.
// The NEXT macro is defined to simply call _NEXT
        .macro NEXT
        b _NEXT
        .endm

// jonesforth is the entry point for the FORTH environment
        .text
        .align 2                        // alignment 2^n (2^2 = 4 byte alignment)
        .global jonesforth
jonesforth:
        ldr x0, =var_S0
	mov DSP, sp
        str x1, [x0]                    // Save the original stack position in S0
        ldr RSP, =return_stack_top      // Set the initial return stack position
        ldr x0, =data_segment           // Get the initial data segment address
        ldr x1, =var_HERE               // Initialize HERE to point at
        str x0, [x1]                    //   the beginning of data segment
        ldr FIP, =cold_start            // Make the FIP point to cold_start
        NEXT                            // Start the interpreter

// _DOCOL is the assembly subroutine that is called
// at the start of every FORTH word execution, which:
//   0. expects the CFA of a FORTH word in x0
//   1. saves the old FIP on the return stack
//   2. makes FIP point to the DFA (first codeword)
//   3. uses _NEXT to start interpreting the word
_DOCOL:
        PUSHRSP FIP
        add FIP, x0, #8

// _NEXT is the assembly subroutine that is called
// at the end of every FORTH word execution, which:
//   1. finds the CFA of the FORTH word to execute
//      by dereferencing the FIP
//   2. increments FIP
//   3. begins executing the routine pointed to
//      by the CFA, with the CFA in x0
_NEXT:
// This is done like so that ASMNEXT doesn't need to
// be kept in sync with _NEXT definition.
	.macro NEXT_BODY, wrap_insn:vararg=
	\wrap_insn ldr x0, [FIP], #8
	\wrap_insn ldr x1, [x0]
	\wrap_insn br  x1
	.endm
	NEXT_BODY

// cold_start is used to bootstrap the interpreter, 
// the first word executed is QUIT
        .section .rodata
cold_start:
        .quad QUIT


//// Now we define a set of helper macros that are syntactic sugar
//// to ease the declaration of FORTH words, Native words, FORTH variables
//// and FORTH constants.

// define the word flags
        .set F_IMM, 0x80
        .set F_HID, 0x20
        .set F_LEN, 0x1f

// link is used to chain the words in the dictionary as they are defined
        .set link, 0

// defword macro helps defining new FORTH words in assembly
        .macro defword name, flags=0, label
        .section .rodata
        .align 3
        .global name_\label
name_\label :
        .quad link               // link
        .set link,name_\label
        .byte \flags+(str_end_\label-str_\label) // flags + length of "\name"
str_\label :
        .ascii "\name"          // the name
str_end_\label :
        .align 3                // padding to next 4 byte boundary
        .global \label
\label :
        .quad _DOCOL             // codeword - the interpreter
        // list of word pointers follow
        .endm

// defcode macro helps defining new native words in assembly
        .macro defcode name, flags=0, label
        .section .rodata
        .align 3
        .globl name_\label
name_\label :
        .quad link               // link
        .set link,name_\label
        .byte \flags+(str_end_\label-str_\label) // flags + length of "\name"
str_\label :
        .ascii "\name"          // the name
str_end_\label :
        .align 3                // padding to next 8 byte boundary
        .global \label
\label :
        .quad code_\label        // codeword
        .text
        .global code_\label
code_\label :                   // assembler code follows
        .endm

// EXIT is the last codeword of a FORTH word.
// It restores the FIP and returns to the caller using NEXT.
// (See _DOCOL)
defcode "EXIT",,EXIT
        POPRSP FIP
        NEXT


// defvar macro helps defining FORTH variables in assembly
        .macro defvar name, flags=0, label, initial=0
        defcode \name,\flags,\label
        ldr x0, =var_\name
        PUSHDSP x0
        NEXT
        .data
        .align 3
        .global var_\name
var_\name :
        .quad \initial
        .endm

// The built-in variables are:
//  STATE           Is the interpreter executing code (0) or compiling a word (non-zero)?
        defvar "STATE",,STATE
//  HERE            Points to the next free byte of memory.  When compiling, compiled words go here.
        defvar "HERE",,HERE
//  LATEST          Points to the latest (most recently defined) word in the dictionary.
        defvar "LATEST",,LATEST,name_EXECUTE  // The last word defined in assembly is EXECUTE
//  S0              Stores the address of the top of the parameter stack.
        defvar "S0",,S0
//  BASE            The current base for printing and reading numbers.
        defvar "BASE",,BASE,10


// defconst macro helps defining FORTH constants in assembly
        .macro defconst name, flags=0, label, value
        defcode \name,\flags,\label
        ldr x0, =\value
        PUSHDSP x0
        NEXT
        .endm

// The built-in constants are:
//  VERSION         Is the current version of this FORTH.
        defconst "VERSION",,VERSION,JONES_VERSION
//  R0              The address of the top of the return stack.
        defconst "R0",,R0,return_stack_top
//  DOCOL           Pointer to _DOCOL.
        defconst "DOCOL",,DOCOL,_DOCOL
//  PAD             Pointer to scratch-pad buffer.
        defconst "PAD",,PAD,scratch_pad
//  F_IMMED         The IMMEDIATE flag's actual value.
        defconst "F_IMMED",,F_IMMED,F_IMM
//  F_HIDDEN        The HIDDEN flag's actual value.
        defconst "F_HIDDEN",,F_HIDDEN,F_HID
//  F_LENMASK       The length mask in the flags/len byte.
        defconst "F_LENMASK",,F_LENMASK,F_LEN
//  FALSE           Boolean predicate False (0)
        defcode "FALSE",,FALSE
                mov x0, #0
                PUSHDSP x0
                NEXT
//  TRUE            Boolean predicate True (-1)
        defcode "TRUE",,TRUE
                mvn x0, xzr
                PUSHDSP x0
                NEXT


// DROP ( a -- ) drops the top element of the stack
defcode "DROP",,DROP
        add DSP, DSP, #8        // ( )
        NEXT

// DUP ( a -- a a ) duplicates the top element
defcode "DUP",,DUP
        ldr x0, [DSP]           // ( a ), x0 = a
        PUSHDSP x0              // ( a a ), x0 = a
        NEXT

// SWAP ( a b -- b a ) swaps the two top elements
defcode "SWAP",,SWAP
        POP2 DSP                // ( ), x1 = a, x0 = b
        PUSHDSP x0              // ( b ), x1 = a, x0 = b
        PUSHDSP x1              // ( b a ), x1 = a, x0 = b
        NEXT

// OVER ( a b -- a b a ) push copy of second element on top
defcode "OVER",,OVER
        ldr x0, [DSP, #8]       // ( a b ), x0 = a
        PUSHDSP x0              // ( a b a )
        NEXT

// ROT ( a b c -- b c a ) rotation
defcode "ROT",,ROT
        POPDSP x1               // ( a b ), x1 = c
        POPDSP x2               // ( a ), x2 = b
        POPDSP x0               // ( ), x0 = a
        PUSH3 DSP               // ( b c a ), x2 = b, x1 = c, x0 = a
        NEXT

// -ROT ( a b c -- c a b ) backwards rotation
defcode "-ROT",,NROT
        POP3 DSP                // ( ), x2 = a, x1 = b, x0 = c
        PUSHDSP x0              // ( c )
        PUSHDSP x2              // ( c a )
        PUSHDSP x1              // ( c a b )
        NEXT

// 2DROP ( a b -- ) drops the top two elements of the stack
defcode "2DROP",,TWODROP
        add DSP, DSP, #16       // ( )
        NEXT

// 2DUP ( a b -- a b a b ) duplicate top two elements of stack
// : 2DUP OVER OVER ;
defcode "2DUP",,TWODUP
	ldp   x1, x0, [DSP]     // ( a b ), x1 = a, x0 = b
        PUSH2 DSP               // ( a b a b ), x1 = a, x0 = b
        NEXT

// 2SWAP ( a b c d -- c d a b ) swap top two pairs of elements of stack
// : 2SWAP >R -ROT R> -ROT ;
defcode "2SWAP",,TWOSWAP
        POP4 DSP                // ( ), x3 = a, x2 = b, x1 = c, x0 = d
        PUSH2 DSP               // ( c d ), x3 = a, x2 = b, x1 = c, x0 = d
        PUSHDSP x3              // ( c d a ), x3 = a, x2 = b, x1 = c, x0 = d
        PUSHDSP x2              // ( c d a b ), x3 = a, x2 = b, x1 = c, x0 = d
        NEXT

// 2OVER ( a b c d -- a b c d a b ) copy second pair of stack elements
defcode "2OVER",,TWOOVER
        ldr x0, [DSP, #16]      // ( a b c d ), x0 = b
        ldr x1, [DSP, #24]      // ( a b c d ), x1 = a, x0 = b
        PUSH2 DSP               // ( a b c d a b ), x1 = a, x0 = b
        NEXT

// NIP ( a b -- b ) drop the second element of the stack
// : NIP SWAP DROP ;
defcode "NIP",,NIP
        POP2 DSP                // ( ), x1 = a, x0 = b
        PUSHDSP x0              // ( b ), x1 = a, x0 = b
        NEXT

// TUCK ( a b -- b a b ) push copy of top element below second
// : TUCK SWAP OVER ;
defcode "TUCK",,TUCK
        POP2 DSP                // ( ), x1 = a, x0 = b
        PUSHDSP x0              // ( b ), x1 = a, x0 = b
        PUSH2 DSP               // ( b a b ), x1 = a, x0 = b
        NEXT

// PICK ( a_n ... a_0 n -- a_n ... a_0 a_n ) copy n-th stack item
// : PICK 1+ 4* DSP@ + @ ;
defcode "PICK",,PICK
        POPDSP x0               // ( a_n ... a_0 ), x0 = n
        ldr x1, [DSP,x0,LSL #3] // ( a_n ... a_0 ), x0 = n, x1 = a_n
        PUSHDSP x1              // ( a_n ... a_0 a_n ), x0 = n, x1 = a_n
        NEXT

// ?DUP ( 0 -- 0 | a -- a a ) duplicates if non-zero
defcode "?DUP",,QDUP
        ldr x0, [DSP]           // x0 = a
        cbz x0, 1f
        str x0, [DSP, #-8]!     // copy if a!=0
1:	NEXT                    // ( a a | 0 )

// : 1+ ( n -- n+1 ) 1 + ;  \  increments the top element
defcode "1+",,INCR
        POPDSP x0
        add x0, x0, #1
        PUSHDSP x0
        NEXT

// : 1- ( n -- n-1 ) 1 - ;  \  decrements the top element
defcode "1-",,DECR
        POPDSP x0
        sub x0, x0, #1
        PUSHDSP x0
        NEXT

// : 2+ ( n -- n+2 ) 2 + ;  \  increments by 2 the top element
defcode "2+",,INCX2
        POPDSP x0
        add x0, x0, #2
        PUSHDSP x0
        NEXT

// : 2- ( n -- n-2 ) 2 - ;  \ decrements by 2 the top element
defcode "2-",,DECX2
        POPDSP x0
        sub x0, x0, #2
        PUSHDSP x0
        NEXT

// : 4+ ( n -- n+4 ) 4 + ;  \  increments by 4 the top element
defcode "4+",,INCX4
        POPDSP x0
        add x0, x0, #4
        PUSHDSP x0
        NEXT

// : 4- ( n -- n-4 ) 4 - ;  \ decrements by 4 the top element
defcode "4-",,DECX4
        POPDSP x0
        sub x0, x0, #4
        PUSHDSP x0
        NEXT

// + ( a b -- a+b )
defcode "+",,ADD
        POP2 DSP                // ( ), x1 = a, x0 = b
        add x0, x0, x1
        PUSHDSP x0
        NEXT

// - ( a b -- a-b )
defcode "-",,SUB
        POP2 DSP                // ( ), x1 = a, x0 = b
        sub x0, x1, x0
        PUSHDSP x0
        NEXT

// 2* ( a -- a*2 )
defcode "2*",,MUL2
        POPDSP x0
        lsl x0, x0, #1
        PUSHDSP x0
        NEXT

// 2/ ( a -- a/2 )
defcode "2/",,DIV2
        POPDSP x0
	asr x0, x0, #1
        PUSHDSP x0
        NEXT

// 4* ( a -- a*4 )
defcode "4*",,MUL4
        POPDSP x0
	lsl x0, x0, #2
        PUSHDSP x0
        NEXT

// 4/ ( a -- a/4 )
defcode "4/",,DIV4
        POPDSP x0
	asr x0, x0, #2
        PUSHDSP x0
        NEXT

// 8* ( a -- a*8 )
defcode "4*",,MUL8
        POPDSP x0
	lsl x0, x0, #3
        PUSHDSP x0
        NEXT

// 8/ ( a -- a/8 )
defcode "4/",,DIV8
        POPDSP x0
	asr x0, x0, #3
        PUSHDSP x0
        NEXT

// LSHIFT ( a b -- a<<b )
defcode "LSHIFT",,LSHIFT
        POP2 DSP                // ( ), x1 = a, x0 = b
	lsl x0, x1, x0
        PUSHDSP x0
        NEXT

// RSHIFT ( a b -- a>>b )
defcode "RSHIFT",,RSHIFT
        POP2 DSP                // ( ), x1 = a, x0 = b
	lsr x0, x1, x0
        PUSHDSP x0
        NEXT

// * ( a b -- a*b )
defcode "*",,MUL
        POP2 DSP                // ( ), x1 = a, x0 = b
        mul x2, x1, x0
        PUSHDSP x2
        NEXT

// / ( n m -- q ) integer division quotient (see /MOD)
// : / /MOD SWAP DROP ;
defcode "/",,DIV
        POPDSP  x1              // ( n ), x1 = m
        POPDSP  x0              // ( ), x0 = n, x1 = m
        udiv    x2, x0, x1
        PUSHDSP x2              // ( q ), x0 = r, x1 = m, x2 = q
        NEXT

// MOD ( n m -- r ) integer division remainder (see /MOD)
// : MOD /MOD DROP ;
defcode "MOD",,MOD
        POPDSP  x1              // ( n ), x1 = m
        POPDSP  x0              // ( ), x0 = n, x1 = m
        udiv    x2, x0, x1
	mul     x1, x2, x1
	sub     x0, x0, x1
        PUSHDSP x0              // ( r ), x0 = r, x1 = m, x2 = q
        NEXT

// NEGATE ( n -- -n ) integer negation
// : NEGATE 0 SWAP - ;
defcode "NEGATE",,NEGATE
        POPDSP x0
        neg x0, x0
        PUSHDSP x0
        NEXT

// = ( a b -- p ) where p is 1 when a and b are equal (0 otherwise)
defcode "=",,EQ
        POP2     DSP                // ( ), x1 = a, x0 = b
	cmp      x1, x0
	bne      1f
	mov      x0, #-1
	b        2f
1:	mov      x0, #0
2:	PUSHDSP  x0
        NEXT

// <> ( a b -- p ) where p = a <> b
defcode "<>",,NEQ
        POP2 DSP                // ( ), x1 = a, x0 = b
	cmp      x1, x0
	beq      1f
	mov      x0, #-1
	b        2f
1:	mov      x0, 0
2:	PUSHDSP  x0
        NEXT

// < ( a b -- p ) where p = a < b
defcode "<",,LT
        POP2 DSP                // ( ), x1 = a, x0 = b
	cmp      x1, x0
	bge      1f
	mov      x0, #-1
	b        2f
1:	mov      x0, #0
2:	PUSHDSP  x0
        NEXT

// > ( a b -- p ) where p = a > b
defcode ">",,GT
        POP2 DSP                // ( ), x1 = a, x0 = b
	cmp      x1, x0
	ble      1f
	mov      x0, #-1
	b        2f
1:	mov      x0, #0
2:	PUSHDSP  x0
        NEXT

// <= ( a b -- p ) where p = a <= b
defcode "<=",,LE
        POP2 DSP                // ( ), x1 = a, x0 = b
	cmp      x1, x0
	bgt      1f
	mov      x0, #-1
	b        2f
1:	mov      x0, #0
2:	PUSHDSP  x0
        NEXT

// >= ( a b -- p ) where p = a >= b
defcode ">=",,GE
        POP2 DSP                // ( ), x1 = a, x0 = b
	cmp      x1, x0
	blt      1f
	mov      x0, #-1
	b        2f
1:	mov      x0, #0
2:	PUSHDSP  x0
        NEXT

// : 0= 0 = ;
defcode "0=",,ZEQ
        POPDSP  x0
	cmp     x0, xzr
	bne     1f
	mov     x0, #-1
	b       2f
1:	mov     x0, #0
2:	PUSHDSP x0
        NEXT

// : 0<> 0 <> ;
defcode "0<>",,ZNEQ
        POPDSP  x0
	cmp     x0, xzr
	beq     1f
	mov     x0, #-1
	b       2f
1:	mov     x0, #0
2:	PUSHDSP x0
	NEXT

// : 0< 0 < ;
defcode "0<",,ZLT
        POPDSP  x0
	cmp     x0, xzr
	bge     1f
	mov     x0, #-1
	b       2f
1:	mov     x0, #0
2:	PUSHDSP x0
	NEXT

// : 0> 0 > ;
defcode "0>",,ZGT
        POPDSP  x0
	cmp     x0, xzr
	ble     1f
	mov     x0, #-1
	b       2f
1:	mov     x0, #0
2:	PUSHDSP x0
	NEXT

// : 0<= 0 <= ;
defcode "0<=",,ZLE
        POPDSP  x0
	cmp     x0, xzr
	bgt     1f
	mov     x0, #-1
	b       2f
1:	mov     x0, #0
2:	PUSHDSP x0
	NEXT

// : 0>= 0 >= ;
defcode "0>=",,ZGE
        POPDSP  x0
	cmp     x0, xzr
	blt     1f
	mov     x0, #-1
	b       2f
1:	mov     x0, #0
2:	PUSHDSP x0
	NEXT

// : NOT 0= ;
defcode "NOT",,NOT
        b code_ZEQ              // same at 0=

// AND ( a b -- a&b ) bitwise and
defcode "AND",,AND
        POP2 DSP                // ( ), x1 = a, x0 = b
        and x0, x1, x0
        PUSHDSP x0
        NEXT

// OR ( a b -- a|b ) bitwise or
defcode "OR",,OR
        POP2 DSP                // ( ), x1 = a, x0 = b
        orr x0, x1, x0
        PUSHDSP x0
        NEXT

// XOR ( a b -- a^b ) bitwise xor
defcode "XOR",,XOR
        POP2 DSP                // ( ), x1 = a, x0 = b
        eor x0, x1, x0
        PUSHDSP x0
        NEXT

// INVERT ( a -- ~a ) bitwise not
defcode "INVERT",,INVERT
        POPDSP x0
        mvn x0, x0
        PUSHDSP x0
        NEXT


// LIT is used to compile literals in FORTH word.
// When LIT is executed it pushes the literal (which is the next codeword)
// into the stack and skips it (since the literal is not executable).
defcode "LIT",, LIT
        ldr x1, [FIP], #8
        PUSHDSP x1
        NEXT

// ! ( value address -- ) write value at address
defcode "!",,STORE
        POP2 DSP                // ( ), x1 = value, x0 = address
        str x1, [x0]
        NEXT

// // ( address -- value ) reads value from address
defcode "//",,FETCH
        POPDSP x1
        ldr x0, [x1]
        PUSHDSP x0
        NEXT

// +! ( amount address -- ) add amount to value at address
defcode "+!",,ADDSTORE
        POP2 DSP                // ( ), x1 = amount, x0 = address
        ldr x2, [x0]
        add x2, x2, x1
        str x2, [x0]
        NEXT

// -! ( amount address -- ) subtract amount to value at address
defcode "-!",,SUBSTORE
        POP2 DSP                // ( ), x1 = amount, x0 = address
        ldr x2, [x0]
        sub x2, x2, x1
        str x2, [x0]
        NEXT

// C! ( c addr -- ) write byte c at addr
defcode "C!",,STOREBYTE
        POP2 DSP                // ( ), x1 = c, x0 = addr
        strb w1, [x0]
        NEXT

// C// ( addr -- c ) read byte from addr
defcode "C//",,FETCHBYTE
        POPDSP x1
        ldrb w0, [x1]
        PUSHDSP w0
        NEXT

// CMOVE ( source dest length -- ) copy length bytes from source to dest
defcode "CMOVE",,CMOVE
        POP3 DSP                // ( ), x2 = source, x1 = dest, x0 = length
        cmp x2, x1              // account for potential overlap
        bge 2f                  // copy forward if s >= d, backward otherwise
        sub x3, x0, #1          // (length - 1)
        add x2, x2, x3          // end of source
        add x1, x1, x3          // end of dest
1:
        cmp x0, #0              // while length > 0
        ble 3f
        ldrb w3, [x2], #-1      //    read character from source
        strb w3, [x1], #-1      //    and write it to dest (decrement both pointers)
        sub x0, x0, #1          //    decrement length
        b 1b
2:
        cmp x0, #0              // while length > 0
        ble 3f
        ldrb w3, [x2], #1       //    read character from source
        strb w3, [x1], #1       //    and write it to dest (increment both pointers)
        sub x0, x0, #1          //    decrement length
        b 2b
3:
        NEXT

// COUNT ( addr -- addr+1 c ) extract first byte (len) of counted string
defcode "COUNT",,COUNT
        POPDSP x0
        ldrb w1, [x0], #1       // get byte and increment pointer
        PUSHDSP x0
        PUSHDSP x1
        NEXT

// >R ( a -- ) move the top element from the data stack to the return stack
defcode ">R",,TOR
        POPDSP x0
        PUSHRSP x0
        NEXT

// R> ( -- a ) move the top element from the return stack to the data stack
defcode "R>",,FROMR
        POPRSP x0
        PUSHDSP x0
        NEXT

// RDROP drops the top element from the return stack
defcode "RDROP",,RDROP
        add RSP,RSP,#8
        NEXT

// RSP//, RSP!, DSP//, DSP! manipulate the return and data stack pointers

defcode "RSP//",,RSPFETCH
        PUSHDSP RSP
        NEXT

defcode "RSP!",,RSPSTORE
        POPDSP RSP
        NEXT

defcode "DSP//",,DSPFETCH
        mov x0, DSP
        PUSHDSP x0
        NEXT

defcode "DSP!",,DSPSTORE
        POPDSP x0
        mov DSP, x0
        NEXT

// KEY ( -- c ) Reads a character from stdin
	defcode "KEY",,KEY
	DSP_TO_SP_FOR_ABI_CALL
        bl getchar              // x0 = getchar();
        PUSHDSP x0              // push the return value on the stack
        NEXT

// EMIT ( c -- ) Writes character c to stdout
defcode "EMIT",,EMIT
        POPDSP x0
	DSP_TO_SP_FOR_ABI_CALL
        bl putchar              // putchar(x0);
        NEXT

// CR ( -- ) print newline
// : CR '\n' EMIT ;
defcode "CR",,CR
        mov x0, #10
	DSP_TO_SP_FOR_ABI_CALL
        bl putchar              // putchar('\n');
        NEXT

// SPACE ( -- ) print space
// : SPACE BL EMIT ;  \ print space
defcode "SPACE",,SPACE
        mov x0, #32
	DSP_TO_SP_FOR_ABI_CALL
        bl putchar              // putchar(' ');
        NEXT

// WORD ( -- addr length ) reads next word from stdin
// skips spaces, control-characters and comments, limited to 32 characters
defcode "WORD",,WORD
        bl _WORD
        PUSHDSP x0              // address
        PUSHDSP x1              // length
        NEXT

_WORD:
	PUSHDSP x6
	PUSHDSP lr

	DSP_TO_SP_FOR_ABI_CALL
1:
        bl getchar              // read a character
        cmp x0, #'\\'
        beq 3f                  // skip comments until end of line
        cmp x0, #' '
        ble 1b                  // skip blank character

        ldr     x6, =word_buffer
2:
        strb w0, [x6], #1       // store character in word buffer
        bl getchar              // read more characters until a space is found
        cmp x0, #' '
        bgt 2b

        ldr x0, =word_buffer    // x0, address of word
        sub x1, x6, x0          // x1, length of word
	
	POPDSP lr
	POPDSP x6
	ret
3:
        bl getchar              // skip all characters until end of line
        cmp x0, #'\n'
        bne 3b
        b 1b

// word_buffer for WORD
        .data
        .align 5                // align to cache-line size
word_buffer:
        .space 32               // FIXME: what about overflow!?

// NUMBER ( addr length -- n e ) converts string to number
// n is the parsed number
// e is the number of unparsed characters
defcode "NUMBER",,NUMBER
        POPDSP x1
        POPDSP x0
        bl _NUMBER
        PUSHDSP x0
        PUSHDSP x1
        NEXT

_NUMBER:
	PUSHDSP x4
	PUSHDSP x5
	PUSHDSP x6
	PUSHDSP lr

        // Save address of the string.
        mov x2, x0

        // x0 will store the result after conversion.
        mov x0, #0

        // Check if length is positive, otherwise this is an error.
        cmp x1, #0
        ble 5f

        // Load current base.
        ldr x3, =var_BASE
        ldr x3, [x3]

        // Load first character and increment pointer.
        ldrb w4, [x2], #1

        // Check trailing '-'.
        mov x5, #0
        cmp x4, #45 // 45 in '-' en ASCII
        // Number is positive.
        bne 2f
        // Number is negative.
        mov x5, #1
        sub x1, x1, #1

        // Check if we have more than just '-' in the string.
        cmp x1, #0
        // No, proceed with conversion.
        bgt 1f
        // Error.
        mov x1, #1
        b 5f
1:
        // number *= BASE
        // Arithmetic shift right.
        // On ARM we need to use an additional register for MUL.
        mul x6, x0, x3
        mov x0, x6

        // Load the next character.
        ldrb w4, [x2], #1
2:
        // Convert the character into a digit.
        sub x4, x4, #48 // x4 = x4 - '0'
        cmp x4, #0
        blt 4f // End, < 0
        cmp x4, #9
        ble 3f // chiffre compris entre 0 et 9

        // Test if hexadecimal character.
        sub x4, x4, #17 // 17 = 'A' - '0'
        cmp x4, #0
        blt 4f // End, < 'A'
        add x4, x4, #10
3:
        // Compare to the current base.
        cmp x4, x3
        bge 4f // End, > BASE

        // Everything is fine.
        // Add the digit to the result.
        add x0, x0, x4
        sub x1, x1, #1

        // Continue processing while there are still characters to read.
        cmp x1, #0
        bgt 1b
4:
        // Negate result if we had a '-'.
        cmp x5, #1
	bne 5f
        sub x0, xzr, x0
5:
        // Back to the caller.
	POPDSP lr
	POPDSP x6
	POPDSP x5
	POPDSP x4
	ret

// FIND ( addr length -- dictionary_address )
// Tries to find a word in the dictionary and returns its address.
// If the word is not found, NULL is returned.
defcode "FIND",,FIND
        POPDSP x1       // length
        POPDSP x0       // addr
        bl _FIND
        PUSHDSP x0
        NEXT

_FIND:
	PUSHDSP x5
	PUSHDSP x6
	PUSHDSP x8
	PUSHDSP x9
        ldr x2, =var_LATEST
        ldr x3, [x2]                    // get the last defined word address
1:
        cmp x3, #0                      // did we check all the words ?
        beq 4f                          // then exit

        ldrb w2, [x3, #8]               // read the length field
        and x2, x2, #(F_HID|F_LEN)      // keep only length + hidden bits
        cmp x2, x1                      // do the lengths match ?
                                        // (note that if a word is hidden,
                                        //  the test will be always negative)
        bne 3f                          // branch if they do not match
                                        // Now we compare strings characters
        mov x5, x0                      // x5 contains searched string
        mov x6, x3                      // x6 contains dict string
        add x6, x6, #9                  // (we skip link and length fields)
                                        // x2 contains the length

2:
        ldrb w8, [x5], #1               // compare character per character
        ldrb w9, [x6], #1
        cmp x8,x9
        bne 3f                          // if they do not match, branch to 3
        subs x2,x2,#1                   // decrement length
        bne 2b                          // loop

                                        // here, strings are equal
        b 4f                            // branch to 4

3:
        ldr x3, [x3]                    // Mismatch, follow link to the next
        b 1b                            // dictionary word
4:
        mov x0, x3                      // move result to x0
	POPDSP	x9
	POPDSP  x8
	POPDSP  x6
	POPDSP  x5
        ret

// >CFA ( dictionary_address -- executable_address )
// Transformat a dictionary address into a code field address
defcode ">CFA",,TCFA
        POPDSP x0
        bl _TCFA
        PUSHDSP x0
        NEXT

_TCFA:
        add x0,x0, #8            // skip link field
	mov x1, #0
        ldrb w1, [x0], #1       // load and skip the length field
        and x1,x1, #F_LEN        // keep only the length
        add x0,x0,x1            // skip the name field
        add x0,x0, #7            // find the next 4-byte boundary
        and x0,x0, #~7
        ret

// >DFA ( dictionary_address -- data_field_address )
// Return the address of the first data field
defcode ">DFA",,TDFA
        POPDSP x0
        bl _TCFA
        add x0,x0,#8            // DFA follows CFA
        PUSHDSP x0
        NEXT

// CREATE ( address length -- ) Creates a new dictionary entry
// in the data segment.
defcode "CREATE",,CREATE
        POPDSP x1       // length of the word to insert into the dictionnary
        POPDSP x0       // address of the word to insert into the dictionnary

        ldr x2,=var_HERE
        ldr x3,[x2]     // load into x3 and x8 the location of the header
        mov x8,x3

        ldr x4,=var_LATEST
        ldr x5,[x4]     // load into x5 the link pointer

        str x5,[x3]     // store link here -> last

        add x3,x3, #8    // skip link adress
        strb w1,[x3]    // store the length of the word
        add x3,x3,#1    // skip the length adress

        mov x7,#0       // initialize the incrementation

1:
        cmp x7,x1       // if the word is completley read
        beq 2f

        ldrb w6,[x0,x7] // read and store a character
        strb w6,[x3,x7]

        add x7,x7,#1    // ready to read the next character

        b 1b

2:
        add x3,x3,x7            // skip the word

        add x3,x3,#7            // align to next 8 byte boundary
        and x3,x3,#~7

        str x8,[x4]             // update LATEST and HERE
        str x3,[x2]

        NEXT

// , ( n -- ) writes the top element from the stack at HERE
defcode ",",,COMMA
        POPDSP x0
        bl _COMMA
        NEXT

_COMMA:
        ldr     x1, =var_HERE
        ldr     x2, [x1]        // read HERE
        str     x0, [x2], #8    // write value and increment address
        str     x2, [x1]        // update HERE
        ret

// [ ( -- ) Change interpreter state to Immediate mode
defcode "[",F_IMM,LBRAC
        ldr     x0, =var_STATE
        mov     x1, #0                  // FALSE
        str     x1, [x0]
        NEXT

// ] ( -- ) Change interpreter state to Compilation mode
defcode "]",,RBRAC
        ldr     x0, =var_STATE
        mvn     x1, xzr                  // TRUE
        str     x1, [x0]
        NEXT

// : word ( -- ) Define a new FORTH word
// : : WORD CREATE DOCOL , LATEST // HIDDEN ] ;
defword ":",,COLON
        .quad WORD                       // Get the name of the new word
        .quad CREATE                     // CREATE the dictionary entry / header
        .quad DOCOL, COMMA               // Append DOCOL (the codeword).
        .quad LATEST, FETCH, HIDDEN      // Make the word hidden (see definition below).
        .quad RBRAC                      // Go into compile mode.
        .quad EXIT                       // Return from the function.

// : ; IMMEDIATE LIT EXIT , LATEST // HIDDEN [ ;
defword ";",F_IMM,SEMICOLON
        .quad LIT, EXIT, COMMA           // Append EXIT (so the word will return).
        .quad LATEST, FETCH, HIDDEN      // Unhide the word (hidden by COLON).
        .quad LBRAC                      // Go back to IMMEDIATE mode.
        .quad EXIT                       // Return from the function.

// IMMEDIATE ( -- ) set IMMEDIATE flag of last defined word
defcode "IMMEDIATE",F_IMM,IMMEDIATE
        ldr x0, =var_LATEST     // address of last word defined
        ldr x0, [x0]            // get dictionary entry
        ldrb w1, [x0, #8]!      // get len/flag byte
        orr w1, w1, #F_IMM      // set F_IMMEDIATE
        strb w1, [x0]           // update len/flag
        NEXT

// HIDDEN ( dictionary_address -- ) toggle HIDDEN flag of a word
defcode "HIDDEN",,HIDDEN
        POPDSP  x0
        ldrb w1, [x0, #8]!      // get len/flag byte
        eor w1, w1, #F_HID      // toggle F_HIDDEN
        strb w1, [x0]           // update len/flag
        NEXT

// HIDE ( -- ) hide a word, FIND fails if already hidden
defword "HIDE",,HIDE
        .quad WORD               // Get the word (after HIDE).
        .quad FIND               // Look up in the dictionary.
        .quad HIDDEN             // Set F_HIDDEN flag.
        .quad EXIT               // Return.

// ' ( -- ) returns the codeword address of next read word
// only works in compile mode. Implementation is identical to LIT.
defcode "'",,TICK
        ldr x1, [FIP], #8
        PUSHDSP x1
        NEXT

// LITERAL (C: value --) (S: -- value) compile `LIT value`
// : LITERAL IMMEDIATE ' LIT , , ;  \ takes <word> from the stack and compiles LIT <word>
defword "LITERAL",F_IMM,LITERAL
        .quad TICK, LIT, COMMA   // compile 'LIT'
        .quad COMMA              // compile value
        .quad EXIT               // Return.

// [COMPILE] word ( -- ) compile otherwise IMMEDIATE word
// : [COMPILE] IMMEDIATE WORD FIND >CFA , ;
defword "[COMPILE]",F_IMM,BRKCOMPILE
        .quad WORD               // get the next word
        .quad FIND               // find it in the dictionary
        .quad TCFA               // get its codeword
        .quad COMMA              // and compile that
        .quad EXIT               // Return.

// RECURSE ( -- ) compile recursive call to current word
// : RECURSE IMMEDIATE LATEST // >CFA , ;
defword "RECURSE",F_IMM,RECURSE
        .quad LATEST, FETCH      // LATEST points to the word being compiled at the moment
        .quad TCFA               // get the codeword
        .quad COMMA              // compile it
        .quad EXIT               // Return.

// BRANCH ( -- ) changes FIP by offset which is found in the next codeword
defcode "BRANCH",,BRANCH
        ldr x1, [FIP]
        add FIP, FIP, x1
        NEXT

// 0BRANCH ( p -- ) branch if the top of the stack is zero
defcode "0BRANCH",,ZBRANCH
        POPDSP x0
        cmp x0, #0              // if the top of the stack is zero
        beq code_BRANCH         // then branch
        add FIP, FIP, #8        // else, skip the offset
        NEXT

// IF true-part THEN ( p -- ) conditional execution
// : IF IMMEDIATE ' 0BRANCH , HERE // 0 , ;
defword "IF",F_IMM,IF
        .quad TICK, ZBRANCH, COMMA       // compile 0BRANCH
        .quad HERE, FETCH                // save location of the offset on the stack
        .quad LIT, 0, COMMA              // compile a dummy offset
        .quad EXIT
// : THEN IMMEDIATE DUP HERE // SWAP - SWAP ! ;
defword "THEN",F_IMM,THEN
        .quad DUP                        // copy address saved on the stack
        .quad HERE, FETCH, SWAP, SUB     // calculate the offset
        .quad SWAP, STORE                // store the offset in the back-filled location
        .quad EXIT
// IF true-part ELSE false-part THEN ( p -- ) conditional execution
// : ELSE IMMEDIATE ' BRANCH , HERE // 0 , SWAP DUP HERE // SWAP - SWAP ! ;
defword "ELSE",F_IMM,ELSE
        .quad TICK, BRANCH, COMMA        // definite branch to just over the false-part
        .quad HERE, FETCH                // save location of the offset on the stack
        .quad LIT, 0, COMMA              // compile a dummy offset
        .quad SWAP                       // now back-fill the original (IF) offset
        .quad DUP                        // same as for THEN word above...
        .quad HERE, FETCH, SWAP, SUB
        .quad SWAP, STORE
        .quad EXIT
// UNLESS false-part ... ( p -- ) same as `NOT IF`
// : UNLESS IMMEDIATE ' NOT , [COMPILE] IF ;
defword "UNLESS",F_IMM,UNLESS
        .quad TICK, NOT, COMMA           // compile NOT (to reverse the test)
        .quad IF                         // continue by calling the normal IF
        .quad EXIT

// BEGIN loop-part p UNTIL ( -- ) post-test loop
// : BEGIN IMMEDIATE HERE // ;
defword "BEGIN",F_IMM,BEGIN
        .quad HERE, FETCH                // save location on the stack
        .quad EXIT
// : UNTIL IMMEDIATE ' 0BRANCH , HERE // - , ;
defword "UNTIL",F_IMM,UNTIL
        .quad TICK, ZBRANCH, COMMA       // compile 0BRANCH
        .quad HERE, FETCH, SUB           // calculate offset saved location
        .quad COMMA                      // compile the offset here
        .quad EXIT
// BEGIN loop-part AGAIN ( -- ) infinite loop (until EXIT)
// : AGAIN IMMEDIATE ' BRANCH , HERE // - , ;
defword "AGAIN",F_IMM,AGAIN
        .quad TICK, BRANCH, COMMA        // compile BRANCH
        .quad HERE, FETCH, SUB           // calculate the offset back
        .quad COMMA                      // compile the offset here
        .quad EXIT
// BEGIN p WHILE loop-part REPEAT ( -- ) pre-test loop
// : WHILE IMMEDIATE ' 0BRANCH , HERE // 0 , ;
defword "WHILE",F_IMM,WHILE
        .quad TICK, ZBRANCH, COMMA       // compile 0BRANCH
        .quad HERE, FETCH                // save location of the offset2 on the stack
        .quad LIT, 0, COMMA              // compile a dummy offset2
        .quad EXIT
// : REPEAT IMMEDIATE ' BRANCH , SWAP HERE // - , DUP HERE // SWAP - SWAP ! ;
defword "REPEAT",F_IMM,REPEAT
        .quad TICK, BRANCH, COMMA        // compile BRANCH
        .quad SWAP                       // get the original offset (from BEGIN)
        .quad HERE, FETCH, SUB, COMMA    // and compile it after BRANCH
        .quad DUP
        .quad HERE, FETCH, SWAP, SUB     // calculate the offset2
        .quad SWAP, STORE                // and back-fill it in the original location
        .quad EXIT

// CASE cases... default ENDCASE ( selector -- ) select case based on selector value
// value OF case-body ENDOF ( -- ) execute case-body if (selector == value)
// : CASE IMMEDIATE 0 ;
defword "CASE",F_IMM,CASE
        .quad LIT, 0                     // push 0 to mark the bottom of the stack
        .quad EXIT
// : OF IMMEDIATE ' OVER , ' = , [COMPILE] IF ' DROP , ;
defword "OF",F_IMM,OF
        .quad TICK, OVER, COMMA          // compile OVER
        .quad TICK, EQ, COMMA            // compile =
        .quad IF                         // compile IF
        .quad TICK, DROP, COMMA          // compile DROP
        .quad EXIT
// : ENDOF IMMEDIATE [COMPILE] ELSE ;
defword "ENDOF",F_IMM,ENDOF
        .quad ELSE                       // ENDOF is the same as ELSE
        .quad EXIT
// : ENDCASE IMMEDIATE ' DROP , BEGIN ?DUP WHILE [COMPILE] THEN REPEAT ;
defword "ENDCASE",F_IMM,ENDCASE
        .quad TICK, DROP, COMMA          // compile DROP
        .quad QDUP, ZBRANCH, 32          // while we're not at our zero marker
        .quad THEN, BRANCH, -40          // keep compiling THEN
        .quad EXIT

// LITSTRING as LIT but for strings
defcode "LITSTRING",,LITSTRING
        ldr x0, [FIP], #8       // read length
        PUSHDSP FIP             // push address
        PUSHDSP x0              // push string
        add FIP, FIP, x0        // skip the string
        add FIP, FIP, #7        // find the next 4-byte boundary
        and FIP, FIP, #~7
        NEXT

// CONSTANT name ( value -- ) create named constant value
// : CONSTANT WORD CREATE DOCOL , ' LIT , , ' EXIT , ;
defword "CONSTANT",,CONSTANT
        .quad WORD               // get the name (the name follows CONSTANT)
        .quad CREATE             // make the dictionary entry
        .quad DOCOL, COMMA       // append _DOCOL (the codeword field of this word)
        .quad TICK, LIT, COMMA   // append the codeword LIT
        .quad COMMA              // append the value on the top of the stack
        .quad TICK, EXIT, COMMA  // append the codeword EXIT
        .quad EXIT               // Return.

// ALLOT ( n -- addr ) allocate n bytes of user memory
// : ALLOT HERE // SWAP HERE +! ;
defword "ALLOT",,ALLOT
        .quad HERE, FETCH, SWAP  // ( here n )
        .quad HERE, ADDSTORE     // adds n to HERE, the old value of HERE is still on the stack
        .quad EXIT               // Return.

// CELLS ( n -- m ) number of bytes for n cells
// : CELLS 4* ;
defword "CELLS",,CELLS
        .quad MUL8               // 8 bytes per cell
        .quad EXIT               // Return.

// VARIABLE name ( -- addr ) create named variable location
// : VARIABLE 1 CELLS ALLOT WORD CREATE DOCOL , ' LIT , , ' EXIT , ;
defword "VARIABLE",,VARIABLE
        .quad LIT, 8, ALLOT      // allocate 1 cell of memory, push the pointer to this memory
        .quad WORD, CREATE       // make the dictionary entry (the name follows VARIABLE)
        .quad DOCOL, COMMA       // append _DOCOL (the codeword field of this word)
        .quad TICK, LIT, COMMA   // append the codeword LIT
        .quad COMMA              // append the pointer to the new memory
        .quad TICK, EXIT, COMMA  // append the codeword EXIT
        .quad EXIT               // Return.

// TELL ( addr length -- ) writes a string to stdout
defcode "TELL",,TELL
        POPDSP x1               // length
        POPDSP x0               // address
        bl _TELL
        NEXT

_TELL:
	PUSHDSP SCRATCH0
	PUSHDSP SCRATCH1
	PUSHDSP lr
	
	DSP_TO_SP_FOR_ABI_CALL

        mov SCRATCH0, x0              // address
        mov SCRATCH1, x1              // length

        b 2f
1:                              // while (--SCRATCH1 > 0) {
        ldrb w0, [SCRATCH0], #1 //     x0 = *SCRATCH0++;
        bl putchar              //     putchar(x0);
2:                              // }
        subs SCRATCH1, SCRATCH1, #1
        bge 1b

	POPDSP lr
	POPDSP SCRATCH1
	POPDSP SCRATCH0
	ret

// DIVMOD computes the unsigned integer division and remainder
// The implementation is based upon the algorithm extracted from 'ARM Software
// Development Toolkit User Guide v2.50' published by ARM in 1997-1998
// The algorithm is split in two steps: search the biggest divisor b^(2^n)
// lesser than a and then subtract it and all b^(2^i) (for i from 0 to n)
// to a.
// ( a b -- r q ) where a = q * b + r
defcode "/MOD",,DIVMOD
        POPDSP  x1                      // Get b
        POPDSP  x0                      // Get a
        udiv    x2, x0, x1              // Get q
	msub    x0, x1, x2, x0          // r = a - q * b
        PUSHDSP x0                      // Put r
        PUSHDSP x2                      // Put q
        NEXT

// on entry x0=integer x1=base
// in-use x0=num/mod x1=base x2=div x3=tmp/dig x4=pad
// on exit x0=addr x1=len x2=end
_UFMT:                                  // Unsigned Integer Formatting
	PUSHDSP x4

        ldr     x4, =scratch_pad_top    // start beyond the PAD
        cmp     x0, x1                  // if (num >= base)
        bhs     2f                      // then, do DIVMOD first
        mov     x2, #0                  // else, initial div = 0
1:
        mov	SCRATCH0, #48
	mov     SCRATCH1, #65
        subs    x3, x0, #10             // tmp = num - 10
	csel    SCRATCH2, SCRATCH0, SCRATCH1, lt // dig = '0' + num, if num < 10
	csel    SCRATCH3, x0, x3, lt             // dig = 'A' + tmp, if num >= 10
        add     x3, SCRATCH3, SCRATCH2

        strb    w3, [x4, #-1]!          // *(--pad) = dig
	subs    x0, x2, xzr             // num = div
        beq     3f                      // if num == 0, we're done!
2:
	udiv    x2, x0, x1
	msub    x0, x1, x2, x0
        b       1b                      // convert next digit
3:
        mov     x0, x4                  // string address
        ldr     x2, =scratch_pad_top    // get PAD end
        sub     x1, x2, x4              // string length

	POPDSP  x4
	ret

// U. ( u -- ) print unsigned number and a trailing space
defcode "U.",,UDOT
        POPDSP  x0                      // number from stack
        ldr     x1, =var_BASE           // address of BASE
        ldr     x1, [x1]                // current value of BASE
        bl      _UDOT
        NEXT

// on entry x0=number, x1=base
// on exit x0=- x1=base
_UDOT:
	PUSHDSP x1
	PUSHDSP lr

        bl      _UFMT                   // (num, base, -, -) ==> (addr, len, end, -)
        bl      _TELL                   // display number
        mov     x0, #32                 // space character
	DSP_TO_SP_FOR_ABI_CALL
        bl      putchar                 // print trailing space

	POPDSP lr
	POPDSP x1
	ret

// U.R ( u width -- ) print unsigned number, padded to width
defcode "U.R",,UDOTR
        ldr     x0, [DSP, #8]           // number from stack
        ldr     x1, =var_BASE           // address of BASE
        ldr     x1, [x1]                // current value of BASE
        bl      _UFMT                   // (num, base, -, -) ==> (addr, len, end, -)
        ldr     x2, [DSP]               // width from stack
        bl      _DOTR                   // (addr, len, width, -) ==> (addr, len, width, -)
        add     DSP, DSP, #16           // remove number and width before return
        NEXT

// on entry x0=integer x1=base
// on exit x0=addr x1=len x2=end
_DFMT:                          // Signed Integer Formatting
	PUSHDSP lr

        subs    x0, x0, xzr             // check sign of number
        blt     1f                      // if num < 0, jump to negative case
        bl      _UFMT                   // (num, base, -, -) ==> (addr, len, end, -)

	POPDSP  lr
	ret
1:
        neg     x0, x0                  // num = -num
        bl      _UFMT                   // (num, base, -, -) ==> (addr, len, end, -)
        mov     x3, #45                 // tmp = '-'
        strb    w3, [x0, #-1]!          // *(--addr) = tmp
        add     x1, x1, #1              // ++len
	
        POPDSP  lr
	ret

// . ( n -- ) print signed number and a trailing space
defcode ".",,DOT
        POPDSP  x0                      // number from stack
        ldr     x1, =var_BASE           // address of BASE
        ldr     x1, [x1]                // current value of BASE
        bl      _DOT
        NEXT

// on entry x0=number, x1=base
// on exit x0=- x1=base
_DOT:
	PUSHDSP x1
	PUSHDSP lr

        bl      _DFMT                   // (num, base, -, -) ==> (addr, len, end, -)
        bl      _TELL                   // display number
        mov     x0, #32                 // space character

	DSP_TO_SP_FOR_ABI_CALL
        bl      putchar                 // print trailing space

	POPDSP  lr
	POPDSP  x1
	ret

// .R ( n width -- ) print signed number, padded to width
defcode ".R",,DOTR
        ldr     x0, [DSP, #8]           // number from stack
        ldr     x1, =var_BASE           // address of BASE
        ldr     x1, [x1]                // current value of BASE
        bl      _DFMT                   // (num, base, -, -) ==> (addr, len, end, -)
        ldr     x2, [DSP]               // width from stack
        bl      _DOTR                   // (addr, len, width, -) ==> (addr, len, width, -)
        add     DSP, DSP, #16           // remove number and width before return
        NEXT

// on entry x0=addr x1=len x2=width
// on exit x0=addr x1=len x2=width
_DOTR:                          // Pad to field width
        PUSHDSP lr

        mov     x3, #32                 // space character
1:      cmp     x1, x2                  // while (len < width) {
	bge     2f
        strb    w3, [x0, #-1]!          //     *(--addr) = ' ';
        add     x1, x1, #1              //     ++len;
        b       1b                      // }
        bl      _TELL                   // display number

2:	POPDSP  lr
        ret

// ? ( addr -- ) fetch and print signed number at addr
// : // . ;
defword "?",,QUESTION
        .quad FETCH
        .quad DOT
        .quad EXIT

// DEPTH ( -- n ) the number of items on the stack
// : DEPTH DSP// S0 // SWAP - 8 / ;
defcode "DEPTH",,DEPTH
        ldr     x0, =var_S0             // address of stack origin
        ldr     x0, [x0]                // stack origin value
	mov     x1, DSP
        sub     x0, x0, x1              // number of bytes on stack
	asr     x0, x0, #3              // /8 to count cells
        PUSHDSP x0
        NEXT

// .S ( -- ) print the contents of the stack (non-destructive)
defcode ".S",,DOTS
        mov     x0, DSP                 // grab original stack top
	PUSHDSP x4
	PUSHDSP x5

        mov     x4, x0                  // remember original top
        ldr     x5, =var_S0             // address of stack origin
        ldr     x5, [x5]                // location = stack origin
        ldr     x1, =var_BASE           // address of BASE
        ldr     x1, [x1]                // current value of BASE
        cmp     x1, #10                 // if BASE is 10
        bne     2f                      // print signed, otherwise unsigned
1:                                      // LOOP {  // signed
        ldr     x0, [x5, #-8]!          //     item = *--location
        cmp     x5, x4                  //     if (location < top)
        blt     3f                      //         goto EXIT
        bl      _DOT                    //     print item (preserves x1)
        b       1b                      // }
2:                                      // LOOP {  // unsigned
        ldr     x0, [x5, #-8]!          //     item = *--location
        cmp     x5, x4                  //     if (location < top)
        blt     3f                      //         goto EXIT
        bl      _UDOT                   //     print item (preserves x1)
        b       2b                      // }
3:                                      // EXIT:
	POPDSP  x5
	POPDSP  x4
        NEXT


// Alternative to DIVMOD: signed implementation using Euclidean division.
defcode "S/MOD",,SDIVMOD
        POPDSP x2                       // Denominator
        POPDSP x1                       // Numerator
        sdiv    x2, x0, x1              // Get q
	smsubl  x0, w1, w2, x0          // r = a - q * b
        PUSHDSP x0                      // Remainder
        PUSHDSP x2                      // Quotient
        NEXT

// QUIT ( -- ) the first word to be executed
defword "QUIT",, QUIT
        .quad R0, RSPSTORE               // Clear return stack
        .quad S0, FETCH, DSPSTORE        // Clear data stack
        .quad INTERPRET                  // Interpret a word
        .quad BRANCH,-16                 // LOOP FOREVER

// INTERPRET, reads a word from stdin and executes or compiles it.
// No need to backup callee save registers here,
// since we are the top level routine!
defcode "INTERPRET",,INTERPRET
        ldr SCRATCH0, =var_S0           // address of stack origin
        ldr SCRATCH0, [SCRATCH0]        // stack origin value
	mov SCRATCH1, DSP
        cmp SCRATCH0, SCRATCH1          // check stack pointer against origin
        bge 7f                          // go to 7, if stack is ok

        // Stack Underflow
        mov DSP, SCRATCH0                // reset stack pointer
        ldr x0, =errstack
        mov x1, #(errstackend-errstack)
        bl _TELL                        // Print error message

7:  // Stack OK
        mov x8, #0                      // interpret_is_lit = 0

        bl _WORD                        // read a word from stdin
        mov SCRATCH0, x0                      // store it in x4,x5
        mov SCRATCH1, x1
	
        bl _FIND                        // find its dictionary entry
        cmp x0, #0                      // if not found go to 1
        beq 1f

    // Here the entry is found
        ldrb w6, [x0, #8]               // read length and flags field
        bl _TCFA                        // find code field address
        tst x6, #F_IMM                  // if the word is immediate
        bne 4f                          // branch to 4 (execute)
        b 2f                            // otherwise, branch to 2
	
1:  // Not found in dictionary
        mov x8, #1                      // interpret_is_lit = 1
        mov x0, SCRATCH0                // restore word
        mov x1, SCRATCH1
        bl _NUMBER                      // convert it to number
        cmp x1, #0                      // if errors were found
        bne 6f                          // then fail

    // it's a literal
        mov x6, x0                      // keep the parsed number if x6
        ldr x0, =LIT                    // we will compile a LIT codeword

2:  // Compiling or Executing
        ldr x1, =var_STATE              // Are we compiling or executing ?
        ldr x1, [x1]
        cmp x1, #0
        beq 4f                          // Go to 4 if in interpret mode

    // Here in compile mode

        bl _COMMA                       // Call comma to compile the codeword
        cmp x8, #1                      // If it's a literal, we have to compile
	bne 3f
        mov  x0, x6                    // the integer ...
        bl  _COMMA                     // .. too
3:	NEXT

4:  // Executing
        cmp x8, #1                      // if it's a literal, branch to 5
        beq 5f

                                        // not a literal, execute now
        ldr x1, [x0]                    // (it's important here that
        br  x1                          //  FIP address in x0, since _DOCOL
                                        //  assumes it)

5:  // Push literal on the stack
        PUSHDSP x6
        NEXT

6:  // Parse error
	
        ldr x0, =errpfx
        mov x1, #(errpfxend-errpfx)
        bl _TELL                        // Begin error message

        mov x0, SCRATCH0                // Address of offending word
        mov x1, SCRATCH1                // Length of offending word
        bl _TELL

        ldr x0, =errsfx
        mov x1, #(errsfxend-errsfx)
        bl _TELL                        // End error message

        NEXT

        .section .rodata
errstack:
        .ascii "Stack empty!\n"
errstackend:

errpfx:
        .ascii "Unknown word <"
errpfxend:

errsfx:
        .ascii ">\n"
errsfxend:

// CHAR ( -- c ) ASCII code from first character of following word
defcode "CHAR",,CHAR
        bl _WORD
        ldrb w1, [x0]
        PUSHDSP w1
        NEXT

// DECIMAL ( -- ) set number conversion BASE to 10
// : DECIMAL ( -- ) 10 BASE ! ;
defcode "DECIMAL",, DECIMAL
        mov     x0, #10
        ldr     x1, =var_BASE
        str     x0, [x1]
        NEXT

// HEX ( -- ) set number conversion BASE to 16
// : HEX ( -- ) 16 BASE ! ;
defcode "HEX",, HEX
        mov     x0, #16
        ldr     x1, =var_BASE
        str     x0, [x1]
        NEXT

// 10// value ( -- n ) interpret decimal literal value w/o changing BASE
// : 10// BASE // 10 BASE ! WORD NUMBER DROP SWAP BASE ! ;
defword "10//",,DECNUMBER
        .quad BASE, FETCH
        .quad LIT, 10, BASE, STORE
        .quad WORD, NUMBER
        .quad DROP, SWAP
        .quad BASE, STORE
        .quad EXIT

// 16// value ( -- n ) interpret hexadecimal literal value w/o changing BASE
// : 16// BASE // 16 BASE ! WORD NUMBER DROP SWAP BASE ! ;
defword "16//",,HEXNUMBER
        .quad BASE, FETCH
        .quad LIT, 16, BASE, STORE
        .quad WORD, NUMBER
        .quad DROP, SWAP
        .quad BASE, STORE
        .quad EXIT

// UPLOAD ( -- addr len ) XMODEM file upload to memory
defcode "UPLOAD",,UPLOAD
        ldr x0, =0x10000        // Upload buffer address
        ldr x1, =0x7F00         // Upload limit (32k - 256) bytes
        PUSHDSP x0              // Push buffer address on the stack
        bl rcv_xmodem           // x0 = rcv_xmodem(x0, x1);
        PUSHDSP x0              // Push upload byte count on the stack
        NEXT

// DUMP ( addr len -- ) Pretty-printed memory dump
defcode "DUMP",,DUMP
        POPDSP x1
        POPDSP x0
        bl hexdump              // hexdump(x0, x1);
        NEXT

// BOOT ( addr len -- ) Boot from memory image (see UPLOAD)
defcode "BOOT",,BOOT
        POP2 DSP                // ( ), x1 = addr, x0 = len
        cmp x0, #0              // len = 0 on upload failure
	beq 1f
        br x1                 // jump to boot address if len > 0
1:	ldr x0, =errboot
        mov x1, #(errbootend-errboot)
        bl _TELL                // write error message to console
        NEXT

.section .rodata
errboot: .ascii "Bad image!\n"
errbootend:

// MONITOR ( -- ) Enter bootstrap monitor
defcode "MONITOR",,MONITOR
        bl monitor              // monitor();
        NEXT

	.macro COMPILE_INSN, insn:vararg
	.quad LIT
	\insn
	.quad COMMA
	.endm

//
// $NEXT ( -- ) emits the _NEXT body at HERE, to be used
// in CODE or ;CODE-defined words.
//
defword "$NEXT",F_IMM,ASMNEXT
	NEXT_BODY COMPILE_INSN
	.quad EXIT

//
// A CREATE...DOES> word is basically a special CREATE...;CODE
// word, where the forth words follow $DODOES. $DODOES thus
// adjusts FIP to point right past $DODOES and does NEXT.
//
// You can think of this as a special DOCOL that sets FIP to a
// certain offset into the CREATE...DOES> word's DFA. The offset
// corresponds to the words following the instructions emitted
// by $DODOES. Those instructions do an absolute branch to
// to _DODOES, hence the words to execute are at LR + 8.
//
// - Just like DOCOL, we enter with CFA in x0.
// - Just like DOCOL, we need to push (old) FIP for EXIT to pop.
// - The Forth words expect DFA (i.e. CFA + 8) on stack.
//
_DODOES:
        PUSHRSP FIP
	mov FIP, lr
	add FIP, FIP, #8
	add x0, x0, #8
	PUSHDSP x0
	NEXT

	.macro DODOES_BODY, wrap_insn:vararg=
1:	\wrap_insn ldr SCRATCH0, . + ((3f-1b)/((2f-1b)/(8)))
2:	\wrap_insn blr SCRATCH0
3:      \wrap_insn .quad _DODOES
	.endm

//
// $DODOES ( -- ) emits the machine words used by DOES>.
//
defword "$DODOES",F_IMM,ASMDODOES
	DODOES_BODY COMPILE_INSN
	.quad EXIT

	.purgem COMPILE_INSN

// EXECUTE ( xt -- ) jump to the address on the stack
//-- WARNING! THIS MUST BE THE LAST WORD DEFINED IN ASSEMBLY (see LATEST) --//
defcode "EXECUTE",,EXECUTE
        POPDSP x0
        ldr x1, [x0]
        br  x1

// Reserve space for the return stack (1Kb)
        .bss
        .align 5                // align to cache-line size
        .set RETURN_STACK_SIZE, 0x400
return_stack:
        .space RETURN_STACK_SIZE
return_stack_top:

// Reserve space for new words and data structures (16Kb)
        .bss
        .align 5                // align to cache-line size
        .set DATA_SEGMENT_SIZE, 0x4000
data_segment:
        .space DATA_SEGMENT_SIZE
data_segment_top:

// Reserve space for scratch-pad buffer (128b)
        .bss
        .align 5                // align to cache-line size
        .set SCRATCH_PAD_SIZE, 0x80
scratch_pad:
        .space SCRATCH_PAD_SIZE
scratch_pad_top:
