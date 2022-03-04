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
#include <string.h>

#include "accmem.h"
#include "lmalloc.h"

static int fd;


#if 1
typedef enum{
	invalid=0,
	allocated,
	translated,
}alloc_state;

typedef struct {
	uintptr_t pa;
	uintptr_t va;
	unsigned long len;
	unsigned long count;
        alloc_state s;
}cm_alloc_info;

cm_alloc_info cm_table[4096];
int last_valid_entry;
static int trans_count;
/* kernel mode calls */
unsigned int
find_alloc_entry(uintptr_t addr){
#if 0
	static unsigned int recent=0;
        uintptr_t va = cm_table[recent].va;
	uintptr_t va_end = cm_table[recent].va + cm_table[recent].len;
	if(va <= addr && va_end > addr){
		return recent;
        }
#endif
        uintptr_t va, va_end;

	//printf("last_valid_entry = %d\n", last_valid_entry);
	for(int i=0;i<last_valid_entry;i++){
		if(cm_table[i].s != invalid){
			va = cm_table[i].va;
			va_end = cm_table[i].va + cm_table[i].len;
	//		printf("va = %p and va_end=%p\n", va, va_end);
			if(va <= addr && va_end > addr){
				return i;
        		}
		}
	}
	return -1;
}

int
init_alloc_entry(uintptr_t addr, unsigned long len){
	if(last_valid_entry+1 < sizeof(cm_table)){
		cm_table[last_valid_entry].s = allocated;
		cm_table[last_valid_entry].va = addr;
		cm_table[last_valid_entry].len = len;
		cm_table[last_valid_entry].count = 0;
		last_valid_entry++;
		return 0;
        }
	return -1;
}

int
set_translated_addr(uintptr_t va, uintptr_t pa){
	unsigned int idx = find_alloc_entry(va);
	if(idx == -1){
		printf("No allocation done for 0x%p\n", (void *)va);
		return -1;
	}else{
		printf("set translated addr va=0x%p with pa=%p\n",(void *)va, (void *)pa);	
		cm_table[idx].s = translated;
		cm_table[idx].pa = pa;
		return 0;
	}
}

void
remove_alloc_entry(uintptr_t va){
	printf("remove_alloc_entry called for va=%p\n", (void *)va);
	unsigned int idx = find_alloc_entry(va);
	printf("removing entry for va =%p addr_tran hits = %ld\n",(void *)va,cm_table[idx].count);
	memset((void *)(&cm_table[idx]), 0, sizeof(cm_alloc_info));
	if(idx == last_valid_entry){
		while(last_valid_entry > 0 && cm_table[last_valid_entry-1].s == invalid){
			last_valid_entry--;
		}
        }
}

uintptr_t addr_tran(const void *addr)
{
	int ret;
	uintptr_t paddr = 0;
	unsigned int idx = find_alloc_entry((uintptr_t)addr);
	trans_count++;
	if(idx!=-1 && cm_table[idx].s==translated){
		paddr = cm_table[idx].pa + ((uintptr_t)addr  - cm_table[idx].va);
		cm_table[idx].count++;
                //printf("address hit %ld at with paddr = 0x%p base_pa = 0x%p req_va = 0x%p and base_va=0x%p\n",cm_table[idx].count,(void *)paddr,(void *)cm_table[idx].pa,addr,(void *)cm_table[idx].va);
	}else{
		if (!fd) fd = open("/dev/lmalloc", O_RDWR);
		ret = lma_tran(fd, &paddr, (void*)addr);
		if (ret < 0) {
			fprintf(stderr, "addr_tran() failed to access lmalloc driver\n");
			return (uintptr_t)NULL;
		}

		// fprintf(stderr, "addr_tran() vaddr: 0x%p, paddr: 0x%016lx\n", addr, paddr);
	}
	return paddr;
}

void *cm_alloc(size_t nbytes)
{
	void *ptr;

	printf("Called cm_alloc %ld\n", nbytes);
	if (!fd) fd = open("/dev/lmalloc", O_RDWR);
	if (lma_alloc(fd, &ptr, nbytes) < 0) {
		fprintf(stderr, "cm_alloc() failed to allocate memory\n");
		return NULL;
	}
        if(init_alloc_entry((uintptr_t)ptr, nbytes)==-1){
		printf("Failed to set entry in cm_tab for 0x%p\n", ptr);
	}else{
		uintptr_t pa = addr_tran(ptr);
		if(pa){
			printf("setting translated addr = 0x%p\n",(void *)pa);
			set_translated_addr((uintptr_t)ptr, pa);
		}
	}
	return ptr;
}

void cm_free(void *ptr)
{
	printf("CM_free called with ptr = %p\n",ptr);
	remove_alloc_entry((uintptr_t)ptr);
	printf("CM_free after remove alloc entry\n");
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
