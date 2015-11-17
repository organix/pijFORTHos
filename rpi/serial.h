/*
 * serial.h -- Raspberry Pi serial i/o (UART) routines written in C
 */
#ifndef _SERIAL_H_
#define _SERIAL_H_

#include "raspi.h"

extern void     serial_init();                  /* initialize serial UART */
extern int      serial_in_ready();              /* input ready != 0, wait == 0 */
extern int      serial_in();                    /* raw input from serial port */
extern int      serial_out_ready();             /* output ready != 0, wait == 0 */
extern int      serial_out(u8 data);            /* raw output to serial port */

extern int      serial_read();                  /* blocking read from serial port */
extern int      serial_write(u8 data);          /* blocking write to serial port */

extern void     serial_puts(char* s);           /* print C-string to serial port */
extern void     serial_rep(int c, int n);       /* print n repetitions of c */

#define serial_eol()    serial_puts("\r\n")

#endif /* _SERIAL_H_ */
