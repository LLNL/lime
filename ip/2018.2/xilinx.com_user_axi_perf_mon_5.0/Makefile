# Input: patch difference
# Output: modified library components

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

IP_DIF = patch/source.diff
IP_SRC = axi_perf_mon_v5_0
IP_DST = $(notdir $(CURDIR))
IP_DIR := $(subst \,/,$(XILINX_VIVADO))/data/ip/xilinx
SOURCES := $(notdir $(wildcard $(IP_DIR)/$(IP_SRC)/*))

# Caution: A potential circular dependency exists through the patch file.

.PHONY: all
all: component.xml

# Keep timestamps on source files for inclusion in patch
# Build source
component.xml: $(IP_DIF)
	cp -rT --preserve=mode,timestamps $(IP_DIR)/$(IP_SRC) .
	patch -d .. -Ntp0 <$(IP_DIF)

# diff: "Exit status is 0 if inputs are the same, 1 if different, 2 if trouble."
# use "diff ...; [ $$? -eq 1 ]" if needed for exit status of 1
# Make patch file
.PHONY: patchfile
patchfile:
	@echo IP_DIR: $(IP_DIR)
	cd .. && LC_ALL=C TZ=UTC0 diff -Naur -x Makefile -x patch $(IP_DIR)/$(IP_SRC) $(IP_DST) | \
	sed 's|$(IP_DIR)/||' >$(IP_DST)/$(IP_DIF)

.PHONY: clean
clean:
	@if [ ! -s "$(IP_DIF)" ]; then tput setaf 1; echo "Missing patch file! run make patchfile."; tput sgr0; false; fi
	$(RM) -r $(SOURCES)

.PHONY: vars
vars:
	@echo IP_DIF: $(IP_DIF)
	@echo IP_SRC: $(IP_SRC)
	@echo IP_DST: $(IP_DST)
	@echo IP_DIR: $(IP_DIR)
	@echo SOURCES: $(SOURCES)
