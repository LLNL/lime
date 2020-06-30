/*
$Id: $

Description: Parse trace binary and convert to text

Input: Trace data in binary (bin) format
Output: Trace data in comma separated values (csv) format
Example: ./parser trace.bin trace.csv

$Log: $
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"

/* round up to next power of 2 */
#if FIFO_AXIS_TDATA_WIDTH <= 128
#define TCD_ENTRY_BITS 128
#elif FIFO_AXIS_TDATA_WIDTH <= 256
#define TCD_ENTRY_BITS 256
#elif FIFO_AXIS_TDATA_WIDTH <= 512
#define TCD_ENTRY_BITS 512
#elif FIFO_AXIS_TDATA_WIDTH <= 1024
#define TCD_ENTRY_BITS 1024
#else
#error "Trace entry too large."
#endif

/* include data in CSV output */
#define OUTPUT_DATA SHOW_AXI_DATA

/* trace definitions */
#define SW_ID 1
#define TRACE_ID 0

/* NOTE: could get from BSP xaxipmon.h */
#define XAPM_FLAG_WRADDR   0x00000001 /* Write Address Flag */
#define XAPM_FLAG_FIRSTWR  0x00000002 /* First Write Flag */
#define XAPM_FLAG_LASTWR   0x00000004 /* Last Write Flag */
#define XAPM_FLAG_RESPONSE 0x00000008 /* Response Flag */
#define XAPM_FLAG_RDADDR   0x00000010 /* Read Address Flag */
#define XAPM_FLAG_FIRSTRD  0x00000020 /* First Read Flag */
#define XAPM_FLAG_LASTRD   0x00000040 /* Last Read Flag */
#define XAPM_FLAG_MIDWR    0x00000080 /* Mid Write Flag */
#define XAPM_FLAG_MIDRD    0x00000100 /* Mid Read Flag */

#define XAPM_FLAG_WRDATA (XAPM_FLAG_FIRSTWR|XAPM_FLAG_MIDWR|XAPM_FLAG_LASTWR)
#define XAPM_FLAG_RDDATA (XAPM_FLAG_FIRSTRD|XAPM_FLAG_MIDRD|XAPM_FLAG_LASTRD)


unsigned next_uint(char **bit, unsigned len)
{
	unsigned num = 0;
	unsigned mask = 1;
	while (len--) {
		num |= (*(*bit)++) ? mask : 0;
		mask <<= 1;
	}
	return num;
}

void next_hexstr(char *str, char **bit, unsigned len)
{
	static char hex[] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
	str += (len ? (len+3)/4 : 1) + 2;
	*str-- = '\0';
	while (len > 4) {
		*str-- = hex[next_uint(bit, 4)];
		len -= 4;
	}
	*str-- = hex[next_uint(bit, len)];
	*str-- = 'x'; *str = '0';
}

unsigned parse_slot(FILE *wfp, char **cursor, int slot, sparam_t *spar, unsigned long time)
{
	unsigned flags;
	unsigned arlen, awlen;
	unsigned rid, arid, bid, awid;
	char araddr[(spar->AxADDR+3)/4+3];
	char awaddr[(spar->AxADDR+3)/4+3];
	char rdata[(spar->xDATA+3)/4+3];
	char wdata[(spar->xDATA+3)/4+3];
#if SHOW_AXI_DATA == 1 && OUTPUT_DATA == 1
	int dlen = sizeof(rdata);
#else
	int dlen = 0;
#endif

	next_uint(cursor, spar->EXT_EVENT);
	flags = next_uint(cursor, spar->FLAGS);
	arlen = (next_uint(cursor, spar->AxLEN)+1)*spar->xDATA/8;
	awlen = (next_uint(cursor, spar->AxLEN)+1)*spar->xDATA/8;
	rid = next_uint(cursor, spar->xxID);
	arid = next_uint(cursor, spar->xxID);
	bid = next_uint(cursor, spar->xxID);
	awid = next_uint(cursor, spar->xxID);
	next_hexstr(araddr, cursor, spar->AxADDR);
	next_hexstr(awaddr, cursor, spar->AxADDR);
#if SHOW_AXI_DATA == 1
	next_hexstr(rdata, cursor, spar->xDATA);
	next_hexstr(wdata, cursor, spar->xDATA);
#else
	strcpy(rdata, "NA");
	strcpy(wdata, "NA");
#endif

	/* five events per slot can occur at same time stamp */
	if (flags & XAPM_FLAG_WRADDR) {
		fprintf(wfp, "%u,W,%s,%.*s%u,%u,%lu\n", slot, awaddr, dlen, ",", awlen, awid, time);
	}
	if (flags & XAPM_FLAG_WRDATA) {
		char type[4];
		switch (flags & XAPM_FLAG_WRDATA) {
		case (XAPM_FLAG_FIRSTWR|XAPM_FLAG_LASTWR): strcpy(type, "DW"); break;
		case (XAPM_FLAG_FIRSTWR): strcpy(type, "FW"); break;
		case (XAPM_FLAG_MIDWR): strcpy(type, "MW"); break;
		case (XAPM_FLAG_LASTWR): strcpy(type, "LW"); break;
		default: fprintf(stderr, "ERROR: INCONSISTENT FLAGS:%#X SLOT:%u\n", flags, slot); return flags;
		}
		fprintf(wfp, "%u,%s,,%.*s%.*s,,%lu\n", slot, type, dlen, wdata, dlen, ",", time);
	}
	if (flags & XAPM_FLAG_RESPONSE) {
		fprintf(wfp, "%u,B,,%.*s,%u,%lu\n", slot, dlen, ",", bid, time);
	}
	if (flags & XAPM_FLAG_RDADDR) {
		fprintf(wfp, "%u,R,%s,%.*s%u,%u,%lu\n", slot, araddr, dlen, ",", arlen, arid, time);
	}
	if (flags & XAPM_FLAG_RDDATA) {
		char type[4];
		switch (flags & XAPM_FLAG_RDDATA) {
		case (XAPM_FLAG_FIRSTRD|XAPM_FLAG_LASTRD): strcpy(type, "DR"); break;
		case (XAPM_FLAG_FIRSTRD): strcpy(type, "FR"); break;
		case (XAPM_FLAG_MIDRD): strcpy(type, "MR"); break;
		case (XAPM_FLAG_LASTRD): strcpy(type, "LR"); break;
		default: fprintf(stderr, "ERROR: INCONSISTENT FLAGS:%#X SLOT:%u\n", flags, slot); return flags;
		}
		fprintf(wfp, "%u,%s,,%.*s%.*s,%u,%lu\n", slot, type, dlen, rdata, dlen, ",", rid, time);
	}
	return flags;
}

