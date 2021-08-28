/*
 * clocks.c
 *
 *  Created on: Jan 31, 2020
 *      Author: lloyd23
 */

#if defined(CLOCKS)

#include <stdio.h> /* printf, fprintf, perror, fopen, fwrite */
#include <stdlib.h> /* exit */
#include <stdint.h> /* uint64_t, uintptr_t */

#include "clocks.h"
#include "devtree.h"
#if defined VAR_DELAY && VAR_DELAY==_GDT_
#include <stdbool.h>
#include "gdt.h"
#define NUM_GDTS 4
#define NUM_TX_TYPES 2 //Read and Write
#define NUM_REGS_PER_BLOCK B_OFFSET //NUM_GDTS x REG_BLOCK_SIZE is the total number of registers available for GDT
#elif defined VAR_DELAY && (VAR_DELAY==_PWCLT106W85R_ || VAR_DELAY==_PWCLT400W200R_) && defined STD
#include <stdbool.h>
#include "gdt.h"
#define NUM_GDTS 4
#define NUM_TX_TYPES 2 //Read and Write
#define NUM_REGS_PER_BLOCK B_OFFSET //NUM_GDTS x REG_BLOCK_SIZE is the total number of registers available for GDT
#else
#define NUM_REGS_PER_BLOCK 4096
#endif

#define DEV_TREE "/sys/firmware/devicetree/base/amba_pl@0"

#define FPD_SLCR   0xFD610000 /* FPD System-level Control */
#define wprot0          0x000 /* 0 active */
#define wprot0_off 0x00000000 /*        0 */

#define CRF_APB    0xFD1A0000 /* Clock and Reset control registers for FPD */
#define APLL_CTRL       0x020 /* 26:24 POST_SRC, 22:20 PRE_SRC, 16 DIV2, 14:8 FBDIV, 3 BYPASS, 0 RESET */
#define APLL_CHK   0x00014200 /*             NA,    PS_REF_CLK,       1,         66,        0,       0 */
#define DPLL_CTRL       0x02C /* 26:24 POST_SRC, 22:20 PRE_SRC, 16 DIV2, 14:8 FBDIV, 3 BYPASS, 0 RESET */
#define ACPU_CTRL       0x060 /* 25 CLKACT_HALF, 24 CLKACT_FULL, 13:8 DIVISOR0, 2:0 SRCSEL */
#define ACPU_EMUL  0x03000800 /*              1,              1,             8,       APLL */
#define ACPU_NORM  0x03000100 /*              1,              1,             1,       APLL */
#define DDR_CTRL        0x080 /* 13:8 DIVISOR0, 2:0 SRCSEL */

#define CRL_APB    0xFF5E0000 /* Clock and Reset control registers for LPD */
#define IOPLL_CTRL      0x020 /* 26:24 POST_SRC, 22:20 PRE_SRC, 16 DIV2, 14:8 FBDIV, 3 BYPASS, 0 RESET */
#define IOPLL_CHK  0x00015A00 /*             NA,    PS_REF_CLK,       1,         90,        0,       0 */
#define PL0_REF_CTRL    0x0C0 /* 24 CLKACT, 21:16 DIVISOR1, 13:8 DIVISOR0, 2:0 SRCSEL */
#define PL0_EMUL   0x01011800 /*         1,              1,            24,      IOPLL */
#define PL0_NORM   0x01010800 /*         1,              1,             6,      IOPLL */
#define PL1_REF_CTRL    0x0C4 /* 24 CLKACT, 21:16 DIVISOR1, 13:8 DIVISOR0, 2:0 SRCSEL */

/* TODO: make clocks_init() and clocks_finish() functions (like monitor_ln.c) */

// The order is delay_0_axi_delay_1, delay_1_axi_delay_0, delay_1_axi_delay_1, delay_0_axi_delay_0
// const int calib_lats[4][2] = {{62,79},{62,79},{48,66},{60,78}};
const int calib_lats[4][2] = {{62,79},{48,66},{60,78},{62,79}};
int gdt_n0[1024] = {
	#include "gdt_data_n0.txt"
	};

