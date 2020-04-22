/*
 * dre.c - data reorganization engine test
 *
 *  Created on: Jul 1, 2014
 *      Author: lloyd23
 */

#include <stdlib.h> /* strtoul */
#include <stdint.h> /* uint32_t */
#include <ctype.h> /* toupper, isalpha, isdigit */
#include <string.h> /* size_t, strlen */

#include "lime.h"

/* * * * * * * * * * I/O * * * * * * * * * */

#if defined(__microblaze__)
#define cprint(str)
#define cprintf(format, ...)
#elif defined(ZYNQ)
#include "xil_printf.h"
#define cprint(str) print(str)
#define cprintf(format, ...) xil_printf(format, ## __VA_ARGS__)
#else // not __microblaze__, ZYNQ
#include <stdio.h>
#define cprint(str) fprintf(stderr, str)
#define cprintf(format, ...) fprintf(stderr, format, ## __VA_ARGS__)
#endif

/* * * * * * * * * * Data Movement * * * * * * * * * */

#if defined(USE_DMAC)
#include <string.h> // memcpy, memset
#include "dmac_cmd.h"
#define smemcpy dmac_smemcpy
#define memcpy dmac_memcpy
// #define memset ::memset

#elif defined(USE_LSU)
#include <string.h> // memcpy, memset
#include "lsu_cmd.h"
#define smemcpy lsu_smemcpy
#define memcpy lsu_memcpy
// #define memset ::memset

#else // use CPU
#include <string.h> // memcpy, memset

void *smemcpy(void *dst, const void *src, size_t block_sz, size_t dst_inc, size_t src_inc, size_t n)
{
	register char *rdst = (char *)dst;
	register const char *rsrc = (const char *)src;
	while (n) {
		memcpy(rdst, rsrc, block_sz);
		rdst += dst_inc;
		rsrc += src_inc;
		n--;
	}
	return dst;
}

// #define memcpy ::memcpy
// #define memset ::memset
#endif // end USE_DMAC, USE_LSU, use CPU

/* * * * * * * * * * Stream Support * * * * * * * * * */

#if defined(USE_STREAM)
#include "aport.h"

#if defined(__microblaze__)
#define THIS_PN MCU0_PN
#else
#define THIS_PN ARM0_PN
#endif

#if defined(ZYNQ)
#include "xparameters.h"
#define STREAM_DEVICE_ID XPAR_AXI_FIFO_0_DEVICE_ID
#else
#define STREAM_DEVICE_ID 0
#endif

#define THIS_ID getID(THIS_PN)
#define LSU0_ID getID(LSU0_PN)

inline void dump_reg(void)
{
	int i;
	for (i = 0; i < 6; i++) cprintf(" LSU0_RD[%d]:%x\r\n", i, aport_read(LSU0_ID+READ_CH, THIS_ID, i));
	for (i = 0; i < 6; i++) cprintf(" LSU0_WR[%d]:%x\r\n", i, aport_read(LSU0_ID+WRITE_CH, THIS_ID, i));
}
#endif // USE_STREAM

/* * * * * * * * * * Main * * * * * * * * * */

#define MEM_WORDS 16
#define MSG_WORDS 4

// tsize*sfac determines largest memory allocation size
#define DEFAULT_TSIZE 512 // LSU transfer size
#define DEFAULT_SFAC 8 // LSU stride factor

#define DFLAG 0x01
#define dprintf(format, ...) if (flags & DFLAG) cprintf(format, ## __VA_ARGS__)

int flags; /* argument flags */
// char *sarg = DEFAULT_STR; /* string argument */
size_t tsize = DEFAULT_TSIZE; /* LSU transfer size */
unsigned sfac = DEFAULT_SFAC; /* LSU stride factor */

static unsigned long atoulk(const char *s)
{
	char *kptr;
	unsigned long num = strtoul(s, &kptr, 0);
	unsigned int k = (isalpha(kptr[0]) && toupper(kptr[1]) == 'I') ? 1024 : 1000;
	switch (toupper(*kptr)) {
	case 'K': num *= k; break;
	case 'M': num *= k*k; break;
	case 'G': num *= k*k*k; break;
	}
	return num;
}


