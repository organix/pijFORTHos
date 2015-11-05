/*
 * xmodem.c -- XMODEM file transfer
 */
#include "xmodem.h"
#include "timer.h"
#include "serial.h"

#define SOH (0x01)  // Start of Header
#define ACK (0x06)  // Acknowledge
#define NAK (0x15)  // Negative Ack
#define EOT (0x04)  // End of Transmission
#define CAN (0x18)  // Cancel

int
rcv_timeout(int timeout)
{
    int t0;
    int t1;

    t0 = timer_usecs();
    t1 = t0 + timeout;
    for (;;) {
        if (serial_in_ready()) {
            return serial_in();
        }
        t0 = timer_usecs();
        if ((t0 - t1) >= 0) {  // timeout
            return -1;
        }
    }
}

#define CHAR_TIME   (250 msecs)  // wait 0.25 seconds per character

void
rcv_flush()
{
    while (rcv_timeout(CHAR_TIME) >= 0)
        ;
}

int
rcv_xmodem(u8* buf, int limit)
{
    int data;
    int rem;
    int len = 0;
    int chk;
    int blk = 0;
    int try = 0;
    int ok = NAK;

    limit -= 128;
    while (len <= limit) {  // make sure there is room to receive block
        if (ok == ACK) {
            try = 0;  // reset retry counter
        } else {
            rcv_flush();  // clear input
        }
        if (++try > 10) {  // retry 10 times on all errors
            break;  // FAIL!
        }
        serial_write(ok);
        ok = NAK;

        /* receive start-of-header (SOH) */
        data = rcv_timeout(3 secs);  // send NAK every 3 seconds 
        if (data < 0) {
            continue;  // retry
        } else if (data == EOT) {  // end-of-transmission
            serial_write(ACK);
            return len;  // SUCCESS! return total length of data in buffer
        } else if (data != SOH) {  // start-of-header
            continue;  // reject
        }

        /* receive block number */
        data = rcv_timeout(CHAR_TIME);
        if (data < 0) {
            continue;  // reject
        }
        if (data == (blk & 0xFF)) {  // previous block #
            rcv_flush();  // ignore duplicate block
            ok = ACK;  // acknowledge block
            continue;
        }
        if (data != ((blk + 1) & 0xFF)) {  // unexpected block
            rcv_flush();  // ignore unexpected block
            break;  // FAIL!
        }

        /* receive inverse block number */
        data = rcv_timeout(CHAR_TIME);
        if (data < 0) {
            continue;  // reject
        }
        if (data != (~(blk + 1) & 0xFF)) {  // block # mismatch
            continue;  // reject
        }

        /* receive block data (128 bytes) */
        chk = 0;  // checksum
        rem = 128;  // remaining count
        do {
            data = rcv_timeout(CHAR_TIME);
            if (data < 0) {
                break;  // timeout
            }
            buf[len++] = data;  // store data in buffer
            chk += data;  // accumulate checksum
        } while (--rem > 0);
        if (rem > 0) {  // incomplete block
            len -= (128 - rem);  // ignore partial block data
            continue;  // reject
        }

        /* receive checksum */
        data = rcv_timeout(CHAR_TIME);
        if ((data < 0) || (data != (chk & 0xFF))) {  // bad checksum
            len -= 128;  // ignore bad block data
            continue;  // reject
        }

        /* acknowledge good block */
        ok = ACK;
        ++blk;  // update expected block #
    }
    serial_write(CAN);  // I tell you three times...
    serial_write(CAN);
    serial_write(CAN);
    return 0;  // FAIL!
}
