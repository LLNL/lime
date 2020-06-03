/*
 * accmem.h - accelerator memory
 *
 *  Created on: Mar 6, 2020
 *      Author: lloyd23
 */

#ifndef ACCMEM_H_
#define ACCMEM_H_

#include <stdlib.h> /* size_t */
#include <stdint.h> /* uintptr_t */

#if defined(USE_OCM)
/* SRAM low-latency timing, ADDR < 0x00100000 */

/* Use OCM for SP storage - ARMv7-A only */
// #define SP_ADDR 0x000000
// #define SP_SIZE 0x030000

/* Use DRAM for SP storage - with SRAM timing */
#define SP_ADDR 0x080000
#define SP_SIZE 0x080000

#else /* not USE_OCM */
/* DRAM higher-latency timing, ADDR >= 0x00100000 */

/* Use DRAM for SP storage */
#define SP_ADDR 0x100000
#define SP_SIZE 0x100000
#endif /* end USE_OCM */

#ifdef __cplusplus
extern "C" {
#endif

extern uintptr_t addr_tran(const void *addr);

extern void *cm_alloc(size_t nbytes);
extern void cm_free(void *ptr);

extern void *sp_alloc(size_t nbytes);
extern void sp_free(void *ptr);

#ifdef __cplusplus
}
#endif

#endif /* ACCMEM_H_ */