static void *dev_smmap(const char *name, int inst, int pgidx)
{
	struct {uint64_t len, addr;} reg;
        unsigned long offset = pgidx * NUM_REGS_PER_BLOCK;
	int found = dev_search(DEV_TREE, name, inst, "reg", &reg, sizeof(reg));
	if(found == inst){ 
          if(offset < reg.len){
			return dev_mmap(reg.addr + offset);
          }
        }else{
          printf("Couldn't find device tree record for %s,inst %d, page index %d\n",name, inst, pgidx);
        }
        return MAP_FAILED;
}
#if defined VAR_DELAY && VAR_DELAY==_GDT_
// The order is delay_0_axi_delay_1, delay_1_axi_delay_0, delay_1_axi_delay_1, delay_0_axi_delay_0
int gdt_inputs[4][2][1024] = {{{
	#include "gdt_data_cpu_dram_write.txt"  // Accererator DRAM write response; fixed delay (before compensation) = 492 clocks
	},{
	#include "gdt_data_cpu_dram_read.txt"  // Accererator DRAM read response; fixed delay (before compensation) = 366 clocks
	}},{{
	#include "gdt_data_acc_sram_write.txt"  // CPU SRAM write response; fixed delay (before compensation) = 216 clocks
	},{
	#include "gdt_data_acc_sram_read.txt"  // CPU SRAM read response; fixed delay (before compensation) = 216 clocks
	}},{{
	#include "gdt_data_acc_dram_write.txt"  // CPU DRAM write response; fixed delay (before compensation) = 636 clocks
	},{
	#include "gdt_data_acc_dram_read.txt"  // CPU DRAM read response; fixed delay (before compensation) = 510 clocks
	}},{{
	#include "gdt_data_cpu_sram_write.txt"  // Accererator SRAM write response; fixed delay (before compensation) = 72 clocks
	},{
	#include "gdt_data_cpu_sram_read.txt"  // Accererator SRAM read response; fixed delay (before compensation) = 72 clocks
	}}};

