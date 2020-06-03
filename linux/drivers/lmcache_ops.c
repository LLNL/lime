/*
 * lmcache.c - LiME cache driver
 *
 * Copyright (c) 2020, Lawrence Livermore National Security, LLC.
 * Produced at the Lawrence Livermore National Laboratory.
 * Written by
 *   G. Scott Lloyd, lloyd23@llnl.gov
 *
 * LLNL-CODE-??????.
 * All rights reserved.
 * 
 * This file is part of LiME. For details, see
 * http://???/lime
 * Please also read – Additional ??? Notice.
 */

#include <linux/module.h>
#include <linux/version.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/uaccess.h>
#include <linux/err.h>
// #include <asm/cacheflush.h>

#include "lmcache.h"
#include "xil_cache.h"

#define DEV_NAME "lmcache"
#define CLASS_NAME "lmcache"

#ifdef DEBUG
#define printk_dbg(fmt,...) printk(KERN_DEBUG   "LiME cache: " fmt, ## __VA_ARGS__)
#else
#define printk_dbg(fmt,...)
#endif
#define printk_inf(fmt,...) printk(KERN_INFO    "LiME cache: " fmt, ## __VA_ARGS__)
#define printk_wrn(fmt,...) printk(KERN_WARNING "LiME cache: " fmt, ## __VA_ARGS__)
#define printk_err(fmt,...) printk(KERN_ERR     "LiME cache: " fmt, ## __VA_ARGS__)

static struct class* dev_class;
static dev_t devno;
static struct device *dev;


static long lmc_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
	rng_t rng;

	if (cmd & IOC_IN) {
		size_t sz = _IOC_SIZE(cmd);
		if (sz > sizeof(rng_t)) return -EINVAL;
		if (copy_from_user(&rng, (void*)arg, sz)) return -EACCES;
	}

	switch (_IOC_NR(cmd))
	{
	case cmd_d_flush:
		// TODO: no arm64 flush_dcache_all implemented in kernel
		Xil_DCacheFlush();
		break;
	case cmd_d_flush_rng:
		// __flush_dcache_area(rng.addr, rng.size);
		// __dma_clear_area(rng.addr, rng.size);
		Xil_DCacheFlushRange((INTPTR)rng.addr, rng.size);
		break;
	case cmd_d_invalidate:
		// TODO: no arm64 inv_dcache_all implemented in kernel
		Xil_DCacheInvalidate();
		break;
	case cmd_d_invalidate_rng:
		// __inval_dcache_area(rng.addr, rng.size);
		// __dma_inv_area(rng.addr, rng.size);
		Xil_DCacheInvalidateRange((INTPTR)rng.addr, rng.size);
		break;
	default:
		return -EINVAL;
		break;
	}
	return 0;
}

static const struct file_operations lmc_fops =
{
	.owner = THIS_MODULE,
	.unlocked_ioctl = lmc_ioctl
};

static int __init lmc_init(void)
{
	printk_inf("initializing module\n");
	dev_class = class_create(THIS_MODULE, CLASS_NAME);
	if (IS_ERR(dev_class)) {
		printk_err("failed to create device class\n");
		return PTR_ERR(dev_class);
	}

	devno = register_chrdev(0, DEV_NAME, &lmc_fops);
	if (devno < 0) {
		printk_err("failed to register device\n");
		class_destroy(dev_class);
		return devno;
	}
	printk_inf("<major, minor>: <%d, %d>\n", MAJOR(devno), MINOR(devno));

	dev = device_create(dev_class, NULL, MKDEV(devno, 0), NULL, DEV_NAME);
	if (IS_ERR(dev)) {
		unregister_chrdev(devno, DEV_NAME);
		class_destroy(dev_class);
		printk_err("failed to create device\n");
		return PTR_ERR(dev);
	}

	return 0;
}

static void __exit lmc_exit(void)
{
	device_destroy(dev_class, MKDEV(devno, 0));
	unregister_chrdev(devno, DEV_NAME);

	// class_unregister(dev_class);
	class_destroy(dev_class);
	printk_inf("exiting module\n");
}

module_init(lmc_init);
module_exit(lmc_exit);

MODULE_LICENSE("Dual MIT/GPL");
MODULE_AUTHOR("Scott Lloyd");
MODULE_DESCRIPTION("LiME cache management");
MODULE_VERSION("0.3");