void parse_entry(FILE *wfp, char **cursor, sparam_t *spar, unsigned long *time)
{
	unsigned int logID;
	unsigned int loop;

	logID = next_uint(cursor, LOGID);
	*time += next_uint(cursor, TIMESTAMP);
	loop = next_uint(cursor, LOOP);
	if (loop == 1) fprintf(stderr, "WARNING: TIMING OVERFLOW\n");

	if (logID == SW_ID) {
		/* software event, parse identifier number */
		char SW[(SW_PACKET+3)/4+3];
		next_hexstr(SW, cursor, SW_PACKET);
		fprintf(wfp, "S,,%s,%.*s,,%lu\n", SW, OUTPUT_DATA, ",", *time);
	} else if (logID == TRACE_ID) {
		/* trace event, parse slot data */
		int i;
		unsigned orflags = 0;
		for (i = 0; i < NUM_MONITOR_SLOTS; i++) {
			orflags |= parse_slot(wfp, cursor, i, spar+i, *time);
		}
		if (orflags == 0) {
			fprintf(stderr, "ERROR: ENTRY WITH NO FLAGS\n");
		}
	}
}

int read_entry(FILE *rfp, char *entry)
{
	int i, val, tmp = 0;

	for (i = 0; i < TCD_ENTRY_BITS; i += 8) {
		/* read bytes from file */
		tmp |= val = fgetc(rfp);
		if (val == EOF) {
			fprintf(stderr, "TRACE END... EOF FOUND\n");
			return 0;
		}
		/* convert value to bits stored in char array */
		{
			char *bit = entry+i;
			int j;
			for (j = 0; j < 8; j++) bit[j] = (val & 1<<j)!=0;
		}
	}
	/* check for end of trace (tcd entry all zeros) */
	if (tmp == 0) {
		fprintf(stderr, "TRACE END... ZEROES FOUND\n");
		return 0;
	}
	return 1;
}


#ifndef VERSION
#define VERSION 2.0
#endif

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

#define DEFAULT_INT 1
#define DEFAULT_STR "ABC"

#define BFLAG 0x01

#define VFLAG 0x1000

int flags; /* boolean flags */
#if 0
int iarg = DEFAULT_INT; /* int argument */
char *sarg = DEFAULT_STR; /* string argument */
#endif


int main(int argc, char *argv[])
{
	int nok = 0;
	char *s;

	while (--argc > 0 && (*++argv)[0] == '-')
		for (s = argv[0]+1; *s; s++)
			switch (*s) {
#if 0
			case 'b':
				flags |= BFLAG;
				break;
			case 'i':
				if (isdigit(s[1])) iarg = atoi(s+1);
				else nok = 1;
				s += strlen(s+1);
				break;
			case 's':
				sarg = s+1;
				s += strlen(s+1);
				break;
#endif
			case 'v':
				flags |= VFLAG;
				break;
			default:
				nok = 1;
				fprintf(stderr, " -- not an option: %c\n", *s);
				break;
			}

	if (flags & VFLAG) fprintf(stderr, "Version: %s\n", TOSTRING(VERSION));
	if (nok || argc < 1 || (argc > 0 && *argv[0] == '?')) {
		fprintf(stderr, "Usage: parser -v [<in_file>] [<out_file>]\n");
#if 0
		/* -b -i<int> -s<str> */
		fprintf(stderr, "  -b  boolean flag\n");
		fprintf(stderr, "  -i  integer argument <int>, default: %d\n", DEFAULT_INT);
		fprintf(stderr, "  -s  string argument <str>, default: %s\n", DEFAULT_STR);
#endif
		fprintf(stderr, "  -v  version\n");
		exit(EXIT_FAILURE);
	}

	{
		FILE *fin, *fout;
		unsigned long timestamp;
		char tcd_entry[TCD_ENTRY_BITS];

		if (argc < 1) {
			fin = stdin;
		} else if ((fin = fopen(argv[0], "r")) == NULL) {
			fprintf(stderr, "ERROR: CANNOT OPEN INPUT FILE: %s\n", argv[0]);
			exit(EXIT_FAILURE);
		}
		if (argc < 2) {
			fout = stdout;
		} else if ((fout = fopen(argv[1], "w")) == NULL) {
			fprintf(stderr, "ERROR: CANNOT OPEN OUTPUT FILE: %s\n", argv[1]);
			exit(EXIT_FAILURE);
		}

		fprintf(stderr, "TRACE START...\n");
		for (timestamp = 0; read_entry(fin, tcd_entry); ) {
			char *cursor = tcd_entry;
			parse_entry(fout, &cursor, slot_param, &timestamp);
		}

		fclose(fin);
		fclose(fout);
	}
	return(EXIT_SUCCESS);
}
