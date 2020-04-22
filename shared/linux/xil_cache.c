
#include <stdio.h> /* fprintf, stderr */
#include <fcntl.h> /* open */

#include "xil_cache.h"
#include "lmcache.h"

static int fd;


void Xil_DCacheEnable(void)
{
	fprintf(stderr, "Xil_DCacheEnable() not implemented\n");
}

void Xil_DCacheDisable(void)
{
	fprintf(stderr, "Xil_DCacheDisable() not implemented\n");
}

void Xil_DCacheInvalidate(void)
{
	int ret;
	if (!fd) fd = open("/dev/lmcache", O_RDWR);
	ret = lmc_d_invalidate(fd);
	if (ret < 0) {
		fprintf(stderr, "Xil_DCacheInvalidate() failed to access lmcache driver\n");
	}
}

void Xil_DCacheInvalidateRange(INTPTR adr, INTPTR len)
{
	int ret;
	if (!fd) fd = open("/dev/lmcache", O_RDWR);
	ret = lmc_d_invalidate_rng(fd, (void *)adr, (size_t)len);
	if (ret < 0) {
		fprintf(stderr, "Xil_DCacheInvalidateRange() failed to access lmcache driver\n");
	}
}

void Xil_DCacheInvalidateLine(INTPTR adr)
{
	fprintf(stderr, "Xil_DCacheInvalidateLine() not implemented\n");
}

void Xil_DCacheFlush(void)
{
	int ret;
	if (!fd) fd = open("/dev/lmcache", O_RDWR);
	ret = lmc_d_flush(fd);
	if (ret < 0) {
		fprintf(stderr, "Xil_DCacheFlush() failed to access lmcache driver\n");
	}
}

void Xil_DCacheFlushRange(INTPTR adr, INTPTR len)
{
	int ret;
	if (!fd) fd = open("/dev/lmcache", O_RDWR);
	ret = lmc_d_flush_rng(fd, (void *)adr, (size_t)len);
	if (ret < 0) {
		fprintf(stderr, "Xil_DCacheFlushRange() failed to access lmcache driver\n");
	}
}

void Xil_DCacheFlushLine(INTPTR adr)
{
	fprintf(stderr, "Xil_DCacheFlushLine() not implemented\n");
}


void Xil_ICacheEnable(void)
{
	fprintf(stderr, "Xil_ICacheEnable() not implemented\n");
}

void Xil_ICacheDisable(void)
{
	fprintf(stderr, "Xil_ICacheDisable() not implemented\n");
}

void Xil_ICacheInvalidate(void)
{
	fprintf(stderr, "Xil_ICacheInvalidate() not implemented\n");
}

void Xil_ICacheInvalidateRange(INTPTR adr, INTPTR len)
{
	fprintf(stderr, "Xil_ICacheInvalidateRange() not implemented\n");
}

void Xil_ICacheInvalidateLine(INTPTR adr)
{
	fprintf(stderr, "Xil_ICacheInvalidateLine() not implemented\n");
}

void Xil_ConfigureL1Prefetch(u8 num)
{
	fprintf(stderr, "Xil_ConfigureL1Prefetch() not implemented\n");
}
