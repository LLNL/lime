/*
 * accmem.c - accelerator memory, linux
 *
 *  Created on: Mar 6, 2020
 *      Author: lloyd23
 */

#include <stdio.h> /* fopen, fread, fprintf, stderr */
#include <fcntl.h> /* open */
#include <sys/mman.h> /* mmap, mlock, MAP_FAILED */
#include <errno.h> /* errno */
#include <unistd.h> /* sysconf */

#include "accmem.h"
#include "lmalloc.h"

static int fd;


#if 1

/* kernel mode calls */

uintptr_t addr_tran(const void *addr)
{
	int ret;
	uintptr_t paddr = 0;

	if (!fd) fd = open("/dev/lmalloc", O_RDWR);
	ret = lma_tran(fd, &paddr, (void*)addr);
	if (ret < 0) {
		fprintf(stderr, "addr_tran() failed to access lmalloc driver\n");
	}

	// fprintf(stderr, "addr_tran() vaddr: 0x%p, paddr: 0x%016lx\n", addr, paddr);
	return paddr;
}

void *cm_alloc(size_t nbytes)
{
	void *ptr;

	if (!fd) fd = open("/dev/lmalloc", O_RDWR);
	if (lma_alloc(fd, &ptr, nbytes) < 0) {
		fprintf(stderr, "cm_alloc() failed to allocate memory\n");
		return NULL;
	}
	return ptr;
}

void cm_free(void *ptr)
{
	if (!fd) fd = open("/dev/lmalloc", O_RDWR);
	if (lma_free(fd, ptr) < 0) {
		fprintf(stderr, "cm_free() failed to access lmalloc driver\n");
	}
}

#else

/* user space calls */

uintptr_t addr_tran(const void *addr)
{
	FILE *pagemap;
	uintptr_t paddr = 0;
	long offset = ((uintptr_t)addr / sysconf(_SC_PAGESIZE)) * sizeof(uint64_t);
	uint64_t e;

	/* https://www.kernel.org/doc/Documentation/vm/pagemap.txt */
	if ((pagemap = fopen("/proc/self/pagemap", "rb"))) {
		if (fseek(pagemap, offset, SEEK_SET) == 0) {
			if (fread(&e, sizeof(uint64_t), 1, pagemap)) {
				if (e & (1ULL << 63)) { /* page present ? */
					paddr = e & ((1ULL << 54) - 1); /* pfn mask */
					paddr = paddr * sysconf(_SC_PAGESIZE);
					/* add offset within page */
					paddr = paddr | ((uintptr_t)addr & (sysconf(_SC_PAGESIZE) - 1));
				}
			}
		}
		fclose(pagemap);
	}

	// fprintf(stderr, "addr_tran() vaddr: 0x%p, paddr: 0x%016lx\n", addr, paddr);
	return paddr;
}

void *cm_alloc(size_t nbytes)
{
	void *ptr = MAP_FAILED;

	if (nbytes <= sysconf(_SC_PAGESIZE)) {
		ptr = mmap(NULL, nbytes, PROT_READ|PROT_WRITE, MAP_LOCKED|MAP_SHARED|MAP_ANONYMOUS, -1, 0);
	} else if (nbytes <= (2*1024*1024)) {
#if defined(MAP_HUGETLB)
		ptr = mmap(NULL, nbytes, PROT_READ|PROT_WRITE, MAP_LOCKED|MAP_SHARED|MAP_ANONYMOUS|MAP_HUGETLB, -1, 0);
#endif
	}
	if (ptr == MAP_FAILED) return NULL;
	return ptr;
}

void cm_free(void *ptr)
{
}

#endif

/* * * * * * * * * * Scratchpad * * * * * * * * * */

void *sp_alloc(size_t nbytes)
{
	return 0;
}

void sp_free(void *ptr)
{
}
