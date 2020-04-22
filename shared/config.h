/*
 * config.h
 *
 *  Created on: Sep 15, 2014
 *      Author: lloyd23
 */

#ifndef CONFIG_H_
#define CONFIG_H_

//----- LiME Configuration Options -----//
// defined(CLOCKS) : enable clock scaling for emulation
// defined(STATS)  : print memory access statistics
#define _TADDR_ 1 // R/W address AXI events
#define _TALL_  2 // all AXI events
// defined(TRACE)  : enable trace capture, =_TADDR_, =_TALL_

// defined(ENTIRE) : flush/invalidate entire cache
#define _Z7_ 2 // Zynq-7000
#define _ZU_ 3 // Zynq UltraScale+
// defined(ZYNQ)     : target the Zynq platform, =_Z7_, =_ZU_
//                   : implies Standalone OS and usage of xparameters.h & Xil_ functions
//                   : differentiate compiler with defined(__ARM_ARCH) or defined(__microblaze__)
// defined(USE_MARG) : get arguments from MARGS macro (string)

//----- Accelerator Options -----//
// defined(STOCK)   : host executes stock algorithm with no accelerator
// defined(DIRECT)  : host executes accelerator algorithm with direct calls
// defined(CLIENT)  : enable protocol & client methods for sending commands to server (MCU)
// defined(SERVER)  : enable protocol & command server for the accelerator
// defined(OFFLOAD) : offload work from host to accelerator (no MCU)

//----- Hardware Usage -----//
// defined(USE_LSU)   : use the load-store unit, implies using LSU0 for data movement
// defined(USE_DMAC)  : use the ARM DMA controller
// defined(USE_INDEX) : use index command in LSU
// defined(USE_HASH)  : use the hash unit, implies using full pipeline ({MCU0,} LSU1, HSU0, LSU2, flow, & probe)
// defined(USE_SP)    : use scratch pad memory
// defined(USE_OCM)   : use on-chip memory (SRAM) for scratch pad, otherwise use special DRAM section
// defined(USE_SD)    : use SD card for trace capture

//----- Compiler Macros -----//
// defined(__microblaze__) : MicroBlaze architecture
// defined(__ARM_ARCH)     : ARM architecture 32-bit or 64-bit
// defined(__aarch64__)    : ARM architecture 64-bit
// defined(__linux__)      : Linux OS

#if defined(CLIENT) || defined(SERVER) || defined(OFFLOAD)
// use stream communication and aport protocols
// also implies the need for explicit cache management
#define USE_STREAM 1
#endif

#if defined(DIRECT) || defined(CLIENT) || defined(SERVER) || defined(OFFLOAD)
// use accelerator or engine code
#define USE_ACC 1
#endif

#if defined(USE_LSU)
// use index command in LSU
#define USE_INDEX 1
#endif

#if defined(ZYNQ) || (defined(__ARM_ARCH) && defined(USE_STREAM))
// use Xilinx cache API
#define XCACHE 1
#endif

#endif /* CONFIG_H_ */
