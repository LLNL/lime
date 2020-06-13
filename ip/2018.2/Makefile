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

SUB := xilinx.com_user_axi_perf_mon_5.0

.PHONY: all
all:
	for i in $(SUB); do $(MAKE) -C $$i; done

.PHONY: clean
clean:
	for i in $(SUB); do $(MAKE) -C $$i clean; done
