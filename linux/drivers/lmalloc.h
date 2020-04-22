/*
 * lmalloc.h - LiME allocation interface
 *
 * Copyright (c) 2020, Lawrence Livermore National Security, LLC.
 * Produced at the Lawrence Livermore National Laboratory.
 * Written by
 *   G. Scott Lloyd, lloyd23@llnl.gov
 *
 * LLNL-CODE-??????.
 * All rights reserved.
 * 
 * This file is part of LiME. For details, see
 * http://???/lime
 * Please also read – Additional ??? Notice.
 */

#ifndef LMALLOC_H_
#define LMALLOC_H_

#if defined(__KERNEL__)
#include <linux/types.h> /* size_t */

#else /* not __KERNEL__ */
#include <sys/mman.h> /* mmap, munmap */
#if !defined(MAP_LOCKED)
#define MAP_LOCKED 0
#warning "LiME memory allocations will not be locked"
#endif
#define __USE_LINUX_IOCTL_DEFS
#include <sys/ioctl.h> /* ioctl */
#endif /* end __KERNEL__ */

#define LMA_MAGIC 254

#define LMA_TRAN _IOWR(LMA_MAGIC, cmd_tran, lma_t)
#define LMA_FREE _IOW (LMA_MAGIC, cmd_free, lma_t)

typedef union {
	void *addr;
	uintptr_t paddr;
} lma_t;

typedef enum {
	cmd_tran,
	cmd_free
} lma_cmd_t;

#if defined(__cplusplus)
extern "C" {
#endif

#if !defined(__KERNEL__)

inline int lma_tran(int fd, uintptr_t* paddr, void* addr)
{
	int ret;
	lma_t lma;
	lma.addr = addr;
	ret = ioctl(fd, LMA_TRAN, &lma);
	*paddr = lma.paddr;
	return ret;
}

inline int lma_alloc(int fd, void** addr, size_t size)
{
	*addr = mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_LOCKED|MAP_SHARED, fd, 0);
	if (*addr == MAP_FAILED) return -1;
	return 0;
}

inline int lma_free(int fd, void* addr)
{
	lma_t lma;
	lma.addr = addr;
	return ioctl(fd, LMA_FREE, &lma);
}

#endif /* end __KERNEL__ */

#if defined(__cplusplus)
} /* end extern "C" */
#endif

#endif /* end LMALLOC_H_ */
