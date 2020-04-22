/*
 * alloc.h - allocation support
 *
 *  Created on: Sep 16, 2014
 *      Author: lloyd23
 */

#ifndef ALLOC_H_
#define ALLOC_H_

/* Since cache management is done explicitly, allocations must be */
/* aligned to the cache line size which is 32 bytes for the ARM A9 */
/* and 64 bytes for the x86 and AArch64. */

#if !defined(ALIGN_SZ)
#if defined(__aarch64__)
// #define ALIGN_SZ 64
#define ALIGN_SZ 128 // match HMC MAX_BLOCK_SIZE
#else // not __aarch64__
#define ALIGN_SZ 32
#endif // end __aarch64__
#endif // end ALIGN_SZ

#define CEIL(n,s) ((((n)+((s)-1)) / (s)) * (s))
#define FLOOR(n,s) (((n) / (s)) * (s))

/* * * * * * * * * * NALLOC, NFREE * * * * * * * * * */

/* NOTE:
   use: void *aligned_alloc(size_t alignment, size_t size); (since C++11)
   when available instead of memalign(). Make sure "size" is also a multiple
   of the alignment.
*/
#if defined(SYSTEMC) && defined(__LP64__)
#define NALLOC(t,n) (t*)sbrk(CEIL((n)*sizeof(t),ALIGN_SZ))
#define NFREE(p)

#elif defined(USE_ACC) && defined(__linux__)
#include "accmem.h"
#define NALLOC(t,n) (t*)cm_alloc(CEIL((n)*sizeof(t),ALIGN_SZ))
#define NFREE(p) cm_free(p)

#elif defined(USE_ACC)
#include <malloc.h> // memalign, free
#define NALLOC(t,n) (t*)memalign(ALIGN_SZ,CEIL((n)*sizeof(t),ALIGN_SZ))
#define NFREE(p) free(p)

#else // not USE_ACC
#include <stdlib.h> // malloc, free
#define NALLOC(t,n) (t*)malloc((n)*sizeof(t))
#define NFREE(p) free(p)
#endif // end USE_ACC

/* * * * * * * * * * NEWA, DELETEA * * * * * * * * * */

#ifdef __cplusplus

#if defined(USE_ACC)
// FIXME: NEWA doesn't construct, only works for simple types
// TODO: make allocator for accelerator
#define ALLOCATOR(t)
#define NEWA(t,n) NALLOC(t,n)
#define DELETEA(p) NFREE(p)

#else // not USE_ACC
#include <memory> // std::allocator
#define ALLOCATOR(t) std::allocator<t>
#define NEWA(t,n) new t [n]
#define DELETEA(p) delete[] p
#endif // end USE_ACC

#endif // end __cplusplus

/* * * * * * * * * * SP_NALLOC, SP_NFREE * * * * * * * * * */

#if defined(USE_SP)
/* Scratch Pad (SP) memory is currently only supported on the emulator */
/* ARMv7-A only: Scratch Pad memory must not have L2 cache enabled. */
/* This means the ARM page table attribute must be outer non-cacheable. */
#include "accmem.h" // sp_alloc, sp_free, SP_SIZE
#define SP_NALLOC(t,n) (t*)sp_alloc(CEIL((n)*sizeof(t),ALIGN_SZ))
#define SP_NFREE(p) sp_free(p)

#else /* not USE_SP */
#define SP_NALLOC(t,n) NALLOC(t,n)
#define SP_NFREE(p) NFREE(p)
#define SP_SIZE 0x100000 // max from DRAM
#endif /* end USE_SP */

/* * * * * * * * * * SHOW_HEAP * * * * * * * * * */

#if defined(ZYNQ)
#ifdef __cplusplus
#include <cstdio> // printf
#include <cstdint> // intptr_t
extern "C" {void *_sbrk(intptr_t increment); void *sbrk(intptr_t increment);}
#else // not __cplusplus
#include <stdio.h> // printf
#include <stdint.h> // intptr_t
extern void *_sbrk(intptr_t increment); extern void *sbrk(intptr_t increment);
#endif // end __cplusplus
extern unsigned char _heap_start[];
extern unsigned char _heap_end[];
static inline void show_heap(void)
{
	unsigned char *_ptr = (unsigned char *)_sbrk(0);
	unsigned char *ptr = (unsigned char *)sbrk(0);
	printf("heap start:%p top:%p end:%p\ntotal:%tu used:%tu\n",
	_heap_start, _ptr, _heap_end, _heap_end - _heap_start, _ptr - _heap_start);
	if (ptr != _heap_start && ptr != _ptr) {
		printf(" -- warning: sbrk has been called and differs from _sbrk!\n");
		printf("heap start:%p top:%p end:%p\ntotal:%tu used:%tu\n",
		_heap_start, ptr, _heap_end, _heap_end - _heap_start, ptr - _heap_start);
	}
}
#define SHOW_HEAP show_heap();
#else /* not ZYNQ */
#define SHOW_HEAP
#endif /* end ZYNQ */

/* * * * * * * * * * chk_alloc * * * * * * * * * */

#if !defined(__microblaze__)
#include <stdio.h> /* fprintf */
#endif /* end __microblaze__ */

#include <stdlib.h> /* exit */

static inline void chk_alloc(const void *aptr, size_t nbytes, const char *str)
{
	if (aptr == NULL) {
#if !defined(__microblaze__)
		fprintf(stderr, " -- error: %s\n", str);
		fprintf(stderr, " -- need: %u bytes\n", (unsigned)nbytes);
#endif
		SHOW_HEAP
		exit(EXIT_FAILURE);
	}
	// else fprintf(stderr, "chk_alloc: %p %lu: %s\n", aptr, (unsigned long)nbytes, str);
}

#endif /* end ALLOC_H_ */
