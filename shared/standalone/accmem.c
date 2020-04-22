/*
 * accmem.c - accelerator memory, standalone
 *
 *  Created on: Jan 3, 2020
 *      Author: lloyd23
 */

/* Scratch Pad (SP) memory is currently only supported on the emulator */
/* ARMv7-A only: Scratch Pad memory must not have L2 cache enabled. */
/* This means the ARM page table attribute must be outer non-cacheable. */

#include <stdint.h> // uintptr_t
#include "alloc.h" // ALIGN_SZ, CEIL
#include "accmem.h"

#define SP_BEG ((((uintptr_t)&_heap_start) & ~(uintptr_t)0x3FFFFFFFUL) + SP_ADDR)
#define SP_END ((((uintptr_t)&_heap_start) & ~(uintptr_t)0x3FFFFFFFUL) + SP_ADDR + SP_SIZE)

extern unsigned char _heap_start[];

#if 0
/* These functions shouldn't be called because of redirection in alloc.h */
uintptr_t addr_tran(const void *addr)
{
	return 0;
}

void *cm_alloc(size_t nbytes)
{
	return 0;
}

void cm_free(void *ptr)
{
}
#endif

void *sp_alloc(size_t nbytes)
{
	static unsigned char *top = NULL;
	unsigned char *ptr;

	if (top == NULL) top = (unsigned char *)SP_BEG;
	ptr = top;
	if ((uintptr_t)ptr + nbytes > SP_END) return NULL;
	top += CEIL(nbytes, ALIGN_SZ);
	return ptr;
}

void sp_free(void *ptr)
{
}
