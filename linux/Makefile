# Input: system_wrapper.hdf, .tcl scripts
# Output: bootfiles.tar.xz

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

SYS = ../system
HDF = $(SYS)/system_wrapper.hdf
BDF = $(SYS)/board
ifneq ($(wildcard $(BDF)),)
BOARD := $(word 2,$(subst :, ,$(shell cat $(BDF))))
endif
XSCT := xsct$(if $(findstring Linux,$(shell uname -s)),,.bat)
# LN := cp -l
LN := ln -s

.PHONY: all
all: boot/bootfiles.tar.xz
	@echo "BOARD: $(BOARD)"

dtc/Makefile:
	git clone https://git.kernel.org/pub/scm/utils/dtc/dtc.git

device-tree-xlnx:
	git clone https://github.com/Xilinx/device-tree-xlnx.git
	cd device-tree-xlnx &&\
	git checkout xilinx-v2018.2

arm-trusted-firmware/Makefile:
	git clone https://github.com/Xilinx/arm-trusted-firmware.git
	cd arm-trusted-firmware &&\
	git checkout xilinx-v2018.2

u-boot-xlnx/Makefile:
	git clone https://github.com/Xilinx/u-boot-xlnx.git
	cd u-boot-xlnx &&\
	git checkout xilinx-v2018.2

DEFCONFIG = linux-xlnx/arch/arm64/configs/xilinx_zynqmp_defconfig
linux-xlnx/Makefile:
	git clone https://github.com/Xilinx/linux-xlnx.git
	cd linux-xlnx &&\
	git checkout xlnx_rebase_v4.14_2018.2
	# Include LiME drivers in kernel source tree
	$(LN) -rf drivers linux-xlnx/drivers/lime
	sed -i.bak '/endmenu/i\source "drivers/lime/Kconfig"\n' linux-xlnx/drivers/Kconfig
	sed -i.bak '$$a\\nobj-y += lime/' linux-xlnx/drivers/Makefile
	sed -i.bak '$$a\CONFIG_LMCACHE=y\nCONFIG_LMALLOC=y' $(DEFCONFIG)
	$(MAKE) -C linux-xlnx/drivers/lime kpatch
ifneq ($(findstring zcu102,$(BOARD)),)
	# Fix for slowness caused by disabled caches and the DRM KMS driver
	sed -i.bak '/CONFIG_DRM_XLNX=y/c\# CONFIG_DRM_XLNX=y' $(DEFCONFIG)
	# Remove all the other DRM stuff just in case
	sed -i.bak '/CONFIG_DRM=y/c\# CONFIG_DRM=y' $(DEFCONFIG)
	sed -i.bak '/CONFIG_DRM_XILINX=y/c\# CONFIG_DRM_XILINX=y' $(DEFCONFIG)
	# Remove the displayport stuff that is causing panic on boot
	sed -i.bak '/CONFIG_SND_SOC_XILINX_DP=y/c\# CONFIG_SND_SOC_XILINX_DP=y' $(DEFCONFIG)
	sed -i.bak '/CONFIG_VIDEO_XILINX=y/c\# CONFIG_VIDEO_XILINX=y' $(DEFCONFIG)
	# Remove usb driver causing panic on shutdown
	sed -i.bak '/CONFIG_USB_XHCI_HCD=y/c\# CONFIG_USB_XHCI_HCD=y' $(DEFCONFIG)
endif

