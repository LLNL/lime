//Portable C Parser for Xilinx Zynq TCD memory traces
//by: Kevin Cheng

// PROGRAM USAGE:
// gcc -O3 parser.c -o parser
// input: Trace Capture Device data in binary (bin)
// output: Trace Event in comma separated values format (csv)
// ./parser lsu.bin lsu.csv (or any binary file dump from Xilinx SDK)

#include <stdio.h>
#include <stdlib.h>

//output file options
#define EN_APM_DATA 0  //NOTE: Use "1" when APM data is present in trace, "0" when it is not

//system parameter widths
#define APM_SLOTS 2

//PARAMETER LENGTHS
#define LOGID_LEN 1
#define TIMESTAMP_LEN 30
#define LOOP_LEN 1
#define SW_PACKET_LEN 32
#define EXT_EVENT_LEN 3

#define WRITE_ADDR_LATCH_LEN 1
#define FIRST_WR_LEN 1
#define LAST_WR_LEN 1
#define RESPONSE_LEN 1
#define READ_ADDR_LATCH_LEN 1
#define FIRST_RD_LEN 1
#define LAST_RD_LEN 1
#define MID_WR_LEN 1
#define MID_RD_LEN 1

#define A0_ID 16
#define A0_ARLEN 8
#define A0_AWLEN 8
#define A0_RID A0_ID
#define A0_ARID A0_ID
#define A0_BID A0_ID
#define A0_AWID A0_ID
#define A0_ARADDR 40
#define A0_AWADDR 40
#define A0_RDATA_LO 64
#define A0_RDATA_HI 64
#define A0_WDATA_LO 64
#define A0_WDATA_HI 64

#define A1_ID 3
#define A1_ARLEN 8
#define A1_AWLEN 8
#define A1_RID A1_ID
#define A1_ARID A1_ID
#define A1_BID A1_ID
#define A1_AWID A1_ID
#define A1_RADDR 40
#define A1_WADDR 40
#define A1_RDATA 64
#define A1_WDATA 64

//default system parameters
#define SW_ID 1
#define TRACE_ID 0
#define BYTE 8

unsigned long long int nextfield(char **a, unsigned int len);
char *int2string(unsigned input_int);


