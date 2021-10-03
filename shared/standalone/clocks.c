/*
 * clocks.c
 *
 *  Created on: Dec 10, 2014
 *      Author: lloyd23
 */

#if defined(CLOCKS)

#include <stdio.h> /* printf */
#include "clocks.h"
#if defined VAR_DELAY && VAR_DELAY==_GDT_
#include "gdt.h"
#endif

#if defined(ZYNQ) && ZYNQ == _Z7_
/* Zynq-7000 Device */
#include "xparameters.h" /* XPAR_* */

#define SLCR           0xF8000000 /* System Level Control Registers */
#define SLCR_UNLOCK         0x008 /* 15:0 UNLOCK_KEY */
#define SLCR_UNLOCK_KEY    0xDF0D /*          0xDF0D */
#define ARM_PLL_CTRL        0x100 /* 18:12 PLL_FDIV, 4 PLL_BYPASS_FORCE, 3 PLL_BYPASS_QUAL, 1 PLL_PWRDWN, 0 PLL_RESET */
#define APLL_CHK       0x00036008 /*             54,                  0,                 1,            0,           0 */
#define DDR_PLL_CTRL        0x104 /* 18:12 PLL_FDIV, 4 PLL_BYPASS_FORCE, 3 PLL_BYPASS_QUAL, 1 PLL_PWRDWN, 0 PLL_RESET */
#define IO_PLL_CTRL         0x108 /* 18:12 PLL_FDIV, 4 PLL_BYPASS_FORCE, 3 PLL_BYPASS_QUAL, 1 PLL_PWRDWN, 0 PLL_RESET */
#define IOPLL_CHK      0x0001E008 /*             30,                  0,                 1,            0,           0 */
#define ARM_CLK_CTRL        0x120 /* 28:24 CLKACT, 13:8 DIVISOR, 5:4 SRCSEL */
#define ACPU_EMUL      0x1F000E00 /*          all,           14,       APLL */
#define ACPU_NORM      0x1F000300 /*          all,            3,       APLL */
#define DDR_CLK_CTRL        0x124 /* 31:26 DDR_2XCLK_DIVISOR, 25:20 DDR_3XCLK_DIVISOR, 1 DDR_2XCLKACT, 0 DDR_3XCLKACT */
#define FPGA0_CLK_CTRL      0x170 /* 25:20 DIVISOR1, 13:8 DIVISOR0, 5:4 SRCSEL */
#define PL0_EMUL       0x00101000 /*              1,            16,      IOPLL */
#define PL0_NORM       0x00100800 /*              1,             6,      IOPLL */
#define FPGA1_CLK_CTRL      0x180 /* 25:20 DIVISOR1, 13:8 DIVISOR0, 5:4 SRCSEL */
#define CLK_621_TRUE        0x1C4 /* 0 CLK_621_TRUE */
#define CLK_621_CHK             0 /*        (4:2:1) */

int gdt_n0[1024] = {
	#include "gdt_data/gdt_data_n0.txt"
	};

