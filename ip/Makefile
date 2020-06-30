# Input: library source
# Output: generated libraries

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

VERSION = $(if $(XILINX_VIVADO),$(notdir $(XILINX_VIVADO)),$(error Vivado environment not set))
SUB := $(patsubst %/,%,$(shell ls -d 2*/)) hls

.PHONY: all
all:
	for i in $(SUB); do $(MAKE) -C $$i; done

.PHONY: clean
clean:
	for i in $(SUB); do $(MAKE) -C $$i clean; done
