/*
 * timer.h -- Raspberry Pi timer routines written in C
 */
#ifndef _TIMER_H_
#define _TIMER_H_

#include "raspi.h"

#define usecs   /* 1e-6 seconds */
#define msecs   * 1000 usecs
#define secs    * 1000 msecs

extern void     timer_init();                   /* initialize microsecond timer */
extern int      timer_usecs();                  /* read microsecond timer value */
extern int      timer_wait(int dt);             /* wait for dt microseconds */

#endif /* _TIMER_H_ */