void clocks_emulate(void)
{
	volatile unsigned int *unlock   = (unsigned int *)(SLCR+SLCR_UNLOCK);
	volatile unsigned int *apll_c   = (unsigned int *)(SLCR+ARM_PLL_CTRL);
	volatile unsigned int *dpll_c   = (unsigned int *)(SLCR+DDR_PLL_CTRL);
	volatile unsigned int *iopll_c  = (unsigned int *)(SLCR+IO_PLL_CTRL);
	volatile unsigned int *arm_cc   = (unsigned int *)(SLCR+ARM_CLK_CTRL);
	volatile unsigned int *ddr_cc   = (unsigned int *)(SLCR+DDR_CLK_CTRL);
	volatile unsigned int *fpga0_cc = (unsigned int *)(SLCR+FPGA0_CLK_CTRL); /* Accelerator & Peripheral Clock */
	volatile unsigned int *fpga1_cc = (unsigned int *)(SLCR+FPGA1_CLK_CTRL); /* Interconnect & APM */
	volatile unsigned int *clk_621  = (unsigned int *)(SLCR+CLK_621_TRUE);

	printf("SRAM_W:%d SRAM_R:%d DRAM_W:%d DRAM_R:%d\nQUEUE_W:%d QUEUE_R:%d TRANS:%d W:%d R:%d\n",
		T_SRAM_W, T_SRAM_R, T_DRAM_W, T_DRAM_R, T_QUEUE_W, T_QUEUE_R, T_TRANS,
		T_DRAM_W+T_QUEUE_W+T_TRANS, T_DRAM_R+T_QUEUE_R+T_TRANS);
	printf("ARM_PLL_CTRL:%08X DDR_PLL_CTRL:%08X IO_PLL_CTRL:%08X CLK_621:%X\n", *apll_c, *dpll_c, *iopll_c, *clk_621);
	if (*apll_c != APLL_CHK || *iopll_c != IOPLL_CHK || *clk_621 != CLK_621_CHK) {
		printf(" -- error: clocks_emulate: incompatible clock configuration\n");
		return;
	}

	*unlock   = SLCR_UNLOCK_KEY;
	*arm_cc   = ACPU_EMUL; /* ARM at 2.57 GHz */
	*fpga0_cc = PL0_EMUL; /* DRE at 1.25 GHz */
	printf("ARM_CLK_CTRL:%08X DDR_CLK_CTRL:%08X\n", *arm_cc, *ddr_cc);
	printf("FPGA0_CLK_CTRL:%08X FPGA1_CLK_CTRL:%08X\n", *fpga0_cc, *fpga1_cc);
	if (*arm_cc != ACPU_EMUL || *fpga0_cc != PL0_EMUL) {
		printf(" -- error: clocks_emulate: clock configuration not set\n");
		return;
	}
#if defined VAR_DELAY && VAR_DELAY==_GDT_
	/* --- Configure the Gaussian Delay Tables (GTD) --- */
        #pragma message "Compiling " __FILE__ "..."
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + B_OFFSET, 0, gdt_n0);
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + R_OFFSET, 0, gdt_n0);
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + B_OFFSET, 0, gdt_n0);
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + R_OFFSET, 0, gdt_n0);
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + B_OFFSET, 0, gdt_n0);
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + R_OFFSET, 0, gdt_n0);
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + B_OFFSET, 0, gdt_n0);
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + R_OFFSET, 0, gdt_n0);
	printf("Gaussian Delay Tables Initialized\n");

//	volatile unsigned int *delay0 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR; /* slot 0, CPU SRAM W, R */
//	volatile unsigned int *delay1 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR; /* slot 0, CPU DRAM W, R */
//	delay0[2] = 4*(T_SRAM_W+T_TRANS)           - 44; delay0[4] = 4*(T_SRAM_R+T_TRANS)           - 39; /* .25 ns per count */
//	delay1[2] = 4*(T_DRAM_W+T_QUEUE_W+T_TRANS) - 45; delay1[4] = 4*(T_DRAM_R+T_QUEUE_R+T_TRANS) - 44;
//	printf("Slot 0 - CPU_SRAM_B:%u CPU_SRAM_R:%u CPU_DRAM_B:%u CPU_DRAM_R:%u\n", delay0[2], delay0[4], delay1[2], delay1[4]);
#elif defined VAR_DELAY && (VAR_DELAY==_PWCLT106W85R_ || VAR_DELAY==_PWCLT400W200R_) && defined STD

	int *pwclt_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_cal_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
	int pwclt_std;

	#if STD == _MUDIVBY4_
		pwclt_std = PWCLT_STD_MUDIVBY4;
	#elif STD == _MUDIVBY8_
		pwclt_std = PWCLT_STD_MUDIVBY8;
	#elif STD == _MUDIVBY16_
		pwclt_std = PWCLT_STD_MUDIVBY16;
	#elif STD == _MUDIVBY32_
		pwclt_std = PWCLT_STD_MUDIVBY32;
	#else
		pwclt_std = PWCLT_STD_MUDIVBY4;
	#endif

	#if VAR_DELAY == _MU106W85R_
		*pwclt_0_0_b = PWCLT_MU216 | pwclt_std;
		*pwclt_0_0_r = PWCLT_MU216 | pwclt_std;
		*pwclt_0_1_b = PWCLT_MU636 | pwclt_std;
		*pwclt_0_1_r = PWCLT_MU510 | pwclt_std;
		*pwclt_1_0_b = PWCLT_MU72 | pwclt_std;
		*pwclt_1_0_r = PWCLT_MU72 | pwclt_std;
		*pwclt_1_1_b = PWCLT_MU492 | pwclt_std;
		*pwclt_1_1_r = PWCLT_MU366 | pwclt_std;
		printf("PWCLT configured with t_W=106ns and t_R=85ns mean gaussians.\n");
	#elif VAR_DELAY == _MU400W200R_
		*pwclt_0_0_b = PWCLT_MU216 | pwclt_std;
		*pwclt_0_0_r = PWCLT_MU216 | pwclt_std;
		*pwclt_0_1_b = PWCLT_MU2400 | pwclt_std;
		*pwclt_0_1_r = PWCLT_MU1200 | pwclt_std;
		*pwclt_1_0_b = PWCLT_MU72 | pwclt_std;
		*pwclt_1_0_r = PWCLT_MU72 | pwclt_std;
		*pwclt_1_1_b = PWCLT_MU2256 | pwclt_std;
		*pwclt_1_1_r = PWCLT_MU1056 | pwclt_std;
		printf("PWCLT configured with t_W=400ns and t_R=200ns mean gaussians.\n");
	#else
		/* --- Configure the Gaussian Delay Tables (GTD) --- */
		config_gdt();
		*pwclt_0_0_b = DISABLE_PWCLT; // CPU SRAM write response
		*pwclt_0_0_r = DISABLE_PWCLT; // CPU SRAM read response
		*pwclt_0_1_b = DISABLE_PWCLT; // CPU DRAM write response
		*pwclt_0_1_r = DISABLE_PWCLT; // CPU DRAM read response
		*pwclt_1_0_b = DISABLE_PWCLT; // Accererator SRAM write response
		*pwclt_1_0_r = DISABLE_PWCLT; // Accererator SRAM read response
		*pwclt_1_1_b = DISABLE_PWCLT; // Accererator DRAM write response
		*pwclt_1_1_r = DISABLE_PWCLT; // Accererator DRAM read response
	#endif

