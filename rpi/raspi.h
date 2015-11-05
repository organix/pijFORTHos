/*
 * raspi.h -- Raspberry Pi kernel definitions
 */
#ifndef _RASPI_H_
#define _RASPI_H_

typedef unsigned char u8;
typedef unsigned int u32;

/* Declare ARM assembly-language helper functions */
extern void PUT_32(u32 addr, u32 data);
extern u32 GET_32(u32 addr);
extern void NO_OP();
extern void SPIN(u32 count);
extern void BRANCH_TO(u32 addr);

/* Macros to enhance efficiency */
#define PUT_32(addr, data)      (*((volatile u32*)(addr)) = (data))
#define GET_32(addr)            (*((volatile u32*)(addr)))

#endif /* _RASPI_H_ */