int MAIN(int argc, char *argv[])
{
	int nok = 0;
	char *s;

	int status = 0;
#if defined(USE_STREAM)
	stream_t port;
#endif // end USE_STREAM
	void *MEM_SP;
	void *MEM_DRAM;

	while (--argc > 0 && (*++argv)[0] == '-')
		for (s = argv[0]+1; *s; s++)
			switch (*s) {
			case 'd':
				flags |= DFLAG;
				break;
#if 0
			case 's':
				sarg = s+1;
				s += strlen(s+1);
				break;
#endif
			case 's':
				if (isdigit(s[1])) sfac = atoulk(s+1);
				else nok = 1;
				s += strlen(s+1);
				break;
			case 't':
				if (isdigit(s[1])) tsize = atoulk(s+1);
				else nok = 1;
				s += strlen(s+1);
				break;
			default:
				nok = 1;
				cprintf(" -- not an option: %c\r\n", *s);
				break;
			}

	if (nok || argc > 0) {
		cprintf("Usage: dre {-flag} {-option<arg>} (example: dre -d -s4 -t16Mi)\r\n");
		cprintf("  -d  display errors\r\n");
		cprintf("  -s  LSU stride factor <int>, default %u\r\n", DEFAULT_SFAC);
		cprintf("  -t  LSU transfer size <int>, default %u\r\n", DEFAULT_TSIZE);
		cprintf("(stride fac. * trans. size) determines largest memory allocation\r\n");
		return(1);
	}

	MEM_SP = SP_NALLOC(char, tsize);
	chk_alloc(MEM_SP, tsize, "allocating MEM_SP");
	MEM_DRAM = NALLOC(char, tsize*sfac);
	chk_alloc(MEM_DRAM, tsize*sfac, "allocating MEM_DRAM");

	cprintf("########## DRE ##########\r\n");
	cprintf("transfer size: %ld\r\n", (unsigned long)tsize);
	cprintf("stride factor: %d\r\n", sfac);

#if !defined(__linux__)
	Xil_ICacheEnable();
	Xil_DCacheEnable();
#endif // end __linux__
	Xil_DCacheInvalidate();

	CLOCKS_EMULATE

	/* Test access to scratchpad memory */
	{
		const unsigned int len = MEM_WORDS;
		register unsigned int *ptr = (int unsigned *)MEM_SP;
		register unsigned int i;

		cprint("Scratchpad test... ");
		Xil_DCacheInvalidateRange((INTPTR)ptr, len*sizeof(int));
		for (i = 0; i < len; i++)
			ptr[i] = i;
		Xil_DCacheFlushRange((INTPTR)ptr, len*sizeof(int));

		for (i = 0; i < len; i++)
			if (ptr[i] != i) {
				dprintf("\r\ninit: %d, buf[%d]: %d ", i, i, ptr[i]);
				status |= 0x01;
			}
		if (status & 0x01) cprint("FAILED\r\n"); else cprint("PASSED\r\n");
	}

	/* Test access to DRAM memory */
	{
		const unsigned int len = MEM_WORDS;
		register unsigned int *ptr = (unsigned int *)MEM_DRAM;
		register unsigned int i;

		cprint("DRAM test... ");
		Xil_DCacheInvalidateRange((INTPTR)ptr, len*sizeof(int));
		for (i = 0; i < len; i++)
			ptr[i] = i;
		Xil_DCacheFlushRange((INTPTR)ptr, len*sizeof(int));

		for (i = 0; i < len; i++)
			if (ptr[i] != i) {
				dprintf("\r\ninit: %d, buf[%d]: %d ", i, i, ptr[i]);
				status |= 0x02;
			}
		if (status & 0x02) cprint("FAILED\r\n"); else cprint("PASSED\r\n");
	}

#if defined(USE_STREAM)
	/* Send message through stream interconnect and back */
	{
		unsigned int i, len;
		int res;
		uint32_t send_buf[MSG_WORDS];
		uint32_t recv_buf[MSG_WORDS];

		cprint("Stream message test... ");
		res = stream_init(&port, STREAM_DEVICE_ID);
		if (res != 0) status |= 0x04;

		send_buf[0] = (THIS_ID << 8) | (THIS_ID+1);
		for (i = 1; i < MSG_WORDS; i++)
			send_buf[i] = 0x01010101 * i;

		for (len = 2; len <= MSG_WORDS; len++) {
			memset(recv_buf, 0, sizeof(uint32_t)*len);
			stream_send(&port, send_buf, sizeof(uint32_t)*len, F_BEGP|F_ENDP);
			stream_recv(&port, recv_buf, sizeof(uint32_t)*len, F_BEGP|F_ENDP);

			for (i = 1; i < len; i++)
				if (send_buf[i] != recv_buf[i]) {
					dprintf("\r\nsend[%d]: 0x%x, recv[%d]: 0x%x ", i, send_buf[i], i, recv_buf[i]);
					status |= 0x08;
				}
		}
		if (status & 0x0C) cprint("FAILED\r\n"); else cprint("PASSED\r\n");
	}

	/* Ping load-store unit (LSU) */
	{
		unsigned int areg;

		cprint("Ping LSU test... ");
		lsu_setport(&port, LSU0_PN, THIS_PN);
		aport_write(LSU0_ID+1, THIS_ID+1, 0, 0, 0); /* clear status */
		areg = aport_read(LSU0_ID+1, THIS_ID+1, 0);
		if (areg != 0) status |= 0x10;
		if (status & 0x10) cprint("FAILED\r\n"); else cprint("PASSED\r\n");
	}
#endif // end USE_STREAM

	TRACE_START
	STATS_START

	/* Contiguous read and write by load-store unit */
	{
		const unsigned int len = tsize;
		char *src_buf = (char *)MEM_DRAM;
		char *dst_buf = (char *)MEM_SP;
		register unsigned int i;

		cprint("Contiguous read & write LSU test... ");
		Xil_DCacheInvalidateRange((INTPTR)src_buf, len);
		for (i = 0; i < len; i++) src_buf[i] = i & 0xFF;
		Xil_DCacheFlushRange((INTPTR)src_buf, len);

		Xil_DCacheInvalidateRange((INTPTR)dst_buf, len);
		memset(dst_buf, 0, len);
		Xil_DCacheFlushRange((INTPTR)dst_buf, len);

		TRACE_EVENT(0x1A)
		memcpy(dst_buf, src_buf, len);
		TRACE_EVENT(0x1B)
		Xil_DCacheInvalidateRange((INTPTR)dst_buf, len);

		for (i = 0; i < len; i++)
			if (src_buf[i] != dst_buf[i]) {
				dprintf("\r\nsrc[%d]: 0x%x, dst[%d]: 0x%x ", i, src_buf[i], i, dst_buf[i]);
				status |= 0x20;
			}

		if (status & 0x20) cprint("FAILED\r\n"); else cprint("PASSED\r\n");
	}

	/* Strided read and contiguous write by load-store unit */
	{
		typedef uint32_t elem_t;
		const unsigned int inc = sfac*sizeof(elem_t);
		const unsigned int len = tsize;
		const unsigned int n = tsize/sizeof(elem_t);
		elem_t *src_buf = (elem_t *)MEM_DRAM;
		elem_t *dst_buf = (elem_t *)MEM_SP;
		register unsigned int i, j;

		cprint("Strided read & contiguous write LSU test... ");
		Xil_DCacheInvalidateRange((INTPTR)src_buf, n*inc);
		for (i = 0; i < n; i++)
			for (j = 0; j < sfac; j++) 
				src_buf[i*sfac+j] = (j) ? ~i : i;
		Xil_DCacheFlushRange((INTPTR)src_buf, n*inc);

		Xil_DCacheInvalidateRange((INTPTR)dst_buf, len);
		memset(dst_buf, 0, len);
		Xil_DCacheFlushRange((INTPTR)dst_buf, len);

		TRACE_EVENT(0x2A)
		smemcpy(dst_buf, src_buf, sizeof(elem_t), sizeof(elem_t), inc, n);
		TRACE_EVENT(0x2B)
		Xil_DCacheInvalidateRange((INTPTR)dst_buf, len);

		for (i = 0; i < n; i++)
			if (src_buf[i*sfac] != dst_buf[i]) {
				dprintf("\r\nsrc[%d]: 0x%x, dst[%d]: 0x%x ", i*sfac, src_buf[i*sfac], i, dst_buf[i]);
				status |= 0x40;
			}

		if (status & 0x40) cprint("FAILED\r\n"); else cprint("PASSED\r\n");
	}

	Xil_DCacheFlush();
	STATS_STOP
	TRACE_STOP
	CLOCKS_NORMAL
	STATS_PRINT
	cprint("Done\r\n");

#if !defined(__linux__)
	Xil_DCacheDisable(); /* does a cache flush */
	Xil_ICacheDisable();
#endif // end __linux__

	TRACE_CAP
	return 0;
}