#endif

//#if defined(XPAR_DELAY_1_AXI_DELAY_0_BASEADDR)
//	volatile unsigned int *delay2 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR; /* slot 1, ACC SRAM W, R */
//	volatile unsigned int *delay3 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR; /* slot 1, ACC DRAM W, R */
//	delay2[2] = 4*(T_SRAM_W)                   - 21; delay2[4] = 4*(T_SRAM_R)                   - 36;
//	delay3[2] = 4*(T_DRAM_W+T_QUEUE_W)         - 21; delay3[4] = 4*(T_DRAM_R+T_QUEUE_R)         - 37;
//	printf("Slot 1 - ACC_SRAM_B:%u ACC_SRAM_R:%u ACC_DRAM_B:%u ACC_DRAM_R:%u\n", delay2[2], delay2[4], delay3[2], delay3[4]);
//#endif
}

void clocks_normal(void)
{
	volatile unsigned int *unlock   = (unsigned int *)(SLCR+SLCR_UNLOCK);
	volatile unsigned int *arm_cc   = (unsigned int *)(SLCR+ARM_CLK_CTRL);
	volatile unsigned int *fpga0_cc = (unsigned int *)(SLCR+FPGA0_CLK_CTRL);
	*unlock   = SLCR_UNLOCK_KEY;
	*arm_cc   = ACPU_NORM;
	*fpga0_cc = PL0_NORM;
	if (*arm_cc != ACPU_NORM || *fpga0_cc != PL0_NORM) {
		printf(" -- error: clocks_normal: clock configuration not set\n");
		return;
	}
#if defined VAR_DELAY && VAR_DELAY==_GDT_
	/* --- Configure the Gaussian Delay Tables (GTD) --- */
        #pragma message "Compiling " __FILE__ "..."
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + R_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + R_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + R_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + R_OFFSET, gdt_n0);
	printf("Gaussian Delay Tables have been cleared\n");

