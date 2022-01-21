# Input: IP library, .tcl scripts
# Output: .hdf

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

PROJ = proj
SYSTEM = system
WRAPPER = $(SYSTEM)_wrapper
XSA = final
IMPL = $(PROJ).runs/impl_1/$(WRAPPER)
DESIGNS := $(patsubst %.tcl,%,$(wildcard *.tcl))
LN := ln -f

# semicolon needed for statement separation
# $$ needed to escape $ in make
# \$ needed to escape $ in shell
define compile
  open_project $(PROJ).xpr;
  launch_runs synth_1 -jobs 6;
  wait_on_run synth_1;
  launch_runs impl_1 -to_step write_bitstream -jobs 6;
  wait_on_run impl_1;
  write_hw_platform -fixed -include_bit final.xsa;
  set bfid [open "board" w];
  puts \$$bfid [get_property board_part [current_project]];
  close \$$bfid;
endef

.PHONY: all
all:
	@echo "Specify a design target:"
	@for i in $(DESIGNS); do echo "  $$i"; done

$(DESIGNS:%=%/):
	mkdir -p $@

.PRECIOUS: %/$(PROJ).xpr
%/$(PROJ).xpr : %.tcl | %/
	cd $* &&\
	$(RM) -r $(PROJ).* .Xil &&\
	$(RM) *.jou *.log &&\
	vivado -mode batch -source ../$< -notrace

.PRECIOUS: %/$(IMPL).hwdef
%/$(IMPL).hwdef : %/$(PROJ).xpr
	cd $* && vivado -mode tcl <<< "$(strip $(compile))"
#	mkdir -p $(@D) && echo "non-zero" > $@
#	mkdir -p $(@D) && touch $@

# if project is a target, then only the project is created
.PHONY: $(DESIGNS)
ifneq ($(filter project,$(MAKECMDGOALS)),)
$(DESIGNS): %: %/$(PROJ).xpr
else
$(DESIGNS): %: %/$(IMPL).hwdef
	cp $@/$(XSA).xsa $(XSA).xsa
	@if [ -s "$(XSA).xsa" ]; then \
		cp $@/board board; \
		tput setaf 2; echo "Build complete!"; tput sgr0; \
	else tput setaf 1; echo "Build failed!"; tput sgr0; false; fi;
endif

.PHONY: project
project:
	@tput setaf 3; echo "Project only created. Skip compilation."; tput sgr0;

.PHONY: clean
clean:
	for i in $(DESIGNS); do $(RM) -r $$i; done
	$(RM) $(XSA).xsa board
