ifneq ($(KERNELRELEASE),)
# kbuild part of makefile
obj-$(CONFIG_LMCACHE) += lmcache.o
lmcache-y := lmcache_ops.o $(ARCH)/xil_cache.o
obj-$(CONFIG_LMALLOC) += lmalloc.o
ccflags-y := -I$(src)/$(ARCH)

else
# normal makefile
export ARCH := arm64
export CROSS_COMPILE := aarch64-linux-gnu-

ifneq ($(wildcard ../../../linux-xlnx),)
  KDIR ?= ../..
else ifneq ($(wildcard ../linux-xlnx),)
  KDIR ?= ../linux-xlnx
else
  KDIR ?= /lib/modules/`uname -r`/build
endif
PWD := $(shell pwd)

.PHONY: modules
modules:
	$(MAKE) -C $(KDIR) M=$(PWD) CONFIG_LMCACHE=m CONFIG_LMALLOC=m modules

.PHONY: clean
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

.PHONY: kpatch
kpatch:
	# sed -i.bak '$$a\EXPORT_SYMBOL_GPL(__flush_dcache_area);\nEXPORT_SYMBOL_GPL(__inval_dcache_area);' $(KDIR)/arch/arm64/mm/flush.c
	sed -i.bak '$$a\EXPORT_SYMBOL_GPL(arch_setup_dma_ops);' $(KDIR)/arch/arm64/mm/dma-mapping.c
	sed -i.bak '$$a\#include <linux/export.h>\nEXPORT_SYMBOL_GPL(dma_alloc_from_contiguous);\nEXPORT_SYMBOL_GPL(dma_release_from_contiguous);' $(KDIR)/kernel/dma/contiguous.c

endif
