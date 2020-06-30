# Input: system_wrapper.hdf, .tcl scripts
# Output: hw_platform_0, standalone_bsp_*

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
BIT = sdk/hw_platform_0/system_wrapper.bit
BOARD := $(word 2,$(subst :, ,$(shell cat $(BDF))))
XSCT := xsct$(if $(findstring Linux,$(shell uname -s)),,.bat)

.PHONY: all
all: $(BIT)
	@echo "BOARD: $(BOARD)"

# Build SDK Projects (hw_platform_0, BSPs)
# Projects are built together sequentially by a single script because
# the SDK leaves history in .metadata that obstructs separate 'makes'.
$(BIT): $(HDF) $(BDF)
	mkdir -p sdk
	-$(RM) -r sdk/* sdk/.metadata
	$(XSCT) sdk.tcl $(HDF)

.PHONY: clean
clean:
	$(RM) -r .Xil sdk