//	volatile unsigned int *delay0 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR; /* slot 0, CPU SRAM W, R */
//	volatile unsigned int *delay1 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR; /* slot 0, CPU DRAM W, R */
//	delay0[2] = 0; delay0[4] = 0; delay1[2] = 0; delay1[4] = 0;
#elif defined VAR_DELAY && (VAR_DELAY==_PWCLT106W85R_ || VAR_DELAY==_PWCLT400W200R_) && defined STD
	int *pwclt_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
	*pwclt_0_0_b = DISABLE_PWCLT; // CPU SRAM write response
	*pwclt_0_0_r = DISABLE_PWCLT; // CPU SRAM read response
	*pwclt_0_1_b = DISABLE_PWCLT; // CPU DRAM write response
	*pwclt_0_1_r = DISABLE_PWCLT; // CPU DRAM read response
	*pwclt_1_0_b = DISABLE_PWCLT; // Accererator SRAM write response
	*pwclt_1_0_r = DISABLE_PWCLT; // Accererator SRAM read response
	*pwclt_1_1_b = DISABLE_PWCLT; // Accererator DRAM write response
	*pwclt_1_1_r = DISABLE_PWCLT; // Accererator DRAM read response
	printf("PWCLT configuration cleared.\n");
#endif

//#if defined(XPAR_DELAY_1_AXI_DELAY_0_BASEADDR)
//	volatile unsigned int *delay2 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR; /* slot 1, ACC SRAM W, R */
//	volatile unsigned int *delay3 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR; /* slot 1, ACC DRAM W, R */
//	delay2[2] = 0; delay2[4] = 0; delay3[2] = 0; delay3[4] = 0;
//#endif
}

#elif defined(ZYNQ) && ZYNQ == _ZU_
/* Zynq UltraScale+ Device */
#include "xparameters.h" /* XPAR_* */

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

/*
these offset/compensation values were determined empirically by running benchmarks, comparing the
performance metrics to the master branch (FDU) operating at pl_clk_0 = pl_clk_1 = 187.5MHz, adjusting the
delays, and repeating until the delta between the FDU@187.5MHz and VLD loaded with constants was less than 1%
for all benchmarks.
*/
int cpu_dram_wr_lat = 62;
int cpu_dram_rd_lat = 79;
int acc_dram_wr_lat = 60; //60; //100;
int acc_dram_rd_lat = 78; //78; //118;

int cpu_sram_wr_lat = 62;
int cpu_sram_rd_lat = 79;
int acc_sram_wr_lat = 48; //28; //48;
int acc_sram_rd_lat = 66; //46; //66;

/* FDU offsets. These were measured/calculated for the FDU at pl_clk_1 = 300MHz. For 187.5MHz operation of
both the FDU and VLD, clock frequency scaling is performed. For the FDU, the scaling is performed in clocks.c
by multiplying these clock cycle values by (187.5/300). For the VLD, the same scaling is performed in gdt.c.

int cpu_wr_lat = 52;
int cpu_rd_lat = 69;
int acc_wr_lat = 48;
int acc_rd_lat = 66;
*/

int gdt_n0[1024] = {
	#include "gdt_data/gdt_data_n0.txt"
	};

//Files named gdt_data_cxxx.txt are filled with constants of value xxx and are used for calibration.
//Files named gdt_data_gxxx.txt are filled with Gaussians where the median is xxx.
int gdt_0_0_b[1024] = {
	//#include "gdt_data/gdt_data_cpu_sram_write.txt"  // CPU SRAM write response; fixed delay (before compensation) = 216 clocks
	#include "gdt_data/gdt_data_g216.txt";
	};
int gdt_0_0_r[1024] = {
	//#include "gdt_data/gdt_data_cpu_sram_read.txt"  // CPU SRAM read response; fixed delay (before compensation) = 216 clocks
	#include "gdt_data/gdt_data_g216.txt";
	};
int gdt_0_1_b[1024] = {
	//#include "gdt_data/gdt_data_cpu_dram_write.txt"  // CPU DRAM write response; fixed delay (before compensation) = 636 clocks
	#include "gdt_data/gdt_data_g636.txt";
	};
int gdt_0_1_r[1024] = {
	//#include "gdt_data/gdt_data_cpu_dram_read.txt"  // CPU DRAM read response; fixed delay (before compensation) = 510 clocks
	#include "gdt_data/gdt_data_g510.txt";
	};
int gdt_1_0_b[1024] = {
	//#include "gdt_data/gdt_data_acc_sram_write.txt"  // Accererator SRAM write response; fixed delay (before compensation) = 72 clocks
	#include "gdt_data/gdt_data_g72.txt";
	};
