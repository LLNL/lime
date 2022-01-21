# Input: HLS source
# Output: generated HDL libraries

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

SUBDIR := $(patsubst %/,%,$(shell ls -d */))
TCLSH := $(if $(findstring win,$(shell uname -s)),xtclsh,tclsh)
IP = solution1/impl/ip/component.xml
TARG = $(addsuffix /$(IP),$(SUBDIR))

.PHONY: all
all: check.log

check.log: $(TARG)
	$(TCLSH) build_ip.tcl | tee check.log

.PRECIOUS: $(TARG)
$(TARG):
	vitis_hls -f $(firstword $(subst /, ,$@))/script.tcl

.PHONY: clean
clean:
	for i in $(SUBDIR); do $(RM) -r $$i/solution1 $$i/*.app; done
	$(RM) *.log

# TODO: move to Makefile in project subdirectory
compress/$(IP): \
  compress/compress.hpp \
  compress/compress.cpp \
  compress/compress_tb.cpp
eth_fifo_interface/$(IP): \
  eth_fifo_interface/eth_fifo_interface.hpp \
  eth_fifo_interface/eth_fifo_interface.cpp \
  eth_fifo_interface/eth_fifo_interface_tb.cpp
