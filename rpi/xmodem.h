/*
 * xmodem.h -- XMODEM file transfer
 */
#ifndef _XMODEM_H_
#define _XMODEM_H_

#include "raspi.h"

extern int      rcv_xmodem(u8* buf, int size);  /* receive into buffer, limited by size */

#endif /* _XMODEM_H_ */
