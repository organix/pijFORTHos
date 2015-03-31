@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ pijFORTHos -- Raspberry Pi JonesFORTH Operating System
@
@ A bare-metal FORTH operating system for Raspberry Pi
@ Copyright (C) 2014 Dale Schumacher and Tristan Slominski
@
@ based on Jones' Forth port for ARM EABI
@ Copyright (C) 2013 M2IHP'13 class
@
@ Original x86 and FORTH code: Richard W.M. Jones <rich@annexia.org>
@
@ See AUTHORS for the full list of contributors.
@
@ The extensive comments from Jones' x86 version have been removed.  You should
@ check them out, they are really detailed, well written and pedagogical.
@ The original sources (with full comments) are in the /annexia/ directory.
@
@ DIVMOD routine taken from the ARM Software Development Toolkit User Guide 2.50
@
@ This program is free software: you can redistribute it and/or modify it under
@ the terms of the GNU Lesser General Public License as published by the Free
@ Software Foundation, either version 3 of the License, or (at your option) any
@ later version.
@
@ This program is distributed in the hope that it will be useful, but WITHOUT
@ ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
@ FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
@ details.
@
@ You should have received a copy of the GNU Lesser General Public License
@ along with this program.  If not, see <http://www.gnu.org/licenses/>.
@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

        .set JONES_VERSION,47

@ Reserve three special registers:
@ DSP (r13) points to the top of the data stack
@ RSP (r11) points to the top of the return stack
@ FIP (r10) points to the next FORTH word that will be executed
@ Note: r12 is often considered a "scratch" register

DSP     .req    r13
RSP     .req    r11
FIP     .req    r10

