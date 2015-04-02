@ Helper functions for the SD library


.globl memory_barrier
memory_barrier:
 mov r0, #0
 mcr p15, #0, r0, c7, c10, #5
 mov pc, lr

.globl quick_memcpy
quick_memcpy:
 push {r4-r9}
 mov r4, r0
 mov r5, r1

.loopb:
 ldmia r5!, {r6-r9}
 stmia r4!, {r6-r9}
 subs r2, #16
 bhi .loopb

 pop {r4-r9}
 mov pc, lr