void operate_gdt(bool fill){
        int i,p;
        for(i = 1;i <= NUM_GDTS; i++){
          for(p = 1; p <= NUM_TX_TYPES; p++){
            volatile unsigned int *delay = (unsigned int *)dev_smmap("axi_delayv",i,p);
            if(delay != MAP_FAILED){
              if(fill){
                config_gdt(delay,calib_lats[i-1][p-1],gdt_inputs[i-1][p-1]);
              }else{
                clear_gdt(delay, gdt_n0);
              }
              dev_munmap((void *)delay);
            }else{
              printf("Failed mapping delay table address region\n");
              exit(-1);
            }
          }
        }
}
#elif defined VAR_DELAY && (VAR_DELAY==_PWCLT106W85R_ || VAR_DELAY==_PWCLT400W200R_) && defined STD
void operate_pwclt(bool fill){
	
	int pwclt_std;
	#if STD == _MUDIVBY4_
		pwclt_std = PWCLT_STD_MUDIVBY4;
		printf("Configuring PwCLT with STD=MUDIVBY4\n");
	#elif STD == _MUDIVBY8_
		pwclt_std = PWCLT_STD_MUDIVBY8;
		printf("Configuring PwCLT with STD=MUDIVBY8\n");
	#elif STD == _MUDIVBY16_
		pwclt_std = PWCLT_STD_MUDIVBY16;
		printf("Configuring PwCLT with STD=MUDIVBY16\n");
	#elif STD == _MUDIVBY32_
		pwclt_std = PWCLT_STD_MUDIVBY32;
		printf("Configuring PwCLT with STD=MUDIVBY32\n");
	#else
		pwclt_std = DISABLE_PWCLT;
		printf("Wrong configuration, PwCLT is disabled and GDT is enabled\n");
	#endif
	
	// The order is delay_0_axi_delay_1, delay_1_axi_delay_0, delay_1_axi_delay_1, delay_0_axi_delay_0
	#if VAR_DELAY == _PWCLT106W85R_
		// int pwclt_lat[NUM_GDTS][NUM_TX_TYPES] = {{PWCLT_MU216, PWCLT_MU216}, {PWCLT_MU636, PWCLT_MU510}, {PWCLT_MU72, PWCLT_MU72},{PWCLT_MU492, PWCLT_MU366}};
		int pwclt_lat[NUM_GDTS][NUM_TX_TYPES] = {{PWCLT_MU636, PWCLT_MU510}, {PWCLT_MU72, PWCLT_MU72},{PWCLT_MU492, PWCLT_MU366},{PWCLT_MU216, PWCLT_MU216}};
		printf("Configuring PwCLT with PWCLT106W85R\n");
	#elif VAR_DELAY == _PWCLT400W200R_
		// int pwclt_lat[NUM_GDTS][NUM_TX_TYPES] = {{PWCLT_MU216, PWCLT_MU216}, {PWCLT_MU2400, PWCLT_MU1200}, {PWCLT_MU72, PWCLT_MU72},{PWCLT_MU2256, PWCLT_MU1056}};
		int pwclt_lat[NUM_GDTS][NUM_TX_TYPES] = {{PWCLT_MU2400, PWCLT_MU1200}, {PWCLT_MU72, PWCLT_MU72},{PWCLT_MU2256, PWCLT_MU1056},{PWCLT_MU216, PWCLT_MU216}};
		printf("Configuring PwCLT with PWCLT400W200R\n");
	#else
		int pwclt_lat[NUM_GDTS][NUM_TX_TYPES] = {{DISABLE_PWCLT, DISABLE_PWCLT}, {DISABLE_PWCLT, DISABLE_PWCLT}, {DISABLE_PWCLT, DISABLE_PWCLT},{DISABLE_PWCLT, DISABLE_PWCLT}};
		printf("Wrong configuration, PwCLT is disabled and GDT is enabled\n");
	#endif

	int i;
	for(i = 1;i <= NUM_GDTS; i++){	
		volatile unsigned int *delay = (unsigned int *)dev_smmap("axi_delayv",i,3);
		if(delay != MAP_FAILED){
			// printf("Mapped dev i=%d addresses: 0x%08x 0x%08x 0x%08x 0x%08x\n",i,delay,(delay + 1),(delay + 2),(delay + 3));
			volatile int *pwclt_b = (int *) (delay);
			volatile int *pwclt_r = (int *) (delay + 1);
			volatile int *pwclt_cal_b = (int *) (delay + 2);
			volatile int *pwclt_cal_r = (int *) (delay + 3);
			if(fill){
				*pwclt_b = (pwclt_lat[i-1][0] | pwclt_std);
				*pwclt_r = (pwclt_lat[i-1][1] | pwclt_std);
				*pwclt_cal_b = (1875*calib_lats[i-1][0])/3000; // CPU SRAM write calibration offset
				*pwclt_cal_r = (1875*calib_lats[i-1][1])/3000; // CPU SRAM read calibration offset
			}else{
				*pwclt_b = DISABLE_PWCLT;
				*pwclt_r = DISABLE_PWCLT;
				*pwclt_cal_b = DISABLE_PWCLT; // CPU SRAM write calibration offset
				*pwclt_cal_r = DISABLE_PWCLT; // CPU SRAM read calibration offset
			}
			// printf("PwCLT regvals: 0x%08x 0x%08x 0x%08x 0x%08x \n",*pwclt_b, *pwclt_r, *pwclt_cal_b, *pwclt_cal_r);
			dev_munmap((void *)delay);
		}else{
			printf("Failed mapping delay table address region\n");
			exit(-1);
		}
	}
}
#endif