# Build SDK Projects (hw_platform_0, BSPs, FSBL, PMUFW)
# Projects are built together sequentially by a single script because
# the SDK leaves history in .metadata that obstructs separate 'makes'.
sdk/pmufw/Release/pmufw.elf: $(HDF) $(BDF)
	mkdir -p sdk
	-$(RM) -r sdk/* sdk/.metadata
	$(XSCT) sdk.tcl $(HDF)

# Build DTS
# Dependent on sdk/hw_platform_0 but using pmufw.elf instead
dts/system-top.dts: sdk/pmufw/Release/pmufw.elf device-tree-xlnx
	$(RM) -r dts
	$(XSCT) dts.tcl
	sed -i.bak '/fclk0: fclk0 {/,/status = "disabled";/c\\tfclk0: fclk0 {\n\t\tstatus = "okay";' dts/zynqmp-clk-ccf.dtsi
	sed -i.bak '/fclk1: fclk1 {/,/status = "disabled";/c\\tfclk1: fclk1 {\n\t\tstatus = "okay";' dts/zynqmp-clk-ccf.dtsi
	# Enable setting CPU frequency to 137.5 MHz via /sys/devices/system/cpu/cpufreq/policy0
	# For more information see https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18841831/CPU+frequency+scaling
	sed -i.bak -e 's/opp-hz = \/bits\/ 64 <299999997>/opp-hz = \/bits\/ 64 <137500000>/g' dts/zynqmp.dtsi
ifneq ($(findstring sidewinder,$(BOARD)),)
	sed -i.bak '/memory {/,/};/c\\tmemory {\n\t\tdevice_type = "memory";\n\t\tlinux,usable-memory = <0x10 0x00000000 0x4 0x00000000>;\n\t};' dts/system-top.dts
	sed -i.bak '/&sdhci1 {/ a\\tno-1-8-v;\n\tdisable-wp;' dts/pcw.dtsi
else ifneq ($(findstring zcu102,$(BOARD)),)
	cp device-tree-xlnx/device_tree/data/kernel_dtsi/2018.2/BOARD/zcu102-rev1.0.dtsi dts
	sed -i.bak '\_/ {_i\/include/ "zcu102-rev1.0.dtsi"' dts/system-top.dts
	sed -i.bak '/memory {/,/};/c\\tmemory {\n\t\tdevice_type = "memory";\n\t\tlinux,usable-memory = <0x10 0x00000000 0x1 0x00000000>;\n\t};' dts/system-top.dts
	# Disable drivers causing kernel panic during boot
	sed -i.bak '/&xlnx_dpdma {/,/};/c\&xlnx_dpdma {\n\tstatus = "disabled";\n};' dts/pcw.dtsi
	sed -i.bak '/&zynqmp_dp_snd_pcm0 {/,/};/c\&zynqmp_dp_snd_pcm0 {\n\tstatus = "disabled";\n};' dts/pcw.dtsi
	sed -i.bak '/&zynqmp_dp_snd_pcm1 {/,/};/c\&zynqmp_dp_snd_pcm1 {\n\tstatus = "disabled";\n};' dts/pcw.dtsi
	sed -i.bak '/&zynqmp_dp_snd_card0 {/,/};/c\&zynqmp_dp_snd_card0 {\n\tstatus = "disabled";\n};' dts/pcw.dtsi
	sed -i.bak '/&zynqmp_dp_snd_codec0 {/,/};/c\&zynqmp_dp_snd_codec0 {\n\tstatus = "disabled";\n};' dts/pcw.dtsi
	sed -i.bak '/&zynqmp_dpsub {/,/};/c\&zynqmp_dpsub {\n\tphy-names = "dp-phy0","dp-phy1";\n\tphys = <&lane1 5 0 3 27000000>,\n\t\t<&lane0 5 1 3 27000000>;\n\tstatus = "disabled";\n\txlnx,max-lanes = <2>;\n};' dts/pcw.dtsi
	# Disable drivers causing panic during shutdown
	sed -i.bak '/&usb0 {/,/};/c\&usb0 {\n\tstatus = "disabled";\n\txlnx,usb-reset = <0x2faf080>;\n};' dts/pcw.dtsi
endif

# Build Device Tree Compiler (dtc)
dtc/dtc: dtc/Makefile
	$(MAKE) -C dtc

# Build DTB
dts/system.dtb: dtc/dtc dts/system-top.dts
	cd dts && ../dtc/dtc -I dts -O dtb -o system.dtb system-top.dts

# Build Arm Trusted Firmware (ATF)
arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf: arm-trusted-firmware/Makefile
	cd arm-trusted-firmware &&\
	export CROSS_COMPILE=aarch64-linux-gnu- &&\
	export ARCH=arm64 &&\
	$(MAKE) PLAT=zynqmp RESET_TO_BL31=1

# Build U-Boot
u-boot-xlnx/u-boot.elf: u-boot-xlnx/Makefile
	cd u-boot-xlnx &&\
	export CROSS_COMPILE=aarch64-linux-gnu- &&\
	export ARCH=aarch64 &&\
	$(MAKE) distclean &&\
	$(MAKE) xilinx_zynqmp_zcu102_rev1_0_defconfig &&\
	$(MAKE)

# Build Linux Kernel
linux-xlnx/arch/arm64/boot/Image: linux-xlnx/Makefile $(if $(filter kernel,$(MAKECMDGOALS)),FORCE)
	cd linux-xlnx &&\
	export CROSS_COMPILE=aarch64-linux-gnu- &&\
	export ARCH=arm64 &&\
	$(MAKE) xilinx_zynqmp_defconfig &&\
	echo $(MAKE) menuconfig &&\
	$(MAKE) -j `getconf _NPROCESSORS_ONLN`
FORCE: ;

.PHONY: kernel
kernel: all

# Build Boot Files
# FSBL and .bit file are built with PMUFW
# sdk/fsbl/Release/fsbl.elf
# sdk/hw_platform_0/system_wrapper.bit
boot/bootfiles.tar.xz: \
sdk/pmufw/Release/pmufw.elf \
arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf \
u-boot-xlnx/u-boot.elf \
boot/uEnv.txt \
dts/system.dtb \
linux-xlnx/arch/arm64/boot/Image
	$(MAKE) -C boot clean
	$(MAKE) -C boot

.PHONY: clean
clean:
	$(RM) -r .Xil
	$(RM) -r sdk
	$(RM) -r device-tree-xlnx
	$(RM) -r dts
	$(RM) -r dtc
	$(RM) -r arm-trusted-firmware
	$(RM) -r u-boot-xlnx
	$(MAKE) -iC drivers clean
	$(RM) -r linux-xlnx
	$(MAKE) -C boot clean
