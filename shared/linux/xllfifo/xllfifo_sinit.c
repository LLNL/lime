/******************************************************************************
*
* Copyright (C) 2013 - 2018 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*
*
*
******************************************************************************/
/*****************************************************************************/
/**
*
* @file xllfifo_sinit.c
* @addtogroup llfifo_v5_3
* @{
*
* This file contains static initialization functionality for Axi Streaming FIFO
* driver.
*
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who  Date     Changes
* ----- ---- -------- -------------------------------------------------------
* 3.00a adk 9/10/2013 initial release
* </pre>
*
******************************************************************************/

/***************************** Include Files *********************************/

// #include "xparameters.h"
#include "devtree.h"
#include "xllfifo.h"

#define DEV_TREE "/sys/firmware/devicetree/base/amba_pl@0"

/*****************************************************************************/
/**
 * Look up the hardware configuration for a device instance
 *
 * @param	DeviceId is the unique device ID of the device to lookup for
 *
 * @return
 *		The configuration structure for the device. If the device ID is
 *		not found,a NULL pointer is returned.
 *
 * @note	None
 *
 ******************************************************************************/
XLlFifo_Config *XLlFfio_LookupConfig(u32 DeviceId)
{
	extern XLlFifo_Config XLlFifo_ConfigTable[];
	struct {uint64_t len, addr;} reg;
	u32 ditype;
	int found;

	if (DeviceId >= XLLFIFO_NUM_INSTANCES) return NULL;
	if (XLlFifo_ConfigTable[DeviceId].BaseAddress == 0) {
		found = dev_search(DEV_TREE, "axi_fifo_mm_s", DeviceId+1, "reg", &reg, sizeof(reg));
		if (found != 1) return NULL;
		found = dev_search(DEV_TREE, "axi_fifo_mm_s", DeviceId+1, "xlnx,data-interface-type", &ditype, sizeof(ditype));
		if (found != 1) return NULL;
		XLlFifo_ConfigTable[DeviceId].DeviceId = DeviceId;
		XLlFifo_ConfigTable[DeviceId].BaseAddress = reg.addr;
		XLlFifo_ConfigTable[DeviceId].Datainterface = ditype;
	}
	return &XLlFifo_ConfigTable[DeviceId];
}
/** @} */