int gdt_1_0_r[1024] = {
	//#include "gdt_data/gdt_data_acc_sram_read.txt"  // Accererator SRAM read response; fixed delay (before compensation) = 72 clocks
	#include "gdt_data/gdt_data_g72.txt";
	};
int gdt_1_1_b[1024] = {
	//#include "gdt_data/gdt_data_acc_dram_write.txt"  // Accererator DRAM write response; fixed delay (before compensation) = 492 clocks
	#include "gdt_data/gdt_data_g492.txt";
	};
int gdt_1_1_r[1024] = {
	//#include "gdt_data/gdt_data_acc_dram_read.txt"  // Accererator DRAM read response; fixed delay (before compensation) = 366 clocks
	#include "gdt_data/gdt_data_g366.txt";
	};

void clocks_emulate(void)
{
	volatile unsigned int *unlock   = (unsigned int *)(FPD_SLCR+wprot0);
	volatile unsigned int *apll_c   = (unsigned int *)(CRF_APB+APLL_CTRL);
	volatile unsigned int *dpll_c   = (unsigned int *)(CRF_APB+DPLL_CTRL);
	volatile unsigned int *arm_cc   = (unsigned int *)(CRF_APB+ACPU_CTRL);
	volatile unsigned int *ddr_cc   = (unsigned int *)(CRF_APB+DDR_CTRL);
	volatile unsigned int *iopll_c  = (unsigned int *)(CRL_APB+IOPLL_CTRL);
	volatile unsigned int *fpga0_cc = (unsigned int *)(CRL_APB+PL0_REF_CTRL); /* Accelerator & Peripheral Clock */
	volatile unsigned int *fpga1_cc = (unsigned int *)(CRL_APB+PL1_REF_CTRL); /* Interconnect & APM */

	printf("SRAM_W:%d SRAM_R:%d DRAM_W:%d DRAM_R:%d\nQUEUE_W:%d QUEUE_R:%d TRANS:%d W:%d R:%d\n",
			T_SRAM_W, T_SRAM_R, T_DRAM_W, T_DRAM_R, T_QUEUE_W, T_QUEUE_R, T_TRANS,
			T_DRAM_W+T_QUEUE_W+T_TRANS, T_DRAM_R+T_QUEUE_R+T_TRANS);
	printf("ARM_PLL_CTRL:%08X DDR_PLL_CTRL:%08X IO_PLL_CTRL:%08X\n", *apll_c, *dpll_c, *iopll_c);
	if (*apll_c != APLL_CHK || *iopll_c != IOPLL_CHK) {
		printf(" -- error: clocks_emulate: incompatible clock configuration\n");
		return;
	}

	*unlock   = wprot0_off;
	*arm_cc   = ACPU_EMUL; /* ARM at 2.75 GHz */
	*fpga0_cc = PL0_EMUL; /* DRE at 1.25 GHz */
	printf("ARM_CLK_CTRL:%08X DDR_CLK_CTRL:%08X\n", *arm_cc, *ddr_cc);
	printf("FPGA0_CLK_CTRL:%08X FPGA1_CLK_CTRL:%08X\n", *fpga0_cc, *fpga1_cc);
	if (*arm_cc != ACPU_EMUL || *fpga0_cc != PL0_EMUL) {
		printf(" -- error: clocks_emulate: clock configuration not set\n");
		return;
	}

	/* TODO: Make two sets of delay calibration values, */
	/* one for the zcu102 and the other for the sidewinder */
	/* The values here likely apply to only one of the boards, */
	/* since the DDR memories run at different frequencies. */


#if defined VAR_DELAY && VAR_DELAY==_GDT_
	/* --- Configure the Gaussian Delay Tables (GTD) --- */
	sleep(1);
    #pragma message "Compiling " __FILE__ "..."
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + B_OFFSET, cpu_sram_wr_lat, gdt_0_0_b); // CPU SRAM write response
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + R_OFFSET, cpu_sram_rd_lat, gdt_0_0_r); // CPU SRAM read response^S
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + B_OFFSET, cpu_dram_wr_lat, gdt_0_1_b); // CPU DRAM write response
	config_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + R_OFFSET, cpu_dram_rd_lat, gdt_0_1_r); // CPU DRAM read response
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + B_OFFSET, acc_sram_wr_lat, gdt_1_0_b); // Accererator SRAM write response
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + R_OFFSET, acc_sram_rd_lat, gdt_1_0_r); // Accererator SRAM read response
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + B_OFFSET, acc_dram_wr_lat, gdt_1_1_b); // Accererator DRAM write response
	config_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + R_OFFSET, acc_dram_rd_lat, gdt_1_1_r); // Accererator DRAM read response

