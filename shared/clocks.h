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

/******************************************************************************

Description of Values Printed from clocks_emulate()

The memory model currently used by LiME is similar to the HMC with 
extensions for near-memory components that reside on a base-die of a 3-D 
memory stack. The SRAM_X and DRAM_X numbers represent the average on-die 
latencies for SRAM and DRAM technology. For example, on the HMC, a DRAM 
vault can access a memory location in 45 ns. After queue delay at the vault, 
on-chip routing, and serdes link overhead, the off-chip latency is typically 
around 85 ns for a read. The listing below describes the memory timing values.

SRAM_X: On-chip latency at the point of access (e.g. SRAM on base-die)
DRAM_X: On-chip latency at the point of access (e.g. DRAM vault in HMC)
QUEUE_X: Delay caused by transactions waiting in a queue
TRANS: Transport delay through link from memory subsystem (e.g. serdes link)
W: Total write latency for host processor = DRAM_W + QUEUE_W + TRANS
R: Total read latency for host processor = DRAM_R + QUEUE_R + TRANS

The ARM_*, DDR_*, IO_*, and FPGA* values show the contents of clock control 
registers in the Zynq processor. These registers and their function are too 
detailed to document here, but a full description can be found in the Zynq 
technical reference manual. In a nutshell, these values can be used to 
verify and document that the clocks have been properly shifted when entering 
emulation mode.

The numbers printed for Slot 0 and Slot 1 show register values for the 
fixed-delay unit. They indicate the extra number of delay cycles added by 
the unit. Slot 0 is the AXI loopback path that originates with the ARM 
cores, loops through the programmable logic, and connects back into ports 
going to the system DRAM. Slot 1 is the AXI data path from the accelerator 
in programmable logic to a separate set of ports going to system DRAM. Each 
slot has two delay units that are useful in emulating two different memory 
technologies (e.g. SRAM and DRAM) in separate address ranges. Each of the 
fixed delay units has five separate delays, one for each AXI subchannel. 
Only two (B and R) are currently used during emulation. The B channel is for 
write responses and the R channel is for read responses and data.

Slot 0
CPU_SRAM_B: CPU SRAM write delay in cycles
CPU_SRAM_R: CPU SRAM read delay in cycles
CPU_DRAM_B: CPU DRAM write delay in cycles
CPU_DRAM_R: CPU DRAM read delay in cycles

Slot 1
ACC_SRAM_B: Accelerator SRAM write delay in cycles
ACC_SRAM_R: Accelerator SRAM read delay in cycles
ACC_DRAM_B: Accelerator DRAM write delay in cycles
ACC_DRAM_R: Accelerator DRAM read delay in cycles

******************************************************************************/
