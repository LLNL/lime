/*
 * lmalloc.c - LiME allocation driver
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
#include <asm/dma-mapping.h> /* arch_setup_dma_ops, before linux/dma-mapping.h */
#include <linux/dma-mapping.h> /* dma_alloc_attrs, dma_free_attrs, dma_mmap_attrs */

#include "lmalloc.h"

#define DEV_NAME "lmalloc"
#define CLASS_NAME "lmalloc"

#ifdef DEBUG
#define printk_dbg(fmt,...) printk(KERN_DEBUG   "LiME alloc: " fmt, ## __VA_ARGS__)
#else
#define printk_dbg(fmt,...)
#endif
#define printk_inf(fmt,...) printk(KERN_INFO    "LiME alloc: " fmt, ## __VA_ARGS__)
#define printk_wrn(fmt,...) printk(KERN_WARNING "LiME alloc: " fmt, ## __VA_ARGS__)
#define printk_err(fmt,...) printk(KERN_ERR     "LiME alloc: " fmt, ## __VA_ARGS__)

static struct class* dev_class;
static dev_t devno;
static struct device *dev;


static inline void print_vma(struct vm_area_struct *vma)
{
	printk_dbg("vm_start: 0x%016lx\n", vma->vm_start);
	printk_dbg("vm_end: 0x%016lx\n", vma->vm_end);
	printk_dbg("vm_page_prot: 0x%016llx\n", pgprot_val(vma->vm_page_prot));
	printk_dbg("vm_flags: 0x%lx\n", vma->vm_flags);
	printk_dbg("vm_ops: 0x%p\n", vma->vm_ops);
	printk_dbg("vm_pgoff: 0x%016lx\n", vma->vm_pgoff);
	printk_dbg("vm_file: 0x%p\n", vma->vm_file);
	printk_dbg("vm_private_data: 0x%p\n", vma->vm_private_data);
}

static long lma_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
	lma_t lma;

	printk_dbg("ioctl cmd: 0x%08x\n", cmd);
	printk_dbg("ioctl arg: 0x%016lx\n", arg);

	if (cmd & IOC_IN) {
		if (copy_from_user(&lma, (void*)arg, sizeof(lma_t))) {
			printk_dbg("failed to copy from user\n");
			return -EACCES;
		}
	}

	switch (_IOC_NR(cmd))
	{
#if 0
	case cmd_tran: {
		printk_dbg("cmd_tran addr: 0x%p\n", lma.addr);
		/* has trouble with high addresses. error: Cannot do DMA to address YYY. Creates bounce buffer */
		lma.paddr = dma_map_single(dev, lma.addr, PAGE_SIZE, DMA_BIDIRECTIONAL);
		if (dma_mapping_error(dev, lma.paddr)) {
			printk_dbg("failed to map page\n");
			return -EACCES;
		}
		printk_dbg("cmd_tran paddr: 0x%016lx\n", lma.paddr);
		} break;
#endif
#if 0
	case cmd_tran: {
		int ret;
		struct page *pg;
		unsigned long start = (unsigned long)lma.addr & PAGE_MASK;
		printk_dbg("cmd_tran addr: 0x%p\n", lma.addr);
		/* will not work for vmas with VM_IO or VM_PFNMAP flags set */
		if ((ret = get_user_pages_fast(start, 1, 0, &pg)) != 1) {
			printk_dbg("failed to get user page, ret: %d\n", ret);
			return -EACCES;
		}
		lma.paddr = page_to_phys(pg) | ((unsigned long)lma.addr & ~PAGE_MASK);
		printk_dbg("cmd_tran paddr: 0x%016lx\n", lma.paddr);
		} break;
#endif
	case cmd_tran: {
		int ret = -EACCES;
		struct mm_struct *mm = current->mm;
		unsigned long start = (unsigned long)lma.addr & PAGE_MASK;
		unsigned long offset = (unsigned long)lma.addr & ~PAGE_MASK;
		unsigned long pfn;
		struct vm_area_struct *vma;

		printk_dbg("cmd_tran addr: 0x%p\n", lma.addr);
		down_read(&mm->mmap_sem);
		vma = find_vma(mm, start);
		if (vma) ret = follow_pfn(vma, start, &pfn);
		up_read(&mm->mmap_sem);
		if (!ret) lma.paddr = PFN_PHYS(pfn)+offset;
		printk_dbg("cmd_tran paddr: 0x%016lx\n", lma.paddr);
		if (ret) return ret;
		} break;
	case cmd_free:
		printk_dbg("cmd_free addr: 0x%p\n", lma.addr);
		// TODO: unmap and free
		break;
	default:
		printk_dbg("cmd_none\n");
		return -EINVAL;
		break;
	}

	if (cmd & IOC_OUT) {
		if (copy_to_user((void*)arg, &lma, sizeof(lma_t))) {
			printk_dbg("failed to copy to user\n");
			return -EACCES;
		}
	}

	return 0;
}

