# Input: final.xsa, .tcl scripts
# Output: hw_platform, standalone_bsp_*

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

SYS = ../system
XSA = $(SYS)/final.xsa
BDF = $(SYS)/board
BIT = vitis/final/hw/final.bit
BOARD := $(word 2,$(subst :, ,$(shell cat $(BDF))))
XSCT := xsct$(if $(findstring Linux,$(shell uname -s)),,.bat)

.PHONY: all
all: $(BIT)
	#@echo "BOARD: $(BOARD)"

# Build Vitis Projects (hw_platform, BSPs)
# Projects are built together sequentially by a single script because
# the Vitis leaves history in .metadata that obstructs separate 'makes'.
$(BIT): $(XSA) $(BDF)
	mkdir -p vitis
	-$(RM) -r vitis/* vitis/.metadata
	$(XSCT) vitis.tcl $(XSA)

.PHONY: clean
clean:
	$(RM) -r .Xil vitis