/*
    int iii = 0;
    for (iii = 0; iii < 1024; ++iii){
		printf("%d %d\n", gdt_0_0_b[iii], iii);
	}
*/

	printf("Gaussian Delay Tables Initialized\n");
	sleep(1);

//	volatile unsigned int *delay0 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR; /* slot 0, CPU SRAM W, R */
//	volatile unsigned int *delay1 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR; /* slot 0, CPU DRAM W, R */
//	delay0[2] = 6*(T_SRAM_W+T_TRANS)           - 52; delay0[4] = 6*(T_SRAM_R+T_TRANS)           - 69; /* .16 ns per count */
//	delay1[2] = 6*(T_DRAM_W+T_QUEUE_W+T_TRANS) - 52; delay1[4] = 6*(T_DRAM_R+T_QUEUE_R+T_TRANS) - 69;
//	printf("Slot 0 - CPU_SRAM_B:%u CPU_SRAM_R:%u CPU_DRAM_B:%u CPU_DRAM_R:%u\n", delay0[2], delay0[4], delay1[2], delay1[4]);
#elif defined VAR_DELAY && ((VAR_DELAY==_PWCLT106W85R_) || (VAR_DELAY==_PWCLT400W200R_)) && defined STD
	int *pwclt_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
	int *pwclt_cal_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
	int pwclt_std;

	#if STD == _MUDIVBY4_
		pwclt_std = PWCLT_STD_MUDIVBY4;
	#elif STD == _MUDIVBY8_
		pwclt_std = PWCLT_STD_MUDIVBY8;
	#elif STD == _MUDIVBY16_
		pwclt_std = PWCLT_STD_MUDIVBY16;
	#elif STD == _MUDIVBY32_
		pwclt_std = PWCLT_STD_MUDIVBY32;
	#else
		pwclt_std = PWCLT_STD_MUDIVBY4;
	#endif

	#if VAR_DELAY == _PWCLT106W85R_
		*pwclt_0_0_b = (PWCLT_MU216 | pwclt_std);
		*pwclt_0_0_r = (PWCLT_MU216 | pwclt_std);
		*pwclt_0_1_b = (PWCLT_MU636 | pwclt_std);
		*pwclt_0_1_r = (PWCLT_MU510 | pwclt_std);
		*pwclt_1_0_b = (PWCLT_MU72  | pwclt_std);
		*pwclt_1_0_r = (PWCLT_MU72  | pwclt_std);
		*pwclt_1_1_b = (PWCLT_MU492 | pwclt_std);
		*pwclt_1_1_r = (PWCLT_MU366 | pwclt_std);
		*pwclt_cal_0_0_b = (1875*cpu_sram_wr_lat)/3000; // CPU SRAM write calibration offset
		*pwclt_cal_0_0_r = (1875*cpu_sram_rd_lat)/3000; // CPU SRAM read calibration offset
		*pwclt_cal_0_1_b = (1875*cpu_dram_wr_lat)/3000; // CPU DRAM write calibration offset
		*pwclt_cal_0_1_r = (1875*cpu_dram_rd_lat)/3000; // CPU DRAM read calibration offset
		*pwclt_cal_1_0_b = (1875*acc_sram_wr_lat)/3000; // Accererator SRAM write calibration offset
		*pwclt_cal_1_0_r = (1875*acc_sram_rd_lat)/3000; // Accererator SRAM read calibration offset
		*pwclt_cal_1_1_b = (1875*acc_dram_wr_lat)/3000; // Accererator DRAM write calibration offset
		*pwclt_cal_1_1_r = (1875*acc_dram_rd_lat)/3000; // Accererator DRAM read calibration offset	
		sleep(1);
		printf("PWCLT configured with t_W=106ns and t_R=85ns mean gaussians (REGVAL=0x%08x).\n",*pwclt_0_1_r);
	#elif VAR_DELAY == _PWCLT400W200R_
		*pwclt_0_0_b = PWCLT_MU216 | pwclt_std;
		*pwclt_0_0_r = PWCLT_MU216 | pwclt_std;
		*pwclt_0_1_b = PWCLT_MU2400 | pwclt_std;
		*pwclt_0_1_r = PWCLT_MU1200 | pwclt_std;
		*pwclt_1_0_b = PWCLT_MU72 | pwclt_std;
		*pwclt_1_0_r = PWCLT_MU72 | pwclt_std;
		*pwclt_1_1_b = PWCLT_MU2256 | pwclt_std;
		*pwclt_1_1_r = PWCLT_MU1056 | pwclt_std;
		*pwclt_cal_0_0_b = (1875*cpu_sram_wr_lat)/3000; // CPU SRAM write calibration offset
		*pwclt_cal_0_0_r = (1875*cpu_sram_rd_lat)/3000; // CPU SRAM read calibration offset
		*pwclt_cal_0_1_b = (1875*cpu_dram_wr_lat)/3000; // CPU DRAM write calibration offset
		*pwclt_cal_0_1_r = (1875*cpu_dram_rd_lat)/3000; // CPU DRAM read calibration offset
		*pwclt_cal_1_0_b = (1875*acc_sram_wr_lat)/3000; // Accererator SRAM write calibration offset
		*pwclt_cal_1_0_r = (1875*acc_sram_rd_lat)/3000; // Accererator SRAM read calibration offset
		*pwclt_cal_1_1_b = (1875*acc_dram_wr_lat)/3000; // Accererator DRAM write calibration offset
		*pwclt_cal_1_1_r = (1875*acc_dram_rd_lat)/3000; // Accererator DRAM read calibration offset	
		sleep(1);
		printf("PWCLT configured with t_W=400ns and t_R=200ns mean gaussians (REGVAL=0x%08x).\n",*pwclt_0_1_r);
	#else
		/* --- Configure the Gaussian Delay Tables (GTD) --- */
		config_gdt();
		sleep(1);
		*pwclt_0_0_b = DISABLE_PWCLT; // CPU SRAM write response
		*pwclt_0_0_r = DISABLE_PWCLT; // CPU SRAM read response
		*pwclt_0_1_b = DISABLE_PWCLT; // CPU DRAM write response
		*pwclt_0_1_r = DISABLE_PWCLT; // CPU DRAM read response
		*pwclt_1_0_b = DISABLE_PWCLT; // Accererator SRAM write response
		*pwclt_1_0_r = DISABLE_PWCLT; // Accererator SRAM read response
		*pwclt_1_1_b = DISABLE_PWCLT; // Accererator DRAM write response
		*pwclt_1_1_r = DISABLE_PWCLT; // Accererator DRAM read response
		*pwclt_cal_0_0_b = 0; // CPU SRAM write calibration offset
		*pwclt_cal_0_0_r = 0; // CPU SRAM read calibration offset
		*pwclt_cal_0_1_b = 0; // CPU DRAM write calibration offset
		*pwclt_cal_0_1_r = 0; // CPU DRAM read calibration offset
		*pwclt_cal_1_0_b = 0; // Accererator SRAM write calibration offset
		*pwclt_cal_1_0_r = 0; // Accererator SRAM read calibration offset
		*pwclt_cal_1_1_b = 0; // Accererator DRAM write calibration offset
		*pwclt_cal_1_1_r = 0; // Accererator DRAM read calibration offset	
	#endif
	sleep(1);