void clocks_emulate(void)
{
	char *fpd_slcr = (char *)dev_mmap(FPD_SLCR);
	char *crf_apb  = (char *)dev_mmap(CRF_APB);
	char *crl_apb  = (char *)dev_mmap(CRL_APB);
	if (fpd_slcr == MAP_FAILED || crf_apb == MAP_FAILED || crl_apb == MAP_FAILED) goto ce_return;

	volatile unsigned int *unlock   = (unsigned int *)(fpd_slcr+wprot0);
	volatile unsigned int *apll_c   = (unsigned int *)(crf_apb+APLL_CTRL);
	volatile unsigned int *dpll_c   = (unsigned int *)(crf_apb+DPLL_CTRL);
	volatile unsigned int *arm_cc   = (unsigned int *)(crf_apb+ACPU_CTRL);
	volatile unsigned int *ddr_cc   = (unsigned int *)(crf_apb+DDR_CTRL);
	volatile unsigned int *iopll_c  = (unsigned int *)(crl_apb+IOPLL_CTRL);
	volatile unsigned int *fpga0_cc = (unsigned int *)(crl_apb+PL0_REF_CTRL); /* Accelerator & Peripheral Clock */
	volatile unsigned int *fpga1_cc = (unsigned int *)(crl_apb+PL1_REF_CTRL); /* Interconnect & APM */

	printf("SRAM_W:%d SRAM_R:%d DRAM_W:%d DRAM_R:%d\nQUEUE_W:%d QUEUE_R:%d TRANS:%d W:%d R:%d\n",
			T_SRAM_W, T_SRAM_R, T_DRAM_W, T_DRAM_R, T_QUEUE_W, T_QUEUE_R, T_TRANS,
			T_DRAM_W+T_QUEUE_W+T_TRANS, T_DRAM_R+T_QUEUE_R+T_TRANS);
	printf("ARM_PLL_CTRL:%08X DDR_PLL_CTRL:%08X IO_PLL_CTRL:%08X\n", *apll_c, *dpll_c, *iopll_c);
	if (*apll_c != APLL_CHK || *iopll_c != IOPLL_CHK) {
		printf(" -- error: clocks_emulate: incompatible clock configuration\n");
		goto ce_return;
	}

	*unlock   = wprot0_off;
	// *arm_cc   = ACPU_EMUL; /* ARM at 2.75 GHz */
	*fpga0_cc = PL0_EMUL; /* DRE at 1.25 GHz */
	FILE *fp = fopen("/sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed", "w+b");
	if (fp != NULL) {char *str = (char *)"137500"; fwrite(str, sizeof(char), sizeof(str), fp); fclose(fp);}
	printf("ARM_CLK_CTRL:%08X DDR_CLK_CTRL:%08X\n", *arm_cc, *ddr_cc);
	printf("FPGA0_CLK_CTRL:%08X FPGA1_CLK_CTRL:%08X\n", *fpga0_cc, *fpga1_cc);
	if (*arm_cc != ACPU_EMUL || *fpga0_cc != PL0_EMUL) {
		printf(" -- error: clocks_emulate: clock configuration not set\n");
		goto ce_return;
	}
#if defined VAR_DELAY && VAR_DELAY==_GDT_
	/* --- Configure the Gaussian Delay Tables (GTD) --- */
        #pragma message "Compiling " __FILE__ "with VAR_DELAY"
        operate_gdt(true);
#elif defined VAR_DELAY && (VAR_DELAY==_PWCLT106W85R_ || VAR_DELAY==_PWCLT400W200R_) && defined STD
	#pragma message "Compiling " __FILE__ "with VAR_DELAY PWCLT"
 	operate_pwclt(true);
#else
	/* TODO: Make two sets of delay calibration values, */
	/* one for the zcu102 and the other for the sidewinder */
	/* The values here likely apply to only one of the boards, */
	/* since the DDR memories run at different frequencies. */
	volatile unsigned int *delay0 = (unsigned int *)dev_smmap("axi_delayv",1, 0); /* slot 0, CPU SRAM W, R */
	volatile unsigned int *delay1 = (unsigned int *)dev_smmap("axi_delayv",2, 0); /* slot 0, CPU DRAM W, R */
	if (delay0 != MAP_FAILED && delay1 != MAP_FAILED) {
		delay0[2] = 6*(T_SRAM_W+T_TRANS)           - 52; delay0[4] = 6*(T_SRAM_R+T_TRANS)           - 69; /* .16 ns per count */
		delay1[2] = 6*(T_DRAM_W+T_QUEUE_W+T_TRANS) - 52; delay1[4] = 6*(T_DRAM_R+T_QUEUE_R+T_TRANS) - 69;
		printf("Slot 0 - CPU_SRAM_B:%u CPU_SRAM_R:%u CPU_DRAM_B:%u CPU_DRAM_R:%u\n", delay0[2], delay0[4], delay1[2], delay1[4]);
	}

	if (delay0 != MAP_FAILED) dev_munmap((void *)delay0);
	if (delay1 != MAP_FAILED) dev_munmap((void *)delay1);
	volatile unsigned int *delay2 = (unsigned int *)dev_smmap("axi_delayv",3, 0); /* slot 1, ACC SRAM W, R */
	volatile unsigned int *delay3 = (unsigned int *)dev_smmap("axi_delayv",4, 0); /* slot 1, ACC DRAM W, R */
	if (delay2 != MAP_FAILED && delay3 != MAP_FAILED) {
		delay2[2] = 6*(T_SRAM_W)                   - 48; delay2[4] = 6*(T_SRAM_R)                   - 66;
		delay3[2] = 6*(T_DRAM_W+T_QUEUE_W)         - 48; delay3[4] = 6*(T_DRAM_R+T_QUEUE_R)         - 66;
		printf("Slot 1 - ACC_SRAM_B:%u ACC_SRAM_R:%u ACC_DRAM_B:%u ACC_DRAM_R:%u\n", delay2[2], delay2[4], delay3[2], delay3[4]);
	}
	if (delay2 != MAP_FAILED) dev_munmap((void *)delay2);
	if (delay3 != MAP_FAILED) dev_munmap((void *)delay3);
#endif
ce_return:
	if (fpd_slcr != MAP_FAILED) dev_munmap(fpd_slcr);
	if (crf_apb  != MAP_FAILED) dev_munmap(crf_apb);
	if (crl_apb  != MAP_FAILED) dev_munmap(crl_apb);
}

