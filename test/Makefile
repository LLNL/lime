
# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

build = zup
WORKSPACE_LOC ?= ../standalone/sdk
HWP = $(WORKSPACE_LOC)/hw_platform_0
XSDB := xsdb$(if $(findstring Linux,$(shell uname -s)),,.bat)
APPS = mem strm 

# External Dependencies:
# $(WORKSPACE_LOC)/hw_platform_0/system_wrapper.bit
# $(WORKSPACE_LOC)/standalone_bsp_a53

.PHONY: all run
all run .DEFAULT:
	$(MAKE) -C mem/$(build) $@
	$(MAKE) -C strm/$(build) $@

.PHONY: help
help:
	@echo "Use the make variable 'build' to specify the executable type"
	@echo "and 'D' to specify comma separated compile time defines."
	@echo "Use 'RUN_ARGS' to specify main arguments in Standalone OS."
	@echo "Applications can also be built individually by typing 'make'"
	@echo "within one of the build directories (e.g., strm/zup)."
	@echo -e "\nTargets:"
	@echo "  <app>     - Build specific application:"
	@echo "              $(APPS)"
	@echo "              e.g., make strm"
	@echo "  all       - Build application set"
	@echo "  clean     - Remove files for all build types"
	@echo "  fpga      - Download bitfile to FPGA (Standalone only)"
	@echo "  run       - Build and run application set"
	@echo "              e.g., make run"
	@echo -e "\nbuild=<type>"
	@echo "  arm_64 - ARM : Linux"
	@echo "  x86_64 - x86 : Linux (default)"
	@echo "  zup    - ARM : Zynq UltraScale+ : Standalone"
	@echo "  zynq   - ARM : Zynq 7000        : Standalone"
	@echo "  e.g., make build=x86_64"
	@echo -e "\nD=DEF1[=VAL1],DEF2[=VAL2],..."
	@echo "  -- LiME Configuration Options --"
	@echo "  CLOCKS - enable clock scaling for emulation"
	@echo "  STATS  - print memory access statistics"
	@echo "  TRACE  - enable trace capture, =_TADDR_, =_TALL_"
	@echo "           _TADDR_ - capture only R/W address AXI events (default)"
	@echo "           _TALL_  - capture all AXI events"
	@echo "  USE_SD - use SD card for trace capture in Standalone OS"
	@echo "  e.g., make D=CLOCKS,STATS,TRACE=_TALL_"
	@echo -e "\nRUN_ARGS=\"-arg1 -arg2 ...\""
	@echo -e "\nARG=<str>"
	@echo "  <null> - use default argument set"
	@echo "  1      - use alternative argument set (larger data)"
	@echo "  e.g., make ARG=1"
	@echo -e "\nPreconditions:"
	@echo "  1) Xilinx tools in path"
	@echo "     e.g., source /opt/Xilinx/Vivado/<version>/settings64.sh"
	@echo "  2) Specify location of board support packages and hardware platform"
	@echo "     e.g., export WORKSPACE_LOC=\$$HOME/<mywork>/lime/standalone/sdk"

run: fpga

.PHONY: $(APPS)
$(APPS):
	$(MAKE) -C $@/$(build) all

.PHONY: fpga
fpga:
ifeq ($(build),zynq)
	$(XSDB) misc/sdk/fpga_config_z7.tcl $(HWP)
else ifeq ($(build),zup)
	$(XSDB) misc/sdk/fpga_config_zu.tcl $(HWP)
endif

.PHONY: clean
clean:
	$(MAKE) -C mem/zup clean
	$(MAKE) -C strm/arm_64 clean
	$(MAKE) -C strm/x86_64 clean
	$(MAKE) -C strm/zup clean
	$(MAKE) -C strm/zynq clean
