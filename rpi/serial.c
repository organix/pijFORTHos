/*
 * serial.c -- Raspberry Pi serial i/o (UART) routines written in C
 *
 * Some of this code was inspired by bare-metal examples
 * from David Welch at https://github.com/dwelch67/raspberrypi
 */
#include "serial.h"

#define USE_SERIAL_UART0    /* select full UART for serial i/o */
//#define USE_SERIAL_UART1    /* select mini UART for serial i/o */

#define GPIO_BASE       0x20200000
#define GPFSEL1         (*((volatile u32*)(GPIO_BASE + 0x04)))
#define GPSET0          (*((volatile u32*)(GPIO_BASE + 0x1c)))
#define GPCLR0          (*((volatile u32*)(GPIO_BASE + 0x28)))
#define GPPUD           (*((volatile u32*)(GPIO_BASE + 0x94)))
#define GPPUDCLK0       (*((volatile u32*)(GPIO_BASE + 0x98)))

struct uart0 {
    u32         DR;     //_00;
    u32         RSRECR; //_04;
    u32         _08;
    u32         _0c;
    u32         _10;
    u32         _14;
    u32         FR;     //_18;
    u32         _1c;
    u32         ILPR;   //_20;
    u32         IBRD;   //_24;
    u32         FBRD;   //_28;
    u32         LCRH;   //_2c;
    u32         CR;     //_30;
    u32         IFLS;   //_34;
    u32         IMSC;   //_38;
    u32         RIS;    //_3c;
    u32         MIS;    //_40;
    u32         ICR;    //_44;
    u32         DMACR;  //_48;
};
#define UART0           ((volatile struct uart0 *)0x20201000)

struct uart1 {
    u32         _00;
    u32         AUXENB; //_04;
    u32         _08;
    u32         _0c;
    u32         _10;
    u32         _14;
    u32         _18;
    u32         _1c;
    u32         _20;
    u32         _24;
    u32         _28;
    u32         _2c;
    u32         _30;
    u32         _34;
    u32         _38;
    u32         _3c;
    u32         IO;     //_40;
    u32         IER;    //_44;
    u32         IIR;    //_48;
    u32         LCR;    //_4c;
    u32         MCR;    //_50;
    u32         LSR;    //_54;
    u32         MSR;    //_58;
    u32         _5c;
    u32         CNTL;   //_60;
    u32         STAT;   //_64;
    u32         BAUD;   //_68;
};
#define UART1           ((volatile struct uart1 *)0x20215000)

/*
 * Initialize serial UART to use GPIO pins 14 (TX) and 15 (RX)
 */
void
serial_init()
{
#ifdef USE_SERIAL_UART0
    u32 r0;

    UART0->CR = 0;

    r0 = GPFSEL1;
    r0 &= ~(7 << 12);           // gpio pin 14
    r0 |= 4 << 12;              //   alt0 = full UART transmit (TX)
    r0 &= ~(7 << 15);           // gpio pin 15
    r0 |= 4 << 15;              //   alt0 = full UART receive (RX)
    GPFSEL1 = r0;

    GPPUD = 0;
    SPIN(150);                  // wait for (at least) 150 clock cycles
    r0 = (1 << 14) | (1 << 15);
    GPPUDCLK0 = r0;
    SPIN(150);                  // wait for (at least) 150 clock cycles
    GPPUDCLK0 = 0;

    UART0->ICR = 0x7FF;
    UART0->IBRD = 1;
    UART0->FBRD = 40;
    UART0->LCRH = 0x70;
    UART0->CR = 0x301;
#endif /* USE_SERIAL_UART0 */
#ifdef USE_SERIAL_UART1
    u32 r0;

    UART1->AUXENB = 1;
    UART1->IER = 0;
    UART1->CNTL = 0;
    UART1->LCR = 3;
    UART1->MCR = 0;
    UART1->IER = 0;
    UART1->IIR = 0xc6;
    /* ((250,000,000 / 115200) / 8) - 1 = 270 */
    UART1->BAUD = 270;

    r0 = GPFSEL1;
    r0 &= ~(7 << 12);           // gpio pin 14
    r0 |= 2 << 12;              //   alt5 = mini UART transmit (TX)
    r0 &= ~(7 << 15);           // gpio pin 15
    r0 |= 2 << 15;              //   alt5 = mini UART receive (RX)
    GPFSEL1 = r0;

    GPPUD = 0;
    SPIN(150);                  // wait for (at least) 150 clock cycles
    r0 = (1 << 14) | (1 << 15);
    GPPUDCLK0 = r0;
    SPIN(150);                  // wait for (at least) 150 clock cycles
    GPPUDCLK0 = 0;

    UART1->CNTL = 3;
#endif /* USE_SERIAL_UART1 */
}

/*
 * Serial input ready != 0, wait == 0
 */
int
serial_in_ready()
{
#ifdef USE_SERIAL_UART0
    return (UART0->FR & 0x10) == 0;
#endif /* USE_SERIAL_UART0 */
#ifdef USE_SERIAL_UART1
    return (UART1->LSR & 0x01) != 0;
#endif /* USE_SERIAL_UART1 */
}

/*
 * Raw input from serial port
 */
int
serial_in()
{
#ifdef USE_SERIAL_UART0
    return UART0->DR & 0xff;
#endif /* USE_SERIAL_UART0 */
#ifdef USE_SERIAL_UART1
    return UART1->IO & 0xff;
#endif /* USE_SERIAL_UART1 */
}

/*
 * Serial output ready != 0, wait == 0
 */
int
serial_out_ready()
{
#ifdef USE_SERIAL_UART0
    return (UART0->FR & 0x20) == 0;
#endif /* USE_SERIAL_UART0 */
#ifdef USE_SERIAL_UART1
    return (UART1->LSR & 0x20) != 0;
#endif /* USE_SERIAL_UART1 */
}

/*
 * Raw output to serial port
 */
int
serial_out(u8 data)
{
#ifdef USE_SERIAL_UART0
    UART0->DR = (u32)data;
    return (int)data;
#endif /* USE_SERIAL_UART0 */
#ifdef USE_SERIAL_UART1
    UART1->IO = (u32)data);
    return (int)data;
#endif /* USE_SERIAL_UART1 */
}

/*
 * Blocking read from serial port
 */
int
serial_read()
{
    while (!serial_in_ready())
        ;
    return serial_in();
}

/*
 * Blocking write to serial port
 */
int
serial_write(u8 data)
{
    while (!serial_out_ready())
        ;
    return serial_out(data);
}

/*
 * Print a C-string, character-by-character
 */
void
serial_puts(char* s)
{
    int c;

    while ((c = *s++) != '\0') {
        serial_write((u8)c);
    }
}

/*
 * Print n repetitions of character c
 */
void
serial_rep(int c, int n)
{
    while (n-- > 0) {
        serial_write((u8)c);
    }
}
