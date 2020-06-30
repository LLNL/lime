/*
 * lmcache.h - LiME cache interface
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

#ifndef LMCACHE_H_
#define LMCACHE_H_

#if defined(__KERNEL__)
#include <linux/types.h> /* size_t */

#else /* not __KERNEL__ */
// #include <sys/mman.h> /* mmap, munmap */
#define __USE_LINUX_IOCTL_DEFS
#include <sys/ioctl.h> /* ioctl */
#endif /* end __KERNEL__ */

#define LMC_MAGIC 255

#define LMC_D_FLUSH                _IO (LMC_MAGIC, cmd_d_flush)
#define LMC_D_FLUSH_RNG            _IOW(LMC_MAGIC, cmd_d_flush_rng, rng_t)
#define LMC_D_FLUSH_INVALIDATE     _IO (LMC_MAGIC, cmd_d_flush_invalidate)
#define LMC_D_FLUSH_INVALIDATE_RNG _IOW(LMC_MAGIC, cmd_d_flush_invalidate_rng, rng_t)
#define LMC_D_INVALIDATE           _IO (LMC_MAGIC, cmd_d_invalidate)
#define LMC_D_INVALIDATE_RNG       _IOW(LMC_MAGIC, cmd_d_invalidate_rng, rng_t)

typedef struct {
	void *addr;
	size_t size;
} rng_t;

typedef enum {
	cmd_d_flush,
	cmd_d_flush_rng,
	cmd_d_flush_invalidate,
	cmd_d_flush_invalidate_rng,
	cmd_d_invalidate,
	cmd_d_invalidate_rng
} lmc_cmd_t;

#if !defined(__KERNEL__)

static inline int lmc_d_flush(int fd)
{
	return ioctl(fd, LMC_D_FLUSH);
}

static inline int lmc_d_flush_rng(int fd, void *addr, size_t size)
{
	rng_t rng;
	rng.addr = addr;
	rng.size = size;
	return ioctl(fd, LMC_D_FLUSH_RNG, &rng);
}

static inline int lmc_d_flush_invalidate(int fd)
{
	return ioctl(fd, LMC_D_FLUSH_INVALIDATE);
}

static inline int lmc_d_flush_invalidate_rng(int fd, void *addr, size_t size)
{
	rng_t rng;
	rng.addr = addr;
	rng.size = size;
	return ioctl(fd, LMC_D_FLUSH_INVALIDATE_RNG, &rng);
}

static inline int lmc_d_invalidate(int fd)
{
	return ioctl(fd, LMC_D_INVALIDATE);
}

static inline int lmc_d_invalidate_rng(int fd, void *addr, size_t size)
{
	rng_t rng;
	rng.addr = addr;
	rng.size = size;
	return ioctl(fd, LMC_D_INVALIDATE_RNG, &rng);
}

#endif /* end __KERNEL__ */

#endif /* end LMCACHE_H_ */
