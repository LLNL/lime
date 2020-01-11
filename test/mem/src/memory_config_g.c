#include "memory_config.h"
#include "xparameters.h"

#define toUL(n) ((unsigned long)n)

#if defined(XPAR_PSU_DDR_0_S_AXI_BASEADDR)
#define DDR0_SZ (toUL(XPAR_PSU_DDR_0_S_AXI_HIGHADDR)-toUL(XPAR_PSU_DDR_0_S_AXI_BASEADDR)+1)
#else
#define DDR0_SZ 0x0UL
#endif

#if defined(XPAR_PSU_DDR_1_S_AXI_BASEADDR)
#define DDR1_SZ (toUL(XPAR_PSU_DDR_1_S_AXI_HIGHADDR)-toUL(XPAR_PSU_DDR_1_S_AXI_BASEADDR)+1)
#else
#define DDR1_SZ 0x0UL
#endif

#if defined(XPAR_DELAY_0_AXI_SHIM_0_BASEADDR)
#define SHIM_SZ (toUL(XPAR_DELAY_0_AXI_SHIM_0_HIGHADDR)-toUL(XPAR_DELAY_0_AXI_SHIM_0_BASEADDR)+1)
#undef DDR1_SZ
#define DDR1_SZ SHIM_SZ
#else
#define SHIM_SZ 0x0UL
#endif

/* For some reason, Xilinx's mem test reserves a few bytes at the beginning
 * of the DDR_0 range and 1M at the end. e.g.
		XPAR_PSU_DDR_0_S_AXI_BASEADDR+0x80,
		DDR0_SZ-0x80-0x100000,
 * The alias test will fail if the base address here is offset
 * differently from the other regions.
 */

struct memory_range_s memory_ranges[] = {
#if defined(XPAR_PSU_DDR_0_S_AXI_BASEADDR)
	{
		"psu_ddr_0_MEM_0",
		"psu_ddr_0",
		XPAR_PSU_DDR_0_S_AXI_BASEADDR,
		DDR0_SZ,
	},
#endif
#if defined(XPAR_PSU_DDR_1_S_AXI_BASEADDR)
	{
		"psu_ddr_1_MEM_0",
		"psu_ddr_1",
		XPAR_PSU_DDR_1_S_AXI_BASEADDR,
		DDR1_SZ,
	},
#endif
#if defined(XPAR_DELAY_0_AXI_SHIM_0_BASEADDR)
	{
		"axi_shim_0_mem0",
		"axi_shim_0",
		XPAR_DELAY_0_AXI_SHIM_0_BASEADDR,
		SHIM_SZ,
	},
#endif
	/* psu_ocm_ram_0_MEM_0 memory will not be tested since application resides in the same memory */
};

int n_memory_ranges = sizeof(memory_ranges)/sizeof(struct memory_range_s);