void clocks_normal(void)
{
	char *fpd_slcr = (char *)dev_mmap(FPD_SLCR);
	char *crf_apb  = (char *)dev_mmap(CRF_APB);
	char *crl_apb  = (char *)dev_mmap(CRL_APB);
	if (fpd_slcr == MAP_FAILED || crf_apb == MAP_FAILED || crl_apb == MAP_FAILED) goto cn_return;

	volatile unsigned int *unlock   = (unsigned int *)(fpd_slcr+wprot0);
	volatile unsigned int *arm_cc   = (unsigned int *)(crf_apb+ACPU_CTRL);
	volatile unsigned int *fpga0_cc = (unsigned int *)(crl_apb+PL0_REF_CTRL);

	*unlock   = wprot0_off;
	// *arm_cc   = ACPU_NORM;
	*fpga0_cc = PL0_NORM;
	FILE *fp = fopen("/sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed", "w+b");
	if (fp != NULL) {char *str = (char *)"1100000"; fwrite(str, sizeof(char), sizeof(str), fp); fclose(fp);}
	if (*arm_cc != ACPU_NORM || *fpga0_cc != PL0_NORM) {
		printf(" -- error: clocks_normal: clock configuration not set\n");
		goto cn_return;
	}
#if defined VAR_DELAY && VAR_DELAY==_GDT_
	/* --- Configure the Gaussian Delay Tables (GTD) --- */
        operate_gdt(false);
#elif defined VAR_DELAY && (VAR_DELAY==_PWCLT106W85R_ || VAR_DELAY==_PWCLT400W200R_) && defined STD
 	operate_pwclt(false);
#else
	volatile unsigned int *delay0 = (unsigned int *)dev_smmap("axi_delayv",1,0); /* slot 0, CPU SRAM W, R */
	volatile unsigned int *delay1 = (unsigned int *)dev_smmap("axi_delayv",2,0); /* slot 0, CPU DRAM W, R */
	if (delay0 != MAP_FAILED && delay1 != MAP_FAILED) {
		delay0[2] = 0; delay0[4] = 0; delay1[2] = 0; delay1[4] = 0;
	}
	if (delay0 != MAP_FAILED) dev_munmap((void *)delay0);
	if (delay1 != MAP_FAILED) dev_munmap((void *)delay1);

	volatile unsigned int *delay2 = (unsigned int *)dev_smmap("axi_delayv",3,0); /* slot 1, ACC SRAM W, R */
	volatile unsigned int *delay3 = (unsigned int *)dev_smmap("axi_delayv",4,0); /* slot 1, ACC DRAM W, R */
	if (delay2 != MAP_FAILED && delay3 != MAP_FAILED) {
		delay2[2] = 0; delay2[4] = 0; delay3[2] = 0; delay3[4] = 0;
	}
	if (delay2 != MAP_FAILED) dev_munmap((void *)delay2);
	if (delay3 != MAP_FAILED) dev_munmap((void *)delay3);

#endif
cn_return:
	if (fpd_slcr != MAP_FAILED) dev_munmap(fpd_slcr);
	if (crf_apb  != MAP_FAILED) dev_munmap(crf_apb);
	if (crl_apb  != MAP_FAILED) dev_munmap(crl_apb);
}

#endif /* CLOCKS */
