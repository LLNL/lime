# Cancel version control implicit rules
# %:: %,v
# %:: RCS/%
# %:: RCS/%,v
# %:: s.%
# %:: SCCS/s.%
# # Delete default suffixes
# .SUFFIXES:
#

# LC_ALL="C"
BUILD_PATH=`pwd`

.PHONY: all

all: image.ub

setup:
	mkdir -p hardware
	mkdir -p xsct_ws
	cp ../standalone/vitis/final/hw/final.xsa hardware

xsct_ws/zynqmp_pmufw/Release/zynqmp_pmufw.elf: 
	xsct build-fsbl-pmu.tcl

arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf:
	git clone https://github.com/Xilinx/arm-trusted-firmware.git
	(cd arm-trusted-firmware && git checkout xilinx-v2020.1 && make PLAT=zynqmp bl31)

device-tree-linux:
	git clone https://github.com/Xilinx/device-tree-xlnx
	(cd device-tree-xlnx && git checkout xlnx_rel_v2020.1)
	#get device tree compiler
	git clone https://git.kernel.org/pub/scm/utils/dtc/dtc.git
	(cd dtc && make && export PATH=`pwd`:$(PATH))
dts/system.dtb: 
	# built dts
	xsct build-dts.tcl
	## fix up
	sh dts-fixup.txt
	## build dtb
	gcc -Idts -Idevice-tree-xlnx/device_tree/data/kernel_dtsi/2020.1 -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o dts/system.dts dts/system-top.dts
	./dtc/dtc -I dts -O dtb -o dts/system.dtb dts/system.dts
	dtc/dtc -I dts -O dtb -o dts/system.dtb dts/system.dts

get-u-boot:
	(git clone https://github.com/Xilinx/u-boot-xlnx.git && cd u-boot-xlnx && git checkout xilinx-v2020.01)
u-boot-xlnx/u-boot.elf:
	cd u-boot-xlnx &&\
	#export CROSS_COMPILE=aarch64-linux-gnu- &&\
	#export ARCH=aarch64 &&\
	export PATH=../dtc:$(PATH) &&\
	make distclean &&\
	make xilinx_zynqmp_virt_defconfig &&\
	make -j 16 CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm DEVICE_TREE="zynqmp-zcu102-rev1.0"
	echo "u-boot.elf building done" 

get-linux-xlnx:
	(git clone https://github.com/Xilinx/linux-xlnx.git; cd linux-xlnx; git checkout xilinx-v2021.1)

linux-xlnx/arch/arm64/boot/Image: 
	sh build-linux.txt


image.ub: \
setup \
xsct_ws/zynqmp_pmufw/Release/zynqmp_pmufw.elf \
arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf \
u-boot-xlnx/u-boot.elf \
dts/system.dtb \
linux-xlnx/arch/arm64/boot/Image
	(PATH=dtc:$PATH ./u-boot-xlnx/tools/mkimage -f fit_image.its image.ub	)

.PHONY: clean
clean:
	$(RM) -r .Xil
	$(RM) -r xsct_ws
	$(RM) -r hardware
	$(RM) -r device-tree-xlnx
	$(RM) -r dts
	$(RM) -r dtc
	$(RM) -r arm-trusted-firmware
	$(RM) -r u-boot-xlnx
	$(MAKE) -iC drivers clean
	$(RM) -r linux-xlnx
	$(MAKE) -C boot clean
