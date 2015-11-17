/*
 * timer.c -- Raspberry Pi timer routines written in C
 *
 * Some of this code was inspired by bare-metal examples
 * from David Welch at https://github.com/dwelch67/raspberrypi
 */
#include "timer.h"

struct timer {
    u32         _00;
    u32         _04;
    u32         CTL;    //_08;
    u32         _0c;
    u32         _10;
    u32         _14;
    u32         _18;
    u32         _1c;
    u32         CNT;    //_20;
    u32         _24;
    u32         _28;
    u32         _2c;
};
#define TIMER           ((volatile struct timer *)0x2000b400)

/*
 * Initialize 1Mhz timer
 */
void
timer_init()
{
    TIMER->CTL = 0x00F90000;    // 0xF9+1 = 250
    TIMER->CTL = 0x00F90200;    // 250MHz/250 = 1MHz
}

/*
 * Get 1Mhz timer tick count (microseconds)
 */
int
timer_usecs()
{
    return TIMER->CNT;
}

/*
 * Delay loop (microseconds)
 */
int
timer_wait(int dt)
{
    int t0;
    int t1;

    t0 = timer_usecs();
    t1 = t0 + dt;
    for (;;) {
        t0 = timer_usecs();
        if ((t0 - t1) >= 0) {  // timeout
            return t0;
        }
    }
}