static int lma_mmap(struct file *f, struct vm_area_struct *vma)
{
	int ret;
	void *cpu_addr;
	dma_addr_t dma_addr;
	size_t size = PAGE_ALIGN(vma->vm_end - vma->vm_start);
	gfp_t flags = GFP_TRANSHUGE; // GFP_KERNEL, GFP_HIGHUSER, GFP_TRANSHUGE, GFP_USER
	unsigned long dma_attrs = DMA_ATTR_FORCE_CONTIGUOUS|DMA_ATTR_NO_KERNEL_MAPPING|DMA_ATTR_SKIP_CPU_SYNC;

	print_vma(vma);

	cpu_addr = dma_alloc_attrs(dev, size, &dma_addr, flags, dma_attrs);
	if (!cpu_addr) {
		printk_err("failed to allocate memory\n");
		return -ENOMEM;
	}
	printk_dbg("lma_mmap cpu_addr: 0x%p\n", cpu_addr);

	ret = dma_mmap_attrs(dev, vma, cpu_addr, dma_addr, size, dma_attrs);
	if (ret < 0) {
		printk_err("failed to mmap\n");
		return ret;
	}
	printk_dbg("lma_mmap dma_addr: 0x%016llx\n", dma_addr);

	printk_dbg("lma_mmap vm_flags: 0x%lx\n", vma->vm_flags);
	// vma->vm_flags |= VM_*;
	// vma->vm_ops = &vm_ops;

	// TODO: save in hash table
	return 0;
}

static const struct file_operations lma_fops =
{
	.owner = THIS_MODULE,
	.unlocked_ioctl = lma_ioctl,
	.mmap = lma_mmap
};

static int __init lma_init(void)
{
	printk_inf("initializing module\n");
	dev_class = class_create(THIS_MODULE, CLASS_NAME);
	if (IS_ERR(dev_class)) {
		printk_err("failed to create device class\n");
		return PTR_ERR(dev_class);
	}

	devno = register_chrdev(0, DEV_NAME, &lma_fops);
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

	/* gfp_t flags during alloc must include __GFP_DIRECT_RECLAIM */
	/* (see linux/gpf.h), or the coherent flag must be false to get */
	/* call to dma_alloc_from_contiguous(). */
	/* If coherent flag is false, a remap can occur on allocation. */
	/* See __dma_alloc() in kdir/arch/arm64/mm/dma-mapping.c */

	/* arch_setup_dma_ops will attach arch specific dma ops to device. */
	/* The parameters dma_base, size, & iommu are ignored for arm64. */
	arch_setup_dma_ops(dev, 0, 0, NULL, false);

	/* TODO: could also configure coherent memory pool */

	return 0;
}

static void __exit lma_exit(void)
{
	device_destroy(dev_class, MKDEV(devno, 0));
	unregister_chrdev(devno, DEV_NAME);

	// class_unregister(dev_class);
	class_destroy(dev_class);
	printk_inf("exiting module\n");
}

module_init(lma_init);
module_exit(lma_exit);

MODULE_LICENSE("Dual MIT/GPL");
MODULE_AUTHOR("Scott Lloyd");
MODULE_DESCRIPTION("LiME memory allocation and translation");
MODULE_VERSION("0.3");