@ Define macros to push and pop from the data and return stacks

        .macro PUSHRSP reg
        str     \reg, [RSP, #-4]!
        .endm

        .macro POPRSP reg
        ldr     \reg, [RSP], #4
        .endm

        .macro PUSHDSP reg
        str     \reg, [DSP, #-4]!
        .endm

        .macro POPDSP reg
        ldr     \reg, [DSP], #4
        .endm

        .macro PUSH2 reg
        stmdb   \reg!, {r0-r1}          @ ( -- r1 r0 )
        .endm

        .macro POP2 reg
        ldmia   \reg!, {r0-r1}          @ ( r1 r0 -- )
        .endm

        .macro PUSH3 reg
        stmdb   \reg!, {r0-r2}          @ ( -- r2 r1 r0 )
        .endm

        .macro POP3 reg
        ldmia   \reg!, {r0-r2}          @ ( r2 r1 r0 -- )
        .endm

        .macro PUSH4 reg
        stmdb   \reg!, {r0-r3}          @ ( -- r3 r2 r1 r0 )
        .endm

        .macro POP4 reg
        ldmia   \reg!, {r0-r3}          @ ( r3 r2 r1 r0 -- )
        .endm

@ _NEXT is the assembly subroutine that is called
@ at the end of every FORTH word execution.
@ The NEXT macro is defined to simply call _NEXT
        .macro NEXT
        b _NEXT
        .endm

@ jonesforth is the entry point for the FORTH environment
        .text
        .align 2                        @ alignment 2^n (2^2 = 4 byte alignment)
        .global jonesforth
jonesforth:
        ldr r0, =var_S0
        str DSP, [r0]                   @ Save the original stack position in S0
        ldr RSP, =return_stack_top      @ Set the initial return stack position
        ldr r0, =data_segment           @ Get the initial data segment address
        ldr r1, =var_HERE               @ Initialize HERE to point at
        str r0, [r1]                    @   the beginning of data segment
        ldr FIP, =cold_start            @ Make the FIP point to cold_start
		ldr r0, =loadname
		bl loadfile						@ file name in r0, return to 
        NEXT                            @ Start the interpreter

@ _DOCOL is the assembly subroutine that is called
@ at the start of every FORTH word execution, which:
@   0. expects the CFA of a FORTH word in r0
@   1. saves the old FIP on the return stack
@   2. makes FIP point to the DFA (first codeword)
@   3. uses _NEXT to start interpreting the word
_DOCOL:
        PUSHRSP FIP
        add FIP, r0, #4

@ _NEXT is the assembly subroutine that is called
@ at the end of every FORTH word execution, which:
@   1. finds the CFA of the FORTH word to execute
@      by dereferencing the FIP
@   2. increments FIP
@   3. begins executing the routine pointed to
@      by the CFA, with the CFA in r0
_NEXT:
        ldr r0, [FIP], #4
        ldr r1, [r0]
        bx r1

@ cold_start is used to bootstrap the interpreter, 
@ the first word executed is QUIT
        .section .rodata
cold_start:
        .int QUIT


@@ Now we define a set of helper macros that are syntactic sugar
@@ to ease the declaration of FORTH words, Native words, FORTH variables
@@ and FORTH constants.

@ define the word flags
        .set F_IMM, 0x80
        .set F_HID, 0x20
        .set F_LEN, 0x1f

@ link is used to chain the words in the dictionary as they are defined
        .set link, 0

@ defword macro helps defining new FORTH words in assembly
        .macro defword name, namelen, flags=0, label
        .section .rodata
        .align 2
        .global name_\label
name_\label :
        .int link               @ link
        .set link,name_\label
        .byte \flags+\namelen   @ flags + length byte
        .ascii "\name"          @ the name
        .align 2                @ padding to next 4 byte boundary
        .global \label
\label :
        .int _DOCOL             @ codeword - the interpreter
        @ list of word pointers follow
        .endm

@ defcode macro helps defining new native words in assembly
        .macro defcode name, namelen, flags=0, label
        .section .rodata
        .align 2
        .globl name_\label
name_\label :
        .int link               @ link
        .set link,name_\label
        .byte \flags+\namelen   @ flags + length byte
        .ascii "\name"          @ the name
        .align 2                @ padding to next 4 byte boundary
        .global \label
\label :
        .int code_\label        @ codeword
        .text
        .global code_\label
code_\label :                   @ assembler code follows
        .endm

@ EXIT is the last codeword of a FORTH word.
@ It restores the FIP and returns to the caller using NEXT.
@ (See _DOCOL)
defcode "EXIT",4,,EXIT
        POPRSP FIP
        NEXT


@ defvar macro helps defining FORTH variables in assembly
        .macro defvar name, namelen, flags=0, label, initial=0
        defcode \name,\namelen,\flags,\label
        ldr r0, =var_\name
        PUSHDSP r0
        NEXT
        .data
        .align 2
        .global var_\name
var_\name :
        .int \initial
        .endm

@ The built-in variables are:
@  STATE           Is the interpreter executing code (0) or compiling a word (non-zero)?
        defvar "STATE",5,,STATE
@  HERE            Points to the next free byte of memory.  When compiling, compiled words go here.
        defvar "HERE",4,,HERE
@  LATEST          Points to the latest (most recently defined) word in the dictionary.
        defvar "LATEST",6,,LATEST,name_EXECUTE  @ The last word defined in assembly is EXECUTE
@  S0              Stores the address of the top of the parameter stack.
        defvar "S0",2,,S0
@  BASE            The current base for printing and reading numbers.
        defvar "BASE",4,,BASE,10
@  SCREENX			The width of the screen in pixels
		defvar "SCREENX",7,,SCREENX,1024
@  SCREENY			The height of the screen in pixels
		defvar "SCREENY",7,,SCREENY,768
@  SCREENDEPTH		The depth of the screen in bits / pixel
		defvar "SCREENDEPTH",11,,SCREENDEPTH,16
@  FG_COLOUR		The foreground colour to use for char on screen
		defvar "FG_COLOUR",9,,FG_COLOUR,65535
@  BG_COLOUR		The background colour on screen
		defvar "BG_COLOUR",9,,BG_COLOUR,15


@ defconst macro helps defining FORTH constants in assembly
        .macro defconst name, namelen, flags=0, label, value
        defcode \name,\namelen,\flags,\label
        ldr r0, =\value
        PUSHDSP r0
        NEXT
        .endm

@ The built-in constants are:
@  VERSION         Is the current version of this FORTH.
        defconst "VERSION",7,,VERSION,JONES_VERSION
@  R0              The address of the top of the return stack.
        defconst "R0",2,,R0,return_stack_top
@  DOCOL           Pointer to _DOCOL.
        defconst "DOCOL",5,,DOCOL,_DOCOL
@  PAD             Pointer to scratch-pad buffer.
        defconst "PAD",3,,PAD,scratch_pad
@  F_IMMED         The IMMEDIATE flag's actual value.
        defconst "F_IMMED",7,,F_IMMED,F_IMM
@  F_HIDDEN        The HIDDEN flag's actual value.
        defconst "F_HIDDEN",8,,F_HIDDEN,F_HID
@  F_LENMASK       The length mask in the flags/len byte.
        defconst "F_LENMASK",9,,F_LENMASK,F_LEN
@  FALSE           Boolean predicate False (0)
        defcode "FALSE",5,,FALSE
                mov r0, #0
                PUSHDSP r0
                NEXT
@  TRUE            Boolean predicate True (-1)
        defcode "TRUE",4,,TRUE
                mvn r0, #0
                PUSHDSP r0
                NEXT


@ DROP ( a -- ) drops the top element of the stack
defcode "DROP",4,,DROP
        add DSP, DSP, #4        @ ( )
        NEXT

@ DUP ( a -- a a ) duplicates the top element
defcode "DUP",3,,DUP
        ldr r0, [DSP]           @ ( a ), r0 = a
        PUSHDSP r0              @ ( a a ), r0 = a
        NEXT

@ SWAP ( a b -- b a ) swaps the two top elements
defcode "SWAP",4,,SWAP
        POP2 DSP                @ ( ), r1 = a, r0 = b
        PUSHDSP r0              @ ( b ), r1 = a, r0 = b
        PUSHDSP r1              @ ( b a ), r1 = a, r0 = b
        NEXT

@ OVER ( a b -- a b a ) push copy of second element on top
defcode "OVER",4,,OVER
        ldr r0, [DSP, #4]       @ ( a b ), r0 = a
        PUSHDSP r0              @ ( a b a )
        NEXT

@ ROT ( a b c -- b c a ) rotation
defcode "ROT",3,,ROT
        POPDSP r1               @ ( a b ), r1 = c
        POPDSP r2               @ ( a ), r2 = b
        POPDSP r0               @ ( ), r0 = a
        PUSH3 DSP               @ ( b c a ), r2 = b, r1 = c, r0 = a
        NEXT

@ -ROT ( a b c -- c a b ) backwards rotation
defcode "-ROT",4,,NROT
        POP3 DSP                @ ( ), r2 = a, r1 = b, r0 = c
        PUSHDSP r0              @ ( c )
        PUSHDSP r2              @ ( c a )
        PUSHDSP r1              @ ( c a b )
        NEXT

@ 2DROP ( a b -- ) drops the top two elements of the stack
defcode "2DROP",5,,TWODROP
        add DSP, DSP, #8        @ ( )
        NEXT

@ 2DUP ( a b -- a b a b ) duplicate top two elements of stack
@ : 2DUP OVER OVER ;
defcode "2DUP",4,,TWODUP
        ldmia DSP, {r0,r1}      @ ( a b ), r1 = a, r0 = b
        PUSH2 DSP               @ ( a b a b ), r1 = a, r0 = b
        NEXT

@ 2SWAP ( a b c d -- c d a b ) swap top two pairs of elements of stack
@ : 2SWAP >R -ROT R> -ROT ;
defcode "2SWAP",5,,TWOSWAP
        POP4 DSP                @ ( ), r3 = a, r2 = b, r1 = c, r0 = d
        PUSH2 DSP               @ ( c d ), r3 = a, r2 = b, r1 = c, r0 = d
        PUSHDSP r3              @ ( c d a ), r3 = a, r2 = b, r1 = c, r0 = d
        PUSHDSP r2              @ ( c d a b ), r3 = a, r2 = b, r1 = c, r0 = d
        NEXT

@ 2OVER ( a b c d -- a b c d a b ) copy second pair of stack elements
defcode "2OVER",5,,TWOOVER
        ldr r0, [DSP, #8]       @ ( a b c d ), r0 = b
        ldr r1, [DSP, #12]      @ ( a b c d ), r1 = a, r0 = b
        PUSH2 DSP               @ ( a b c d a b ), r1 = a, r0 = b
        NEXT

@ NIP ( a b -- b ) drop the second element of the stack
@ : NIP SWAP DROP ;
defcode "NIP",3,,NIP
        POP2 DSP                @ ( ), r1 = a, r0 = b
        PUSHDSP r0              @ ( b ), r1 = a, r0 = b
        NEXT

@ TUCK ( a b -- b a b ) push copy of top element below second
@ : TUCK SWAP OVER ;
defcode "TUCK",4,,TUCK
        POP2 DSP                @ ( ), r1 = a, r0 = b
        PUSHDSP r0              @ ( b ), r1 = a, r0 = b
        PUSH2 DSP               @ ( b a b ), r1 = a, r0 = b
        NEXT

@ PICK ( a_n ... a_0 n -- a_n ... a_0 a_n ) copy n-th stack item
@ : PICK 1+ 4* DSP@ + @ ;
defcode "PICK",4,,PICK
        POPDSP r0               @ ( a_n ... a_0 ), r0 = n
        ldr r1, [DSP,r0,LSL #2] @ ( a_n ... a_0 ), r0 = n, r1 = a_n
        PUSHDSP r1              @ ( a_n ... a_0 a_n ), r0 = n, r1 = a_n
        NEXT

@ ?DUP ( 0 -- 0 | a -- a a ) duplicates if non-zero
defcode "?DUP", 4,,QDUP
        ldr r0, [DSP]           @ r0 = a
        cmp r0, #0              @ test if a==0
        strne r0, [DSP, #-4]!   @ copy if a!=0
        NEXT                    @ ( a a | 0 )

@ : 1+ ( n -- n+1 ) 1 + ;  \  increments the top element
defcode "1+",2,,INCR
        POPDSP r0
        add r0, r0, #1
        PUSHDSP r0
        NEXT

@ : 1- ( n -- n-1 ) 1 - ;  \  decrements the top element
defcode "1-",2,,DECR
        POPDSP r0
        sub r0, r0, #1
        PUSHDSP r0
        NEXT

@ : 2+ ( n -- n+2 ) 2 + ;  \  increments by 2 the top element
defcode "2+",2,,INCR2
        POPDSP r0
        add r0, r0, #2
        PUSHDSP r0
        NEXT

@ : 2- ( n -- n-2 ) 2 - ;  \ decrements by 2 the top element
defcode "2-",2,,DECR2
        POPDSP r0
        sub r0, r0, #2
        PUSHDSP r0
        NEXT

@ : 4+ ( n -- n+4 ) 4 + ;  \  increments by 4 the top element
defcode "4+",2,,INCR4
        POPDSP r0
        add r0, r0, #4
        PUSHDSP r0
        NEXT

@ : 4- ( n -- n-4 ) 4 - ;  \ decrements by 4 the top element
defcode "4-",2,,DECR4
        POPDSP r0
        sub r0, r0, #4
        PUSHDSP r0
        NEXT

@ + ( a b -- a+b )
defcode "+",1,,ADD
        POP2 DSP                @ ( ), r1 = a, r0 = b
        add r0, r0, r1
        PUSHDSP r0
        NEXT

@ - ( a b -- a-b )
defcode "-",1,,SUB
        POP2 DSP                @ ( ), r1 = a, r0 = b
        sub r0, r1, r0
        PUSHDSP r0
        NEXT

@ 2* ( a -- a*2 )
defcode "2*",2,,MUL2
        POPDSP r0
        mov r0, r0, LSL #1
        PUSHDSP r0
        NEXT

@ 2/ ( a -- a/2 )
defcode "2/",2,,DIV2
        POPDSP r0
        mov r0, r0, ASR #1
        PUSHDSP r0
        NEXT

@ 4* ( a -- a*4 )
defcode "4*",2,,MUL4
        POPDSP r0
        mov r0, r0, LSL #2
        PUSHDSP r0
        NEXT

@ 4/ ( a -- a/4 )
defcode "4/",2,,DIV4
        POPDSP r0
        mov r0, r0, ASR #2
        PUSHDSP r0
        NEXT

@ LSHIFT ( a b -- a<<b )
defcode "LSHIFT",6,,LSHIFT
        POP2 DSP                @ ( ), r1 = a, r0 = b
        mov r0, r1, LSL r0
        PUSHDSP r0
        NEXT

@ RSHIFT ( a b -- a>>b )
defcode "RSHIFT",6,,RSHIFT
        POP2 DSP                @ ( ), r1 = a, r0 = b
        mov r0, r1, LSR r0
        PUSHDSP r0
        NEXT

@ * ( a b -- a*b )
defcode "*",1,,MUL
        POP2 DSP                @ ( ), r1 = a, r0 = b
        mul r2, r1, r0
        PUSHDSP r2
        NEXT

@ / ( n m -- q ) integer division quotient (see /MOD)
@ : / /MOD SWAP DROP ;
defcode "/",1,,DIV
        POPDSP  r1              @ ( n ), r1 = m
        POPDSP  r0              @ ( ), r0 = n, r1 = m
        bl _DIVMOD
        PUSHDSP r2              @ ( q ), r0 = r, r1 = m, r2 = q
        NEXT

@ MOD ( n m -- r ) integer division remainder (see /MOD)
@ : MOD /MOD DROP ;
defcode "MOD",3,,MOD
        POPDSP  r1              @ ( n ), r1 = m
        POPDSP  r0              @ ( ), r0 = n, r1 = m
        bl _DIVMOD
        PUSHDSP r0              @ ( r ), r0 = r, r1 = m, r2 = q
        NEXT

@ NEGATE ( n -- -n ) integer negation
@ : NEGATE 0 SWAP - ;
defcode "NEGATE",6,,NEGATE
        POPDSP r0
        rsb r0, r0, #0
        PUSHDSP r0
        NEXT

@ = ( a b -- p ) where p is 1 when a and b are equal (0 otherwise)
defcode "=",1,,EQ
        POP2 DSP                @ ( ), r1 = a, r0 = b
        cmp r1, r0
        mvneq r0, #0
        movne r0, #0
        PUSHDSP r0
        NEXT

@ <> ( a b -- p ) where p = a <> b
defcode "<>",2,,NEQ
        POP2 DSP                @ ( ), r1 = a, r0 = b
        cmp r1, r0
        mvnne r0, #0
        moveq r0, #0
        PUSHDSP r0
        NEXT

@ < ( a b -- p ) where p = a < b
defcode "<",1,,LT
        POP2 DSP                @ ( ), r1 = a, r0 = b
        cmp r1, r0
        mvnlt r0, #0
        movge r0, #0
        PUSHDSP r0
        NEXT

@ > ( a b -- p ) where p = a > b
defcode ">",1,,GT
        POP2 DSP                @ ( ), r1 = a, r0 = b
        cmp r1, r0
        mvngt r0, #0
        movle r0, #0
        PUSHDSP r0
        NEXT

@ <= ( a b -- p ) where p = a <= b
defcode "<=",2,,LE
        POP2 DSP                @ ( ), r1 = a, r0 = b
        cmp r1, r0
        mvnle r0, #0
        movgt r0, #0
        PUSHDSP r0
        NEXT

@ >= ( a b -- p ) where p = a >= b
defcode ">=",2,,GE
        POP2 DSP                @ ( ), r1 = a, r0 = b
        cmp r1, r0
        mvnge r0, #0
        movlt r0, #0
        PUSHDSP r0
        NEXT

@ : 0= 0 = ;
defcode "0=",2,,ZEQ
        POPDSP r1
        mov r0, #0
        cmp r1, r0
        mvneq r0, #0
        PUSHDSP r0
        NEXT

@ : 0<> 0 <> ;
defcode "0<>",3,,ZNEQ
        POPDSP r1
        mov r0, #0
        cmp r1, r0
        mvnne r0, #0
        PUSHDSP r0
        NEXT

@ : 0< 0 < ;
defcode "0<",2,,ZLT
        POPDSP r1
        mov r0, #0
        cmp r1, r0
        mvnlt r0, #0
        PUSHDSP r0
        NEXT

@ : 0> 0 > ;
defcode "0>",2,,ZGT
        POPDSP r1
        mov r0, #0
        cmp r1, r0
        mvngt r0, #0
        PUSHDSP r0
        NEXT

@ : 0<= 0 <= ;
defcode "0<=",3,,ZLE
        POPDSP r1
        mov r0, #0
        cmp r1, r0
        mvnle r0, #0
        PUSHDSP r0
        NEXT

@ : 0>= 0 >= ;
defcode "0>=",3,,ZGE
        POPDSP r1
        mov r0, #0
        cmp r1, r0
        mvnge r0, #0
        PUSHDSP r0
        NEXT

@ : NOT 0= ;
defcode "NOT",3,,NOT
        b code_ZEQ              @ same at 0=

@ AND ( a b -- a&b ) bitwise and
defcode "AND",3,,AND
        POP2 DSP                @ ( ), r1 = a, r0 = b
        and r0, r1, r0
        PUSHDSP r0
        NEXT

@ OR ( a b -- a|b ) bitwise or
defcode "OR",2,,OR
        POP2 DSP                @ ( ), r1 = a, r0 = b
        orr r0, r1, r0
        PUSHDSP r0
        NEXT

@ XOR ( a b -- a^b ) bitwise xor
defcode "XOR",3,,XOR
        POP2 DSP                @ ( ), r1 = a, r0 = b
        eor r0, r1, r0
        PUSHDSP r0
        NEXT

@ INVERT ( a -- ~a ) bitwise not
defcode "INVERT",6,,INVERT
        POPDSP r0
        mvn r0, r0
        PUSHDSP r0
        NEXT


@ LIT is used to compile literals in FORTH word.
@ When LIT is executed it pushes the literal (which is the next codeword)
@ into the stack and skips it (since the literal is not executable).
defcode "LIT", 3,, LIT
        ldr r1, [FIP], #4
        PUSHDSP r1
        NEXT

@ ! ( value address -- ) write value at address
defcode "!",1,,STORE
        POP2 DSP                @ ( ), r1 = value, r0 = address
        str r1, [r0]
        NEXT

@ @ ( address -- value ) reads value from address
defcode "@",1,,FETCH
        POPDSP r1
        ldr r0, [r1]
        PUSHDSP r0
        NEXT

@ +! ( amount address -- ) add amount to value at address
defcode "+!",2,,ADDSTORE
        POP2 DSP                @ ( ), r1 = amount, r0 = address
        ldr r2, [r0]
        add r2, r1
        str r2, [r0]
        NEXT

@ -! ( amount address -- ) subtract amount to value at address
defcode "-!",2,,SUBSTORE
        POP2 DSP                @ ( ), r1 = amount, r0 = address
        ldr r2, [r0]
        sub r2, r1
        str r2, [r0]
        NEXT

@ C! ( c addr -- ) write byte c at addr
defcode "C!",2,,STOREBYTE
        POP2 DSP                @ ( ), r1 = c, r0 = addr
        strb r1, [r0]
        NEXT

@ C@ ( addr -- c ) read byte from addr
defcode "C@",2,,FETCHBYTE
        POPDSP r1
        ldrb r0, [r1]
        PUSHDSP r0
        NEXT

@ CMOVE ( source dest length -- ) copy length bytes from source to dest
defcode "CMOVE",5,,CMOVE
        POP3 DSP                @ ( ), r2 = source, r1 = dest, r0 = length
        cmp r2, r1              @ account for potential overlap
        bge 2f                  @ copy forward if s >= d, backward otherwise
        sub r3, r0, #1          @ (length - 1)
        add r2, r3              @ end of source
        add r1, r3              @ end of dest
1:
        cmp r0, #0              @ while length > 0
        ble 3f
        ldrb r3, [r2], #-1      @    read character from source
        strb r3, [r1], #-1      @    and write it to dest (decrement both pointers)
        sub r0, r0, #1          @    decrement length
        b 1b
2:
        cmp r0, #0              @ while length > 0
        ble 3f
        ldrb r3, [r2], #1       @    read character from source
        strb r3, [r1], #1       @    and write it to dest (increment both pointers)
        sub r0, r0, #1          @    decrement length
        b 2b
3:
        NEXT

@ COUNT ( addr -- addr+1 c ) extract first byte (len) of counted string
defcode "COUNT",5,,COUNT
        POPDSP r0
        ldrb r1, [r0], #1       @ get byte and increment pointer
        PUSHDSP r0
        PUSHDSP r1
        NEXT

@ >R ( a -- ) move the top element from the data stack to the return stack
defcode ">R",2,,TOR
        POPDSP r0
        PUSHRSP r0
        NEXT

@ R> ( -- a ) move the top element from the return stack to the data stack
defcode "R>",2,,FROMR
        POPRSP r0
        PUSHDSP r0
        NEXT

@ RDROP drops the top element from the return stack
defcode "RDROP",5,,RDROP
        add RSP,RSP,#4
        NEXT

@ RSP@, RSP!, DSP@, DSP! manipulate the return and data stack pointers

defcode "RSP@",4,,RSPFETCH
        PUSHDSP RSP
        NEXT
@ I J are same, get copy of top and second or datastack for LOOP
defcode "I",1,,RSP2FETCH
        ldr r0, [RSP]       @ R ( J I  ), r0 = I
        PUSHDSP r0
        NEXT

defcode "J",1,,RSP3FETCH
        ldr r0, [RSP, #4]       @ R ( J I  ), r0 = J
        PUSHDSP r0
        NEXT

defcode "I!",2,,RSP2STORE
        POPDSP r0
        str r0, [RSP]       @ R ( J I ), r0 = I
        NEXT

defcode "J!",2,,RSP3STORE
        POPDSP r0
        str r0, [RSP, #4]       @ R ( J I ), r0 = J
        NEXT

defcode "RSP!",4,,RSPSTORE
        POPDSP RSP
        NEXT

defcode "DSP@",4,,DSPFETCH
        mov r0, DSP
        PUSHDSP r0
        NEXT

defcode "DSP!",4,,DSPSTORE
        POPDSP r0
        mov DSP, r0
        NEXT

@ KEY ( -- c ) Reads a character from stdin
defcode "KEY",3,,KEY
        bl getchar              @ r0 = getchar();
        PUSHDSP r0              @ push the return value on the stack
        NEXT

@ SETFB ( -- ) Sets new framebuffer with GPU
@ defcode "SETFB",5,,SETFB
@		bl FB_Init
@		NEXT

@ LOAD ( -- ) gets file name from keyboard, loads file as code
defcode "LOAD",4,,LOAD
		bl _WORD
		add		r1,r1,r0		@ r1 = len + r0 = address 
		ldr		r2,=0
		strb	r2,[r1]		@ null terminator
		bl loadfile
        NEXT

@ EMIT ( c -- ) Writes character c to stdout
defcode "EMIT",4,,EMIT
        POPDSP r0
        bl putchar              @ putchar(r0);
        NEXT

@ CR ( -- ) print newline
@ : CR '\n' EMIT ;
defcode "CR",2,,CR
        mov r0, #10
        bl putchar              @ putchar('\n');
        NEXT

@ SPACE ( -- ) print space
@ : SPACE BL EMIT ;  \ print space
defcode "SPACE",5,,SPACE
        mov r0, #32
        bl putchar              @ putchar(' ');
        NEXT

@ WORD ( -- addr length ) reads next word from stdin
@ skips spaces, control-characters and comments, limited to 32 characters
defcode "WORD",4,,WORD
        bl _WORD
        PUSHDSP r0              @ address
        PUSHDSP r1              @ length
        NEXT

_WORD:
        stmfd   sp!, {r6,lr}    @ preserve r6 and lr
1:
        bl getchar              @ read a character
        cmp r0, #'\\'
        beq 3f                  @ skip comments until end of line
        cmp r0, #' '
        ble 1b                  @ skip blank character

        ldr     r6, =word_buffer
2:
        strb r0, [r6], #1       @ store character in word buffer
        bl getchar              @ read more characters until a space is found
        cmp r0, #' '
        bgt 2b

        ldr r0, =word_buffer    @ r0, address of word
        sub r1, r6, r0          @ r1, length of word

        ldmfd sp!, {r6,lr}      @ restore r6 and lr
        bx lr
3:
        bl getchar              @ skip all characters until end of line
        cmp r0, #'\n'
        bne 3b
        b 1b

@ word_buffer for WORD
        .data
        .align 5                @ align to cache-line size
word_buffer:
        .space 32               @ FIXME: what about overflow!?

@ NUMBER ( addr length -- n e ) converts string to number
@ n is the parsed number
@ e is the number of unparsed characters
defcode "NUMBER",6,,NUMBER
        POPDSP r1
        POPDSP r0
        bl _NUMBER
        PUSHDSP r0
        PUSHDSP r1
        NEXT

_NUMBER:
        stmfd sp!, {r4-r6, lr}

        @ Save address of the string.
        mov r2, r0

        @ r0 will store the result after conversion.
        mov r0, #0

        @ Check if length is positive, otherwise this is an error.
        cmp r1, #0
        ble 5f

        @ Load current base.
        ldr r3, =var_BASE
        ldr r3, [r3]

        @ Load first character and increment pointer.
        ldrb r4, [r2], #1

        @ Check trailing '-'.
        mov r5, #0
        cmp r4, #45 @ 45 in '-' en ASCII
        @ Number is positive.
        bne 2f
        @ Number is negative.
        mov r5, #1
        sub r1, r1, #1

        @ Check if we have more than just '-' in the string.
        cmp r1, #0
        @ No, proceed with conversion.
        bgt 1f
        @ Error.
        mov r1, #1
        b 5f
1:
        @ number *= BASE
        @ Arithmetic shift right.
        @ On ARM we need to use an additional register for MUL.
        mul r6, r0, r3
        mov r0, r6

        @ Load the next character.
        ldrb r4, [r2], #1
2:
        @ Convert the character into a digit.
        sub r4, r4, #48 @ r4 = r4 - '0'
        cmp r4, #0
        blt 4f @ End, < 0
        cmp r4, #9
        ble 3f @ chiffre compris entre 0 et 9

        @ Test if hexadecimal character.
        sub r4, r4, #17 @ 17 = 'A' - '0'
        cmp r4, #0
        blt 4f @ End, < 'A'
        add r4, r4, #10
3:
        @ Compare to the current base.
        cmp r4, r3
        bge 4f @ End, > BASE

        @ Everything is fine.
        @ Add the digit to the result.
        add r0, r0, r4
        sub r1, r1, #1

        @ Continue processing while there are still characters to read.
        cmp r1, #0
        bgt 1b
4:
        @ Negate result if we had a '-'.
        cmp r5, #1
        rsbeq r0, r0, #0
5:
        @ Back to the caller.
        ldmfd sp!, {r4-r6, pc}


@ FIND ( addr length -- dictionary_address )
@ Tries to find a word in the dictionary and returns its address.
@ If the word is not found, NULL is returned.
defcode "FIND",4,,FIND
        POPDSP r1       @ length
        POPDSP r0       @ addr
        bl _FIND
        PUSHDSP r0
        NEXT

_FIND:
        stmfd   sp!, {r5,r6,r8,r9}      @ save callee save registers
        ldr r2, =var_LATEST
        ldr r3, [r2]                    @ get the last defined word address
1:
        cmp r3, #0                      @ did we check all the words ?
        beq 4f                          @ then exit

        ldrb r2, [r3, #4]               @ read the length field
        and r2, r2, #(F_HID|F_LEN)      @ keep only length + hidden bits
        cmp r2, r1                      @ do the lengths match ?
                                        @ (note that if a word is hidden,
                                        @  the test will be always negative)
        bne 3f                          @ branch if they do not match
                                        @ Now we compare strings characters
        mov r5, r0                      @ r5 contains searched string
        mov r6, r3                      @ r6 contains dict string
        add r6, r6, #5                  @ (we skip link and length fields)
                                        @ r2 contains the length

2:
        ldrb r8, [r5], #1               @ compare character per character
        ldrb r9, [r6], #1
        cmp r8,r9
        bne 3f                          @ if they do not match, branch to 3
        subs r2,r2,#1                   @ decrement length
        bne 2b                          @ loop

                                        @ here, strings are equal
        b 4f                            @ branch to 4

3:
        ldr r3, [r3]                    @ Mismatch, follow link to the next
        b 1b                            @ dictionary word
4:
        mov r0, r3                      @ move result to r0
        ldmfd   sp!, {r5,r6,r8,r9}      @ restore callee save registers
        bx lr

@ >CFA ( dictionary_address -- executable_address )
@ Transformat a dictionary address into a code field address
defcode ">CFA",4,,TCFA
        POPDSP r0
        bl _TCFA
        PUSHDSP r0
        NEXT

_TCFA:
        add r0,r0,#4            @ skip link field
        ldrb r1, [r0], #1       @ load and skip the length field
        and r1,r1,#F_LEN        @ keep only the length
        add r0,r0,r1            @ skip the name field
        add r0,r0,#3            @ find the next 4-byte boundary
        and r0,r0,#~3
        bx lr

@ >DFA ( dictionary_address -- data_field_address )
@ Return the address of the first data field
defcode ">DFA",4,,TDFA
        POPDSP r0
        bl _TCFA
        add r0,r0,#4            @ DFA follows CFA
        PUSHDSP r0
        NEXT

@ CREATE ( -- ) 
@ Creates a new dictionary entry in the data segment.
@ revised version calls WORD to get name, no stack items
@ this also needs to be 32bit aligned
defcode "CREATE",6,,CREATE
        @POPDSP r1       @ length of the word to insert into the dictionnary
        @POPDSP r0       @ address of the word to insert into the dictionnary
		bl	_WORD		@ get word and length
        ldr r2,=var_HERE
        ldr r3,[r2]     @ load into r3 and r8 the location of the header
        add r3,r3,#3            @ align to next 4 byte boundary
        and r3,r3,#~3
        mov r8,r3

        ldr r4,=var_LATEST
        ldr r5,[r4]     @ load into r5 the link pointer

        str r5,[r3]     @ store link here -> last

        add r3,r3,#4    @ skip link adress
        strb r1,[r3]    @ store the length of the word
        add r3,r3,#1    @ skip the length adress

        mov r7,#0       @ initialize the incrementation

1:
        cmp r7,r1       @ if the word is completley read
        beq 2f

        ldrb r6,[r0,r7] @ read and store a character
        strb r6,[r3,r7]

        add r7,r7,#1    @ ready to read the next character

        b 1b

2:
        add r3,r3,r7            @ skip the word

        add r3,r3,#3            @ align to next 4 byte boundary
        and r3,r3,#~3

        str r8,[r4]             @ update LATEST and HERE
        str r3,[r2]

        NEXT

@ , ( n -- ) writes the top element from the stack at HERE
defcode ",",1,,COMMA
        POPDSP r0
        bl _COMMA
        NEXT

_COMMA:
        ldr     r1, =var_HERE
        ldr     r2, [r1]        @ read HERE
        str     r0, [r2], #4    @ write value and increment address
        str     r2, [r1]        @ update HERE
        bx      lr

@ [ ( -- ) Change interpreter state to Immediate mode
defcode "[",1,F_IMM,LBRAC
        ldr     r0, =var_STATE
        mov     r1, #0                  @ FALSE
        str     r1, [r0]
        NEXT

@ ] ( -- ) Change interpreter state to Compilation mode
defcode "]",1,,RBRAC
        ldr     r0, =var_STATE
        mvn     r1, #0                  @ TRUE
        str     r1, [r0]
        NEXT

@ : word ( -- ) Define a new FORTH word
@ new version WORD is called inside CREATE
@ : : WORD CREATE DOCOL , LATEST @ HIDDEN ] ;
defword ":",1,,COLON
        @.int WORD                       @ Get the name of the new word
        .int CREATE                     @ CREATE the dictionary entry / header
        .int DOCOL, COMMA               @ Append DOCOL (the codeword).
        .int LATEST, FETCH, HIDDEN      @ Make the word hidden (see definition below).
        .int RBRAC                      @ Go into compile mode.
        .int EXIT                       @ Return from the function.

@ : ; IMMEDIATE LIT EXIT , LATEST @ HIDDEN [ ;
defword ";",1,F_IMM,SEMICOLON
        .int LIT, EXIT, COMMA           @ Append EXIT (so the word will return).
        .int LATEST, FETCH, HIDDEN      @ Unhide the word (hidden by COLON).
        .int LBRAC                      @ Go back to IMMEDIATE mode.
        .int EXIT                       @ Return from the function.

@ IMMEDIATE ( -- ) set IMMEDIATE flag of last defined word
defcode "IMMEDIATE",9,F_IMM,IMMEDIATE
        ldr r0, =var_LATEST     @ address of last word defined
        ldr r0, [r0]            @ get dictionary entry
        ldrb r1, [r0, #4]!      @ get len/flag byte
        orr r1, r1, #F_IMM      @ set F_IMMEDIATE
        strb r1, [r0]           @ update len/flag
        NEXT

@ HIDDEN ( dictionary_address -- ) toggle HIDDEN flag of a word
defcode "HIDDEN",6,,HIDDEN
        POPDSP  r0
        ldrb r1, [r0, #4]!      @ get len/flag byte
        eor r1, r1, #F_HID      @ toggle F_HIDDEN
        strb r1, [r0]           @ update len/flag
        NEXT

@ HIDE ( -- ) hide a word, FIND fails if already hidden
defword "HIDE",4,,HIDE
        .int WORD               @ Get the word (after HIDE).
        .int FIND               @ Look up in the dictionary.
        .int HIDDEN             @ Set F_HIDDEN flag.
        .int EXIT               @ Return.

@ ' ( -- ) returns the codeword address of next read word
@ only works in compile mode. Implementation is identical to LIT.
defcode "'",1,,TICK
        ldr r1, [FIP], #4
        PUSHDSP r1
        NEXT

@ LITERAL (C: value --) (S: -- value) compile `LIT value`
@ : LITERAL IMMEDIATE ' LIT , , ;  \ takes <word> from the stack and compiles LIT <word>
defword "LITERAL",7,F_IMM,LITERAL
        .int TICK, LIT, COMMA   @ compile 'LIT'
        .int COMMA              @ compile value
        .int EXIT               @ Return.

@ [COMPILE] word ( -- ) compile otherwise IMMEDIATE word
@ : [COMPILE] IMMEDIATE WORD FIND >CFA , ;
defword "[COMPILE]",9,F_IMM,BRKCOMPILE
        .int WORD               @ get the next word
        .int FIND               @ find it in the dictionary
        .int TCFA               @ get its codeword
        .int COMMA              @ and compile that
        .int EXIT               @ Return.

@ RECURSE ( -- ) compile recursive call to current word
@ : RECURSE IMMEDIATE LATEST @ >CFA , ;
defword "RECURSE",7,F_IMM,RECURSE
        .int LATEST, FETCH      @ LATEST points to the word being compiled at the moment
        .int TCFA               @ get the codeword
        .int COMMA              @ compile it
        .int EXIT               @ Return.

@ BRANCH ( -- ) changes FIP by offset which is found in the next codeword
defcode "BRANCH",6,,BRANCH
        ldr r1, [FIP]
        add FIP, FIP, r1
        NEXT

@ 0BRANCH ( p -- ) branch if the top of the stack is zero
defcode "0BRANCH",7,,ZBRANCH
        POPDSP r0
        cmp r0, #0              @ if the top of the stack is zero
        beq code_BRANCH         @ then branch
        add FIP, FIP, #4        @ else, skip the offset
        NEXT

@ IF true-part THEN ( p -- ) conditional execution
@ : IF IMMEDIATE ' 0BRANCH , HERE @ 0 , ;
defword "IF",2,F_IMM,IF
        .int TICK, ZBRANCH, COMMA       @ compile 0BRANCH
        .int HERE, FETCH                @ save location of the offset on the stack
        .int LIT, 0, COMMA              @ compile a dummy offset
        .int EXIT
@ : THEN IMMEDIATE DUP HERE @ SWAP - SWAP ! ;
defword "THEN",4,F_IMM,THEN
        .int DUP                        @ copy address saved on the stack
        .int HERE, FETCH, SWAP, SUB     @ calculate the offset
        .int SWAP, STORE                @ store the offset in the back-filled location
        .int EXIT
@ IF true-part ELSE false-part THEN ( p -- ) conditional execution
@ : ELSE IMMEDIATE ' BRANCH , HERE @ 0 , SWAP DUP HERE @ SWAP - SWAP ! ;
defword "ELSE",4,F_IMM,ELSE
        .int TICK, BRANCH, COMMA        @ definite branch to just over the false-part
        .int HERE, FETCH                @ save location of the offset on the stack
        .int LIT, 0, COMMA              @ compile a dummy offset
        .int SWAP                       @ now back-fill the original (IF) offset
        .int DUP                        @ same as for THEN word above...
        .int HERE, FETCH, SWAP, SUB
        .int SWAP, STORE
        .int EXIT
@ UNLESS false-part ... ( p -- ) same as `NOT IF`
@ : UNLESS IMMEDIATE ' NOT , [COMPILE] IF ;
defword "UNLESS",6,F_IMM,UNLESS
        .int TICK, NOT, COMMA           @ compile NOT (to reverse the test)
        .int IF                         @ continue by calling the normal IF
        .int EXIT

@ BEGIN loop-part p UNTIL ( -- ) post-test loop
@ : BEGIN IMMEDIATE HERE @ ;
defword "BEGIN",5,F_IMM,BEGIN
        .int HERE, FETCH                @ save location on the stack
        .int EXIT
@ : UNTIL IMMEDIATE ' 0BRANCH , HERE @ - , ;
defword "UNTIL",5,F_IMM,UNTIL
        .int TICK, ZBRANCH, COMMA       @ compile 0BRANCH
        .int HERE, FETCH, SUB           @ calculate offset saved location
        .int COMMA                      @ compile the offset here
        .int EXIT
@ BEGIN loop-part AGAIN ( -- ) infinite loop (until EXIT)
@ : AGAIN IMMEDIATE ' BRANCH , HERE @ - , ;
defword "AGAIN",5,F_IMM,AGAIN
        .int TICK, BRANCH, COMMA        @ compile BRANCH
        .int HERE, FETCH, SUB           @ calculate the offset back
        .int COMMA                      @ compile the offset here
        .int EXIT
@ BEGIN p WHILE loop-part REPEAT ( -- ) pre-test loop
@ : WHILE IMMEDIATE ' 0BRANCH , HERE @ 0 , ;
defword "WHILE",5,F_IMM,WHILE
        .int TICK, ZBRANCH, COMMA       @ compile 0BRANCH
        .int HERE, FETCH                @ save location of the offset2 on the stack
        .int LIT, 0, COMMA              @ compile a dummy offset2
        .int EXIT
@ : REPEAT IMMEDIATE ' BRANCH , SWAP HERE @ - , DUP HERE @ SWAP - SWAP ! ;
defword "REPEAT",6,F_IMM,REPEAT
        .int TICK, BRANCH, COMMA        @ compile BRANCH
        .int SWAP                       @ get the original offset (from BEGIN)
        .int HERE, FETCH, SUB, COMMA    @ and compile it after BRANCH
        .int DUP
        .int HERE, FETCH, SWAP, SUB     @ calculate the offset2
        .int SWAP, STORE                @ and back-fill it in the original location
        .int EXIT

@ CASE cases... default ENDCASE ( selector -- ) select case based on selector value
@ value OF case-body ENDOF ( -- ) execute case-body if (selector == value)
@ : CASE IMMEDIATE 0 ;
defword "CASE",4,F_IMM,CASE
        .int LIT, 0                     @ push 0 to mark the bottom of the stack
        .int EXIT
@ : OF IMMEDIATE ' OVER , ' = , [COMPILE] IF ' DROP , ;
defword "OF",2,F_IMM,OF
        .int TICK, OVER, COMMA          @ compile OVER
        .int TICK, EQ, COMMA            @ compile =
        .int IF                         @ compile IF
        .int TICK, DROP, COMMA          @ compile DROP
        .int EXIT
@ : ENDOF IMMEDIATE [COMPILE] ELSE ;
defword "ENDOF",5,F_IMM,ENDOF
        .int ELSE                       @ ENDOF is the same as ELSE
        .int EXIT
@ : ENDCASE IMMEDIATE ' DROP , BEGIN ?DUP WHILE [COMPILE] THEN REPEAT ;
defword "ENDCASE",7,F_IMM,ENDCASE
        .int TICK, DROP, COMMA          @ compile DROP
        .int QDUP, ZBRANCH, 16          @ while we're not at our zero marker
        .int THEN, BRANCH, -20          @     keep compiling THEN
        .int EXIT

@ LITS as LIT but for strings
defcode "LITS",4,,LITS
        ldr r0, [FIP], #4       @ read length
        PUSHDSP FIP             @ push address
        PUSHDSP r0              @ push string
        add FIP, FIP, r0        @ skip the string
        add FIP, FIP, #3        @ find the next 4-byte boundary
        and FIP, FIP, #~3
        NEXT

@ CONSTANT name ( value -- ) create named constant value
@ new version WORD is called in CREATE
@ : CONSTANT WORD CREATE DOCOL , ' LIT , , ' EXIT , ;
defword "CONSTANT",8,,CONSTANT
        @.int WORD               @ get the name (the name follows CONSTANT)
        .int CREATE             @ make the dictionary entry
        .int DOCOL, COMMA       @ append _DOCOL (the codeword field of this word)
        .int TICK, LIT, COMMA   @ append the codeword LIT
        .int COMMA              @ append the value on the top of the stack
        .int TICK, EXIT, COMMA  @ append the codeword EXIT
        .int EXIT               @ Return.

@ ALLOT ( n -- addr ) allocate n bytes of user memory
@ : ALLOT HERE @ SWAP HERE +! ;
defword "ALLOT",5,,ALLOT
        .int HERE, FETCH, SWAP  @ ( here n )
        .int HERE, ADDSTORE     @ adds n to HERE, the old value of HERE is still on the stack
        .int EXIT               @ Return.

@ CELLS ( n -- m ) number of bytes for n cells
@ : CELLS 4* ;
defword "CELLS",5,,CELLS
        .int MUL4               @ 4 bytes per cell
        .int EXIT               @ Return.

@ VARIABLE name ( -- addr ) create named variable location
@ new version WORD is called in CREATE
@ : VARIABLE 1 CELLS ALLOT WORD CREATE DOCOL , ' LIT , , ' EXIT , ;
defword "VARIABLE",8,,VARIABLE
        .int LIT, 4, ALLOT      @ allocate 1 cell of memory, push the pointer to this memory
        @.int WORD, 
		.int CREATE       @ make the dictionary entry (the name follows VARIABLE)
        .int DOCOL, COMMA       @ append _DOCOL (the codeword field of this word)
        .int TICK, LIT, COMMA   @ append the codeword LIT
        .int COMMA              @ append the pointer to the new memory
        .int TICK, EXIT, COMMA  @ append the codeword EXIT
        .int EXIT               @ Return.

@ TELL ( addr length -- ) writes a string to stdout
defcode "TELL",4,,TELL
        POPDSP r1               @ length
        POPDSP r0               @ address
        bl _TELL
        NEXT

_TELL:
        stmfd sp!, {r4-r5, lr}  @ stack save + return address
        mov r4, r0              @ address
        mov r5, r1              @ length
        b 2f
1:                              @ while (--r5 >= 0) {
        ldrb r0, [r4], #1       @     r0 = *r4++;
        bl putchar              @     putchar(r0);
2:                              @ }
        subs r5, r5, #1
        bge 1b
        ldmfd sp!, {r4-r5, pc}  @ stack restore + return

@ DIVMOD computes the unsigned integer division and remainder
@ The implementation is based upon the algorithm extracted from 'ARM Software
@ Development Toolkit User Guide v2.50' published by ARM in 1997-1998
@ The algorithm is split in two steps: search the biggest divisor b^(2^n)
@ lesser than a and then subtract it and all b^(2^i) (for i from 0 to n)
@ to a.
@ ( a b -- r q ) where a = q * b + r
defcode "/MOD",4,,DIVMOD
        POPDSP  r1                      @ Get b
        POPDSP  r0                      @ Get a
        bl _DIVMOD
        PUSHDSP r0                      @ Put r
        PUSHDSP r2                      @ Put q
        NEXT

@ on entry r0=numerator r1=denominator
@ on exit r0=remainder r1=denominator r2=quotient
_DIVMOD:                        @ Integer Divide/Modulus
        mov     r3, r1                  @ Put b in tmp

        cmp     r3, r0, LSR #1
1:      movls   r3, r3, LSL #1          @ Double tmp
        cmp     r3, r0, LSR #1
        bls     1b                      @ Jump until 2 * tmp > a

        mov     r2, #0                  @ Initialize q

2:      cmp     r0, r3                  @ If a - tmp > 0
        subcs   r0, r0, r3              @ a <= a - tmp
        adc     r2, r2, r2              @ Increment q
        mov     r3, r3, LSR #1          @ Halve tmp
        cmp     r3, r1                  @ Jump until tmp < b
        bhs     2b

        bx lr

@ on entry r0=integer r1=base
@ in-use r0=num/mod r1=base r2=div r3=tmp/dig r4=pad
@ on exit r0=addr r1=len r2=end
_UFMT:                          @ Unsigned Integer Formatting
        stmfd   sp!, {r4,lr}            @ save in-use registers
        ldr     r4, =scratch_pad_top    @ start beyond the PAD
        cmp     r0, r1                  @ if (num >= base)
        bhs     2f                      @ then, do DIVMOD first
        mov     r2, #0                  @ else, initial div = 0
1:
        subs    r3, r0, #10             @ tmp = num - 10
        addlt   r3, r0, #48             @ dig = '0' + num, if num < 10
        addge   r3, r3, #65             @ dig = 'A' + tmp, if num >= 10
        strb    r3, [r4, #-1]!          @ *(--pad) = dig
        movs    r0, r2                  @ num = div
        beq     3f                      @ if num == 0, we're done!
2:
        bl      _DIVMOD                 @ (num, base, -, -) ==> (mod, base, div, -)
        b       1b                      @ convert next digit
3:
        mov     r0, r4                  @ string address
        ldr     r2, =scratch_pad_top    @ get PAD end
        sub     r1, r2, r4              @ string length
        ldmfd   sp!, {r4,pc}            @ restore registers and return

@ U. ( u -- ) print unsigned number and a trailing space
defcode "U.",2,,UDOT
        POPDSP  r0                      @ number from stack
        ldr     r1, =var_BASE           @ address of BASE
        ldr     r1, [r1]                @ current value of BASE
        bl      _UDOT
        NEXT

@ on entry r0=number, r1=base
@ on exit r0=- r1=base
_UDOT:
        stmfd   sp!, {r1,lr}            @ save in-use registers
        bl      _UFMT                   @ (num, base, -, -) ==> (addr, len, end, -)
        bl      _TELL                   @ display number
        mov     r0, #32                 @ space character
        bl      putchar                 @ print trailing space
        ldmfd   sp!, {r1,pc}            @ restore registers and return

@ U.R ( u width -- ) print unsigned number, padded to width
defcode "U.R",3,,UDOTR
        ldr     r0, [DSP, #4]           @ number from stack
        ldr     r1, =var_BASE           @ address of BASE
        ldr     r1, [r1]                @ current value of BASE
        bl      _UFMT                   @ (num, base, -, -) ==> (addr, len, end, -)
        ldr     r2, [DSP]               @ width from stack
        bl      _DOTR                   @ (addr, len, width, -) ==> (addr, len, width, -)
        add     DSP, DSP, #8            @ remove number and width before return
        NEXT

@ on entry r0=integer r1=base
@ on exit r0=addr r1=len r2=end
_DFMT:                          @ Signed Integer Formatting
        stmfd   sp!, {lr}               @ save in-use registers
        movs    r0, r0                  @ check sign of number
        blt     1f                      @ if num < 0, jump to negative case
        bl      _UFMT                   @ (num, base, -, -) ==> (addr, len, end, -)
        ldmfd   sp!, {pc}               @ restore registers and return
1:
        rsb     r0, r0, #0              @ num = -num
        bl      _UFMT                   @ (num, base, -, -) ==> (addr, len, end, -)
        mov     r3, #45                 @ tmp = '-'
        strb    r3, [r0, #-1]!          @ *(--addr) = tmp
        add     r1, r1, #1              @ ++len
        ldmfd   sp!, {pc}               @ restore registers and return

@ . ( n -- ) print signed number and a trailing space
defcode ".",1,,DOT
        POPDSP  r0                      @ number from stack
        ldr     r1, =var_BASE           @ address of BASE
        ldr     r1, [r1]                @ current value of BASE
        bl      _DOT
        NEXT

@ on entry r0=number, r1=base
@ on exit r0=- r1=base
_DOT:
        stmfd   sp!, {r1,lr}            @ save in-use registers
        bl      _DFMT                   @ (num, base, -, -) ==> (addr, len, end, -)
        bl      _TELL                   @ display number
        mov     r0, #32                 @ space character
        bl      putchar                 @ print trailing space
        ldmfd   sp!, {r1,pc}            @ restore registers and return

@ .R ( n width -- ) print signed number, padded to width
defcode ".R",2,,DOTR
        ldr     r0, [DSP, #4]           @ number from stack
        ldr     r1, =var_BASE           @ address of BASE
        ldr     r1, [r1]                @ current value of BASE
        bl      _DFMT                   @ (num, base, -, -) ==> (addr, len, end, -)
        ldr     r2, [DSP]               @ width from stack
        bl      _DOTR                   @ (addr, len, width, -) ==> (addr, len, width, -)
        add     DSP, DSP, #8            @ remove number and width before return
        NEXT

@ on entry r0=addr r1=len r2=width
@ on exit r0=addr r1=len r2=width
_DOTR:                          @ Pad to field width
        stmfd   sp!, {lr}               @ save in-use registers
        mov     r3, #32                 @ space character
1:      cmp     r1, r2                  @ while (len < width) {
        strltb  r3, [r0, #-1]!          @     *(--addr) = ' ';
        addlt   r1, r1, #1              @     ++len;
        blt     1b                      @ }
        bl      _TELL                   @ display number
        ldmfd   sp!, {pc}               @ restore registers and return

@ ? ( addr -- ) fetch and print signed number at addr
@ : @ . ;
defword "?",1,,QUESTION
        .int FETCH
        .int DOT
        .int EXIT

@ DEPTH ( -- n ) the number of items on the stack
@ : DEPTH DSP@ S0 @ SWAP - 4 / ;
defcode "DEPTH",5,,DEPTH
        ldr     r0, =var_S0             @ address of stack origin
        ldr     r0, [r0]                @ stack origin value
        sub     r0, r0, DSP             @ number of bytes on stack
        mov     r0, r0, ASR #2          @ /4 to count cells
        PUSHDSP r0
        NEXT

@ .S ( -- ) print the contents of the stack (non-destructive)
defcode ".S",2,,DOTS
        mov     r0, DSP                 @ grab original stack top
        stmfd   sp!, {r4-r5}            @ save in-use registers (on the stack!)
        mov     r4, r0                  @ remember original top
        ldr     r5, =var_S0             @ address of stack origin
        ldr     r5, [r5]                @ location = stack origin
        ldr     r1, =var_BASE           @ address of BASE
        ldr     r1, [r1]                @ current value of BASE
        cmp     r1, #10                 @ if BASE is 10
        bne     2f                      @ print signed, otherwise unsigned
1:                                      @ LOOP {  // signed
        ldr     r0, [r5, #-4]!          @     item = *--location
        cmp     r5, r4                  @     if (location < top)
        blt     3f                      @         goto EXIT
        bl      _DOT                    @     print item (preserves r1)
        b       1b                      @ }
2:                                      @ LOOP {  // unsigned
        ldr     r0, [r5, #-4]!          @     item = *--location
        cmp     r5, r4                  @     if (location < top)
        blt     3f                      @         goto EXIT
        bl      _UDOT                   @     print item (preserves r1)
        b       2b                      @ }
3:                                      @ EXIT:
        ldmfd   sp!, {r4-r5}            @ restore registers (from the stack)
        NEXT


@ Alternative to DIVMOD: signed implementation using Euclidean division.
defcode "S/MOD",5,,SDIVMOD
        POPDSP r2                       @ Denominator
        POPDSP r1                       @ Numerator
        bl _SDIVMOD
        PUSHDSP r1                      @ Remainder
        PUSHDSP r0                      @ Quotient
        NEXT

_SDIVMOD:
        @ Division by 0.
        cmp r2, #0
        beq 4f

        @ r0 will store the quotient at the end.
        mov r0, #0

        @ r3 will be 1 if numerator and denominator have the same
        @ sign, -1 otherwise.
        @ r4 will be 1 if the numerator is positive, -1 otherwise.
        mov r3, #1
        mov r4, #1

        rsblt r3, r3, #0 @ r3 = -r3 if negative denominator
        rsblt r2, r2, #0 @ denominator = abs(denominator)

        cmp r1, #0
        rsblt r4, r4, #0 @ r4 = sign(numerator)
        rsblt r3, r3, #0 @ r3 = -r3 if negative numerator
        rsblt r1, r1, #0 @ numerator = abs(numerator)

        cmp r3, #-1
        beq 2f

1:      @ Case where denominator and numerator have the same sign.
        cmp r1, r2
        blt 3f
        11:
        add r0, r0, #1
        sub r1, r1, r2
        cmp r1, r2
        bge 11b

        b 3f

2:      @ Case where denominator and numerator have different sign.
        cmp r1, #0
        beq 3f
        21:
        sub r0, r0, #1
        sub r1, r1, r2
        cmp r1, #0
        bgt 21b

3:
        @ If numerator and denominator were negative:
        @ remainder = -remainder
        cmp r4, #-1
        rsbeq r1, r1, #0
        b 5f

4:      @ Error, division by 0.
        ldr r0, =errdiv0
        mov r1, #(errdiv0end-errdiv0)
        bl _TELL                        @ Display error message

5:
        bx lr

.section .rodata
errdiv0: .ascii "Division by 0!\n"
errdiv0end:

@ QUIT ( -- ) the first word to be executed
defword "QUIT", 4,, QUIT
        .int R0, RSPSTORE               @ Clear return stack
        .int S0, FETCH, DSPSTORE        @ Clear data stack
        .int INTERPRET                  @ Interpret a word
        .int BRANCH,-8                  @ LOOP FOREVER

@ INTERPRET, reads a word from stdin and executes or compiles it.
@ No need to backup callee save registers here,
@ since we are the top level routine!
defcode "INTERPRET",9,,INTERPRET
        ldr r12, =var_S0                @ address of stack origin
        ldr r12, [r12]                  @ stack origin value
        cmp r12, DSP                    @ check stack pointer against origin
        bge 7f                          @ go to 7, if stack is ok

    @ Stack Underflow
        mov sp, r12                     @ reset stack pointer
        ldr r0, =errstack
        mov r1, #(errstackend-errstack)
        bl _TELL                        @ Print error message

7:  @ Stack OK
        mov r8, #0                      @ interpret_is_lit = 0

        bl _WORD                        @ read a word from stdin
        mov r4, r0                      @ store it in r4,r5
        mov r5, r1

        bl _FIND                        @ find its dictionary entry
        cmp r0, #0                      @ if not found go to 1
        beq 1f

    @ Here the entry is found
        ldrb r6, [r0, #4]               @ read length and flags field
        bl _TCFA                        @ find code field address
        tst r6, #F_IMM                  @ if the word is immediate
        bne 4f                          @ branch to 4 (execute)
        b 2f                            @ otherwise, branch to 2

1:  @ Not found in dictionary
        mov r8, #1                      @ interpret_is_lit = 1
        mov r0, r4                      @ restore word
        mov r1, r5
        bl _NUMBER                      @ convert it to number
        cmp r1, #0                      @ if errors were found
        bne 6f                          @ then fail

    @ it's a literal
        mov r6, r0                      @ keep the parsed number if r6
        ldr r0, =LIT                    @ we will compile a LIT codeword

2:  @ Compiling or Executing
        ldr r1, =var_STATE              @ Are we compiling or executing ?
        ldr r1, [r1]
        cmp r1, #0
        beq 4f                          @ Go to 4 if in interpret mode

    @ Here in compile mode

        bl _COMMA                       @ Call comma to compile the codeword
        cmp r8, #1                      @ If it's a literal, we have to compile
        moveq r0, r6                    @ the integer ...
        bleq _COMMA                     @ .. too
        NEXT

4:  @ Executing
        cmp r8, #1                      @ if it's a literal, branch to 5
        beq 5f

                                        @ not a literal, execute now
        ldr r1, [r0]                    @ (it's important here that
        bx r1                           @  FIP address in r0, since _DOCOL
                                        @  assumes it)

5:  @ Push literal on the stack
        PUSHDSP r6
        NEXT

6:  @ Parse error
        ldr r0, =errpfx
        mov r1, #(errpfxend-errpfx)
        bl _TELL                        @ Begin error message

        mov r0, r4                      @ Address of offending word
        mov r1, r5                      @ Length of offending word
        bl _TELL

        ldr r0, =errsfx
        mov r1, #(errsfxend-errsfx)
        bl _TELL                        @ End error message

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

@ CHAR ( -- c ) ASCII code from first character of following word
defcode "CHAR",4,,CHAR
        bl _WORD
        ldrb r1, [r0]
        PUSHDSP r1
        NEXT

@ DECIMAL ( -- ) set number conversion BASE to 10
@ : DECIMAL ( -- ) 10 BASE ! ;
defcode "DECIMAL", 7,, DECIMAL
        mov     r0, #10
        ldr     r1, =var_BASE
        str     r0, [r1]
        NEXT

@ HEX ( -- ) set number conversion BASE to 16
@ : HEX ( -- ) 16 BASE ! ;
defcode "HEX", 3,, HEX
        mov     r0, #16
        ldr     r1, =var_BASE
        str     r0, [r1]
        NEXT

@ 10# value ( -- n ) interpret decimal literal value w/o changing BASE
@ : 10# BASE @ 10 BASE ! WORD NUMBER DROP SWAP BASE ! ;
defword "10#",3,,DECNUMBER
        .int BASE, FETCH
        .int LIT, 10, BASE, STORE
        .int WORD, NUMBER
        .int DROP, SWAP
        .int BASE, STORE
        .int EXIT

@ 16# value ( -- n ) interpret hexadecimal literal value w/o changing BASE
@ : 16# BASE @ 16 BASE ! WORD NUMBER DROP SWAP BASE ! ;
defword "16#",3,,HEXNUMBER
        .int BASE, FETCH
        .int LIT, 16, BASE, STORE
        .int WORD, NUMBER
        .int DROP, SWAP
        .int BASE, STORE
        .int EXIT

@ UPLOAD ( -- addr len ) XMODEM file upload to memory
defcode "UPLOAD",6,,UPLOAD
        ldr r0, =0x10000        @ Upload buffer address
        ldr r1, =0x7F00         @ Upload limit (32k - 256) bytes
        PUSHDSP r0              @ Push buffer address on the stack
        bl rcv_xmodem           @ r0 = rcv_xmodem(r0, r1);
        PUSHDSP r0              @ Push upload byte count on the stack
        NEXT

@ DUMP ( addr len -- ) Pretty-printed memory dump
defcode "DUMP",4,,DUMP
        POPDSP r1
        POPDSP r0
        bl hexdump              @ hexdump(r0, r1);
        NEXT

@ BOOT ( addr len -- ) Boot from memory image (see UPLOAD)
defcode "BOOT",4,,BOOT
        POP2 DSP                @ ( ), r1 = addr, r0 = len
        cmp r0, #0              @ len = 0 on upload failure
        bxgt r1                 @ jump to boot address if len > 0
        ldr r0, =errboot
        mov r1, #(errbootend-errboot)
        bl _TELL                @ write error message to console
        NEXT

.section 	.rodata
errboot: 	.ascii "Bad image!\n"
loadname: 	.ascii "forth.f\0"
errbootend:

@ MONITOR ( -- ) Enter bootstrap monitor
defcode "MONITOR",7,,MONITOR
        bl monitor              @ monitor();
        NEXT

@ EXECUTE ( xt -- ) jump to the address on the stack
@-- WARNING! THIS MUST BE THE LAST WORD DEFINED IN ASSEMBLY (see LATEST) --@
defcode "EXECUTE",7,,EXECUTE
        POPDSP r0
        ldr r1, [r0]
        bx r1

@ Reserve space for the return stack (1Kb)
        .bss
        .align 5                @ align to cache-line size
        .set RETURN_STACK_SIZE, 0x400
return_stack:
        .space RETURN_STACK_SIZE
return_stack_top:

@ Reserve space for new words and data structures (16Kb)
        .bss
        .align 5                @ align to cache-line size
        .set DATA_SEGMENT_SIZE, 0x4000
data_segment:
        .space DATA_SEGMENT_SIZE
data_segment_top:

@ Reserve space for scratch-pad buffer (128b)
        .bss
        .align 5                @ align to cache-line size
        .set SCRATCH_PAD_SIZE, 0x80
scratch_pad:
        .space SCRATCH_PAD_SIZE
scratch_pad_top:
