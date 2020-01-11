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

# External Dependencies:
# $(WORKSPACE_LOC)/hw_platform_0/system_wrapper.bit
# $(WORKSPACE_LOC)/standalone_bsp_a53

.PHONY: all run
.DEFAULT all run:
	$(MAKE) -C mem/$(build) $@
	$(MAKE) -C strm/$(build) $@

.PHONY: fpga
fpga:
ifeq ($(build),zynq)
	$(XSDB) misc/sdk/fpga_config_z7.tcl $(HWP)
else ifeq ($(build),zup)
	$(XSDB) misc/sdk/fpga_config_zu.tcl $(HWP)
endif

run: fpga

.PHONY: clean
clean:
	$(MAKE) -C mem/zup clean
	$(MAKE) -C strm/arm_64 clean
	$(MAKE) -C strm/x86_64 clean
	$(MAKE) -C strm/zup clean
	$(MAKE) -C strm/zynq clean