int main(int argc, char *argv[])
{
	unsigned int STREAM_SIZE;
    if (!EN_APM_DATA) {
		STREAM_SIZE = 512;
	}
	else {
		STREAM_SIZE = 1024;
	}

	printf("TRACE START..\n");

	//OPEN INPUT/OUTPUT FILES
	FILE *readfp, *writefp;
	readfp = fopen(argv[1],"r");
	writefp = fopen(argv[2],"w+");
	if (!readfp) {
		printf("ERROR: CANNOT FIND FILE\n");
		return 0;
	}

	char *TCD_BYTE = (char*) malloc(sizeof(char)*BYTE);
	char bitstream[STREAM_SIZE];

	unsigned long timestamp = 0;

	while (1) {
		int i, k, val;
		//READ BYTES FROM FILE
		for (k = STREAM_SIZE-8; k >= 0; k = k-8) {
			val = fgetc(readfp);
			if (val == EOF) {
				printf("TRACE END....EOF FOUND\n");
				goto term;
			}
			TCD_BYTE = int2string(val);
			for (i = 0; i < 8; i++) {
				 bitstream[i+k] = TCD_BYTE[i];
			}
		}

		//CHECK FOR END OF TRACE
		for (k = 0; k < STREAM_SIZE && bitstream[k] == '0'; k++) ;
		if (k == STREAM_SIZE) {
			printf("TRACE END....ZEROES FOUND\n");
			goto term;
		}

		//-----------------START PARSING--------------------------
		char *cursor = &bitstream[STREAM_SIZE-1];

		unsigned int logID = nextfield(&cursor,LOGID_LEN);
		timestamp += nextfield(&cursor,TIMESTAMP_LEN);
		unsigned int loop = nextfield(&cursor,LOOP_LEN);
		if (loop == 1) printf("WARNING: TIMING OVERFLOW\n");

		if (logID == SW_ID) {
			//SW TRACE PARSING
			unsigned int SW = nextfield(&cursor,SW_PACKET_LEN);
			fprintf(writefp, "S,,0x%X,,,%lu\n",SW,timestamp);
		} else if (logID == TRACE_ID) {
			//APM0 PARSING
			unsigned int a0_ext_event = nextfield(&cursor,EXT_EVENT_LEN);
			unsigned int a0_wr_addr_latch = nextfield(&cursor,WRITE_ADDR_LATCH_LEN);
			unsigned int a0_first_wr = nextfield(&cursor,FIRST_WR_LEN);
			unsigned int a0_last_wr = nextfield(&cursor,LAST_WR_LEN);
			unsigned int a0_response = nextfield(&cursor,RESPONSE_LEN);
			unsigned int a0_rd_addr_latch = nextfield(&cursor,READ_ADDR_LATCH_LEN);
			unsigned int a0_first_rd = nextfield(&cursor,FIRST_RD_LEN);
			unsigned int a0_last_rd = nextfield(&cursor,LAST_RD_LEN);
			unsigned int a0_mid_wr = nextfield(&cursor,MID_WR_LEN);
			unsigned int a0_mid_rd = nextfield(&cursor,MID_RD_LEN);
			unsigned int a0_arlen = (nextfield(&cursor,A0_ARLEN)+1)*16;
			unsigned int a0_awlen = (nextfield(&cursor,A0_AWLEN)+1)*16;
			unsigned int a0_rid = nextfield(&cursor,A0_RID);
			unsigned int a0_arid = nextfield(&cursor,A0_ARID);
			unsigned int a0_bid = nextfield(&cursor,A0_BID);
			unsigned int a0_awid = nextfield(&cursor,A0_AWID);
			unsigned long long int a0_araddr = nextfield(&cursor,A0_ARADDR);
			unsigned long long int a0_awaddr = nextfield(&cursor,A0_AWADDR);
			unsigned long long int  a0_ardata_lo = nextfield(&cursor,A0_RDATA_LO);
			unsigned long long int  a0_ardata_hi = nextfield(&cursor,A0_RDATA_HI);
			unsigned long long int  a0_awdata_lo = nextfield(&cursor,A0_WDATA_LO);
			unsigned long long int  a0_awdata_hi = nextfield(&cursor,A0_WDATA_HI);

			//APM1 PARSING
			unsigned int a1_ext_event = nextfield(&cursor,EXT_EVENT_LEN);
			unsigned int a1_wr_addr_latch = nextfield(&cursor,WRITE_ADDR_LATCH_LEN);
			unsigned int a1_first_wr = nextfield(&cursor,FIRST_WR_LEN);
			unsigned int a1_last_wr = nextfield(&cursor,LAST_WR_LEN);
			unsigned int a1_response = nextfield(&cursor,RESPONSE_LEN);
			unsigned int a1_rd_addr_latch = nextfield(&cursor,READ_ADDR_LATCH_LEN);
			unsigned int a1_first_rd = nextfield(&cursor,FIRST_RD_LEN);
			unsigned int a1_last_rd = nextfield(&cursor,LAST_RD_LEN);
			unsigned int a1_mid_wr = nextfield(&cursor,MID_WR_LEN);
			unsigned int a1_mid_rd = nextfield(&cursor,MID_RD_LEN);
			unsigned int a1_arlen = (nextfield(&cursor,A1_ARLEN)+1)*8;
			unsigned int a1_awlen = (nextfield(&cursor,A1_AWLEN)+1)*8;
			unsigned int a1_rid = nextfield(&cursor,A1_RID);
			unsigned int a1_arid = nextfield(&cursor,A1_ARID);
			unsigned int a1_bid = nextfield(&cursor,A1_BID);
			unsigned int a1_awid = nextfield(&cursor,A1_AWID);
			unsigned long long int a1_araddr = nextfield(&cursor,A1_RADDR);
			unsigned long long int a1_awaddr = nextfield(&cursor,A1_WADDR);
			unsigned long long int a1_ardata = nextfield(&cursor,A1_RDATA);
			unsigned long long int a1_awdata = nextfield(&cursor,A1_WDATA);

			//APM0 FILE WRITE
			if (EN_APM_DATA == 1) {
			    if (a0_wr_addr_latch == 1) {
			    	fprintf(writefp,"0,W,0x%010llX,,%u,%u,%lu\n",a0_awaddr,a0_awlen,a0_awid,timestamp);
			    }
			    if (a0_first_wr == 1) {
			    	fprintf(writefp,"0,FW,,0x%016llX%016llX,,,%lu\n",a0_awdata_hi,a0_awdata_lo,timestamp);
			    }
			    if (a0_last_wr == 1) {
			    	fprintf(writefp,"0,LW,,0x%016llX%016llX,,,%lu\n",a0_awdata_hi,a0_awdata_lo,timestamp);
			    }
			    if (a0_response == 1) {
			    	fprintf(writefp,"0,B,,,,%u,%lu\n",a0_bid,timestamp);
			    }
			    if (a0_rd_addr_latch == 1) {
			    	fprintf(writefp,"0,R,0x%010llX,,%u,%u,%lu\n",a0_araddr,a0_arlen,a0_arid,timestamp);
			    }
			    if (a0_first_rd == 1) {
			    	fprintf(writefp,"0,FR,,0x%016llX%016llX,,%u,%lu\n",a0_ardata_hi,a0_ardata_lo,a0_rid,timestamp);
			    }
			    if (a0_last_rd == 1) {
			    	fprintf(writefp,"0,LR,,0x%016llX%016llX,,%u,%lu\n",a0_ardata_hi,a0_ardata_lo,a0_rid,timestamp);
			    }
			    if (a0_mid_wr == 1) {
			    	fprintf(writefp,"0,MW,,0x%016llX%016llX,,,%lu\n",a0_awdata_hi,a0_awdata_lo,timestamp);
			    }
			    if (a0_mid_rd == 1) {
			    	fprintf(writefp,"0,MR,,0x%016llX%016llX,,%u,%lu\n",a0_ardata_hi,a0_ardata_lo,a0_rid,timestamp);
			    }
			}
			else {
			    if (a0_wr_addr_latch == 1) {
			    	fprintf(writefp,"0,W,0x%010llX,%u,%u,%lu\n",a0_awaddr,a0_awlen,a0_awid,timestamp);
			    }
			    if (a0_first_wr == 1) {
			    	fprintf(writefp,"0,FW,,,,%lu\n",timestamp);
			    }
			    if (a0_last_wr == 1) {
			    	fprintf(writefp,"0,LW,,,,%lu\n",timestamp);
			    }
			    if (a0_response == 1) {
			    	fprintf(writefp,"0,B,,,%u,%lu\n",a0_bid,timestamp);
			    }
			    if (a0_rd_addr_latch == 1) {
			    	fprintf(writefp,"0,R,0x%010llX,%u,%u,%lu\n",a0_araddr,a0_arlen,a0_arid,timestamp);
			    }
			    if (a0_first_rd == 1) {
			    	fprintf(writefp,"0,FR,,,%u,%lu\n",a0_rid,timestamp);
			    }
			    if (a0_last_rd == 1) {
			    	fprintf(writefp,"0,LR,,,%u,%lu\n",a0_rid,timestamp);
			    }
			    if (a0_mid_wr == 1) {
			    	fprintf(writefp,"0,MW,,,,%lu\n",timestamp);
			    }
			    if (a0_mid_rd == 1) {
			    	fprintf(writefp,"0,MR,,,%u,%lu\n",a0_rid,timestamp);
			    }
			}

			//APM1 FILE WRITE
			if (EN_APM_DATA == 1) {
			    if (a1_wr_addr_latch == 1) {
			    	fprintf(writefp,"1,W,0x%010llX,,%u,%u,%lu\n",a1_awaddr,a1_awlen,a1_awid,timestamp);
			    }
			    if (a1_first_wr == 1) {
			    	fprintf(writefp,"1,FW,,0x%016llX,,,%lu\n",a1_awdata,timestamp);
			    }
			    if (a1_last_wr == 1) {
			    	fprintf(writefp,"1,LW,,0x%016llX,,,%lu\n",a1_awdata,timestamp);
			    }
			    if (a1_response == 1) {
			    	fprintf(writefp,"1,B,,,,%u,%lu\n",a1_bid,timestamp);
			    }
			    if (a1_rd_addr_latch == 1) {
			    	fprintf(writefp,"1,R,0x%010llX,,%u,%u,%lu\n",a1_araddr, a1_arlen,a1_arid,timestamp);
			    }
			    if (a1_first_rd == 1) {
			    	fprintf(writefp,"1,FR,,0x%016llX,,%u,%lu\n",a1_ardata,a1_rid,timestamp);
			    }
			    if (a1_last_rd == 1) {
			    	fprintf(writefp,"1,LR,,0x%016llX,,%u,%lu\n",a1_ardata,a1_rid,timestamp);
			    }
			    if (a1_mid_wr == 1) {
			    	fprintf(writefp,"1,MW,,0x%016llX,,,%lu\n",a1_awdata,timestamp);
			    }
			    if (a1_mid_rd == 1) {
			    	fprintf(writefp,"1,MR,,0x%016llX,,%u,%lu\n",a1_ardata,a1_rid,timestamp);
			    }
			}
			else {
			    if (a1_wr_addr_latch == 1) {
			    	fprintf(writefp,"1,W,0x%010llX,%u,%u,%lu\n",a1_awaddr,a1_awlen,a1_awid,timestamp);
			    }
			    if (a1_first_wr == 1) {
			    	fprintf(writefp,"1,FW,,,,%lu\n",timestamp);
			    }
			    if (a1_last_wr == 1) {
			    	fprintf(writefp,"1,LW,,,,%lu\n",timestamp);
			    }
			    if (a1_response == 1) {
			    	fprintf(writefp,"1,B,,,%u,%lu\n",a1_bid,timestamp);
			    }
			    if (a1_rd_addr_latch == 1) {
			    	fprintf(writefp,"1,R,0x%010llX,%u,%u,%lu\n",a1_araddr, a1_arlen,a1_arid,timestamp);
			    }
			    if (a1_first_rd == 1) {
			    	fprintf(writefp,"1,FR,,,%u,%lu\n",a1_rid,timestamp);
			    }
			    if (a1_last_rd == 1) {
			    	fprintf(writefp,"1,LR,,,%u,%lu\n",a1_rid,timestamp);
			    }
			    if (a1_mid_wr == 1) {
			    	fprintf(writefp,"1,MW,,,,%lu\n",timestamp);
			    }
			    if (a1_mid_rd == 1) {
			    	fprintf(writefp,"1,MR,,,%u,%lu\n",a1_rid,timestamp);
			    }
			}
		}
	}

term:
	fclose(readfp);
	fclose(writefp);
	return 0;
}

unsigned long long int nextfield(char **a, unsigned int len)
{
	unsigned long long int num = 0;
	unsigned long long int mask = 1;
	while (len--) {
		num |= (*(*a)-- == '1') ? mask : 0;
		mask <<= 1;
	}
	return num;
}

char *int2string(unsigned input_int)
{
	static char bin[8];
	unsigned i;
	unsigned j = 0;
	for (i = 1 << 7; i > 0; i = i / 2) {
		if (input_int & i) {
			bin[j] = '1';
		} else {
			bin[j] = '0';
		}
		j++;
	}
	return bin;
}