//#if defined(XPAR_DELAY_1_AXI_DELAY_0_BASEADDR)
//	volatile unsigned int *delay2 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR; /* slot 1, ACC SRAM W, R */
//	volatile unsigned int *delay3 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR; /* slot 1, ACC DRAM W, R */
//	delay2[2] = 6*(T_SRAM_W)                   - 48; delay2[4] = 6*(T_SRAM_R)                   - 66;
//	delay3[2] = 6*(T_DRAM_W+T_QUEUE_W)         - 48; delay3[4] = 6*(T_DRAM_R+T_QUEUE_R)         - 66;
//	printf("Slot 1 - ACC_SRAM_B:%u ACC_SRAM_R:%u ACC_DRAM_B:%u ACC_DRAM_R:%u\n", delay2[2], delay2[4], delay3[2], delay3[4]);
#endif
}

void clocks_normal(void)
{
	volatile unsigned int *unlock   = (unsigned int *)(FPD_SLCR+wprot0);
	volatile unsigned int *arm_cc   = (unsigned int *)(CRF_APB+ACPU_CTRL);
	volatile unsigned int *fpga0_cc = (unsigned int *)(CRL_APB+PL0_REF_CTRL);
	*unlock   = wprot0_off;
	*arm_cc   = ACPU_NORM;
	*fpga0_cc = PL0_NORM;
	if (*arm_cc != ACPU_NORM || *fpga0_cc != PL0_NORM) {
		printf(" -- error: clocks_normal: clock configuration not set\n");
		return;
	}
#if defined VAR_DELAY && VAR_DELAY==_GDT_
	/* --- Configure the Gaussian Delay Tables (GTD) --- */
	sleep(1);
        #pragma message "Compiling " __FILE__ "..."
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + R_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + R_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + R_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + B_OFFSET, gdt_n0);
	clear_gdt((volatile void *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + R_OFFSET, gdt_n0);
	sleep(1);
	printf("Gaussian Delay Tables have been cleared\n");
	sleep(1);

//	volatile unsigned int *delay0 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_0_BASEADDR; /* slot 0, CPU SRAM W, R */
//	volatile unsigned int *delay1 = (unsigned int *)XPAR_DELAY_0_AXI_DELAY_1_BASEADDR; /* slot 0, CPU DRAM W, R */
//	delay0[2] = 0; delay0[4] = 0; delay1[2] = 0; delay1[4] = 0;
//#endif
//#if defined(XPAR_DELAY_1_AXI_DELAY_0_BASEADDR)
//	volatile unsigned int *delay2 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_0_BASEADDR; /* slot 1, ACC SRAM W, R */
//	volatile unsigned int *delay3 = (unsigned int *)XPAR_DELAY_1_AXI_DELAY_1_BASEADDR; /* slot 1, ACC DRAM W, R */
//	delay2[2] = 0; delay2[4] = 0; delay3[2] = 0; delay3[4] = 0;
#elif defined VAR_DELAY && (VAR_DELAY==_PWCLT106W85R_ || VAR_DELAY==_PWCLT400W200R_) && defined STD
	int *pwclt_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + sizeof(int));
    int *pwclt_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET);
    int *pwclt_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + sizeof(int));
	int *pwclt_cal_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
    int *pwclt_cal_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 2*sizeof(int));
    int *pwclt_cal_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + PWCLT_OFFSET + 3*sizeof(int));
	*pwclt_0_0_b = DISABLE_PWCLT; // CPU SRAM write response
	*pwclt_0_0_r = DISABLE_PWCLT; // CPU SRAM read response
	*pwclt_0_1_b = DISABLE_PWCLT; // CPU DRAM write response
	*pwclt_0_1_r = DISABLE_PWCLT; // CPU DRAM read response
	*pwclt_1_0_b = DISABLE_PWCLT; // Accererator SRAM write response
	*pwclt_1_0_r = DISABLE_PWCLT; // Accererator SRAM read response
	*pwclt_1_1_b = DISABLE_PWCLT; // Accererator DRAM write response
	*pwclt_1_1_r = DISABLE_PWCLT; // Accererator DRAM read response
	*pwclt_cal_0_0_b = 0; // CPU SRAM write calibration offset
	*pwclt_cal_0_0_r = 0; // CPU SRAM read calibration offset
	*pwclt_cal_0_1_b = 0; // CPU DRAM write calibration offset
	*pwclt_cal_0_1_r = 0; // CPU DRAM read calibration offset
	*pwclt_cal_1_0_b = 0; // Accererator SRAM write calibration offset
	*pwclt_cal_1_0_r = 0; // Accererator SRAM read calibration offset
	*pwclt_cal_1_1_b = 0; // Accererator DRAM write calibration offset
	*pwclt_cal_1_1_r = 0; // Accererator DRAM read calibration offset	
	printf("PWCLT configuration cleared.\n");
#endif
}

#endif /* ZYNQ */

#endif /* CLOCKS */
