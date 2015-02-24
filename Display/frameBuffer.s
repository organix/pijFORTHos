@ Frame buffer functions for piJFORTHos
@ Based on Baking Pi by Alex Chadwick
@ and Hello World Demo by krom (Peter Lemon)
@ License GPL3 - see license file
@ Written by David Stevenson Jan 2015

@ exported functions 
.global FB_Init
.global showchar

@ constants
PERIPHERAL_BASE = 0x20000000 	@ Peripheral Base Address
MAIL_BASE   	= 0xB880 		@ Mailbox Base Address
MAIL_READ   	= 0x0 			@ Mailbox Read Register
MAIL_CONFIG 	= 0x1C 			@ Mailbox Config Register
MAIL_STATUS 	= 0x18 			@ Mailbox Status Register
MAIL_WRITE  	= 0x20 			@ Mailbox Write Register
MAIL_FB      	= 0x1 			@ Mailbox Channel 1: Frame Buffer


@@@@@@@@@@@@@@@
@ set frame buffer by sending request to GPU 
@ note this only works once, TO DO: try using Release buffer to reset
@@@@@@@@@@@@@@
FB_Init:
	stmfd sp!, {r4-r5, lr}
	ldr r3,=var_SCREENX
	ldr r3,[r3]
	ldr r4,=var_SCREENY
	ldr r4,[r4]
	ldr r5,=var_SCREENDEPTH
	ldr r5,[r5]
	ldr r0,=PERIPHERAL_BASE+MAIL_BASE
	ldr r1,=FB_STRUCT
	str r3,[r1]					@ Frame Buffer Pixel Width
	str r3,[r1,#8]				@ Frame Buffer Virtual Pixel Width
	str r4,[r1,#4]				@ Frame Buffer Pixel Height
	str r4,[r1,#12]				@ Frame Buffer Virtual Pixel Height
	str r5,[r1,#20]				@ Frame Buffer Bits Per Pixel
	orr r1,#MAIL_FB
	str r1,[r0,#MAIL_WRITE] 	@ Mail Box Write

FB_Read:
    ldr r1,[r0,#MAIL_READ]
    tst r1,#MAIL_FB 			@ Test Frame Buffer Channel 1
    beq FB_Read 				@ Wait For Frame Buffer Channel 1 Data

	ldr r1,=FB_POINTER
	ldr r0,[r1] 				@ R0 = Frame Buffer Pointer
	cmp r0,#0 					@ Compare Frame Buffer Pointer To Zero
	beq FB_Init 				@ IF Zero Re-Initialize Frame Buffer
    ldmfd sp!, {r4-r5, pc}
	
@@@@@@@@@@	
@ show single char on screen r0=char r1=x r2=y
@@@@@@@@@@
showchar:
	cmp		r0,#127
	movhi 	pc,lr				@ invalid char so return
	stmfd 	sp!, {r4-r8, lr}
@ calc bytes per line
	ldr 	r3,=var_SCREENX
	ldr		r3,[r3]					@ r3 = pixels/screen line
	ldr 	r4,=var_SCREENDEPTH
	ldr 	r4,[r4]
	lsr		r4,#3					@ bytes / pixel = bpp/8      r4 = bytes / pixel
	mul		r3,r4					@ r3 = bytes / screen line
@ calc address of top left pixel to write
	ldr 	r5,=FB_POINTER			@ base address
	ldr		r5,[r5]
	mul		r2,r3					@ y * char_ht * bytes /line = byte offset
	add		r5,r2,lsl #3
	lsl		r1,#3					@ x * 8 width of char
	mul		r1,r4
	add		r1,r5					@ r1 = address to write to
@ calc address of char in font
	ldr		r6,=Font
	add		r6,r0,lsl #3			@ 8 bytes per char in font
	mov		r0,r6					@ address to use in r0
@ load colours	
	ldr		r2,=var_FG_COLOUR
	ldr		r2,[r2]
	ldr		r4,=var_BG_COLOUR
	ldr		r4,[r4]

@@@@@@ write char to buffer @@@@@
@ - half word version 16bit colour only!!
@ r0 = address of char in font
@ r1 = pixel address to write to
@ r2 = FG_colour
@ r3 = bytes/line
@ r4 = BG_colour
@ r7 = line index = 0
@ r5 = char font byte for this line
@ r6 = bit mask
	mov		r7,#0
lineloop:
	ldr		r6,=0b10000000
	mov		r8,#0
pixelloop:
	ldrb	r5,[r0,r7]			@ font data
	tst		r5,r6
	strneh	r2,[r1,r8]			@ FG
	streqh	r4,[r1,r8]			@ BG
	lsr		r6,#1				@ next bit of font
	add		r8,#2				@ next half word in buffer
	cmp		r6,#0
	bne		pixelloop
	add		r1,r3				@ next line on screen
	add		r7,#1				@ next byte in font
	cmp		r7,#8
	bne		lineloop
	ldmfd sp!, {r4-r8, pc}
		
	
@@@@ DATA @@@@@@@@
.ltorg
.align 4   					@ 16byte align
@ Frame Buffer Structure
FB_STRUCT: 
.4byte 0		 			@ Frame Buffer Pixel Width
.4byte 0					@ Frame Buffer Pixel Height
.4byte 0					@ Frame Buffer Virtual Pixel Width
.4byte 0					@ Frame Buffer Virtual Pixel Height
.4byte 0 					@ Frame Buffer Pitch (Set By GPU)
.4byte 0			 		@ Frame Buffer Bits Per Pixel
.4byte 0 					@ Frame Buffer Offset In X Direction
.4byte 0 					@ Frame Buffer Offset In Y Direction
FB_POINTER:
.4byte 0 					@ Frame Buffer Pointer (Set By GPU)
.4byte 0 					@ Frame Buffer Size (Set By GPU)

.align 2
Font:
  .incbin "font.bin"
  
