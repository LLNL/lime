/*
 * clocks.h
 *
 *  Created on: Dec 10, 2014
 *      Author: lloyd23
 */

#ifndef CLOCKS_H_
#define CLOCKS_H_

#include "config.h"

/* expects ticks.h to be included elsewhere */
#define tesec(f,s) ((_uns long long)tdiff(f,s)/(double)TICKS_ESEC)
#define tvesec(v) ((_uns long long)(v)/(double)TICKS_ESEC)

#if defined(CLOCKS)

#if !defined(T_W)
#define T_W 106 // Average DRAM Write, off-chip
#endif
#if !defined(T_R)
#define T_R  85 // Average DRAM Read, off-chip
#endif
#if !defined(T_TRANS)
#define T_TRANS 24 // 24 32 40
#endif
#define T_SRAM_W 12
#define T_SRAM_R 12
#define T_DRAM_W 45 // (T_W - T_TRANS) // 45
#define T_DRAM_R 45 // (T_R - T_TRANS) // 45
#define T_QUEUE_W (T_W - T_DRAM_W - T_TRANS) // 00 20 40
#define T_QUEUE_R (T_R - T_DRAM_R - T_TRANS) // 00 20 40

#define DISABLE_PWCLT   0x00000000

#define PWCLT_MU72      0x00000001
#define PWCLT_MU216     0x00000002
#define PWCLT_MU366     0x00000003
#define PWCLT_MU492     0x00000004
#define PWCLT_MU510     0x00000005
#define PWCLT_MU636     0x00000006
#define PWCLT_MU1056    0x00000007
#define PWCLT_MU1200    0x00000008
#define PWCLT_MU2256    0x00000009
#define PWCLT_MU2400    0x0000000A

#define PWCLT_STD_MUDIVBY4     0x00000000
#define PWCLT_STD_MUDIVBY8     0x00000010
#define PWCLT_STD_MUDIVBY16    0x00000020
#define PWCLT_STD_MUDIVBY32    0x00000030

#if defined(ZYNQ) && ZYNQ == _Z7_ && defined(XILTIME)
#define TICKS_ESEC (2571428546UL/2)
#else
#define TICKS_ESEC (TICKS_SEC*20UL)
#endif

#define CLOCKS_EMULATE clocks_emulate();
#define CLOCKS_NORMAL  clocks_normal();

#ifdef __cplusplus
extern "C" {
#endif

void clocks_emulate(void);
void clocks_normal(void);

#ifdef __cplusplus
}
#endif

#else /* not CLOCKS */

#define CLOCKS_EMULATE
#define CLOCKS_NORMAL
#define TICKS_ESEC TICKS_SEC

#endif /* end CLOCKS */

#endif /* end CLOCKS_H_ */
