
PACKAGE = lime-2.1.0

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

DESIGNS := $(patsubst system/%.tcl,%,$(wildcard system/*.tcl))

.PHONY: all
all:
	@echo "Specify a design target:"
	@for i in $(DESIGNS); do echo "  $$i"; done
	@echo "and optionally an OS target (standalone or linux)."
	@echo "Use target 'sdcard' to format and copy linux to an SD card."
	@echo "Use the make variable 'DEV' to specify the SD device"
	@echo "(e.g. make sdcard DEV=/dev/mmcblk0)."
	@echo "Use target 'trace' to build the trace parser."
	@echo "Use target 'test' to run hardware tests (standalone)."
	@echo "Preconditions:"
	@echo "1) Xilinx tools in path (e.g. source /opt/Xilinx/Vivado/<version>/settings64.sh)"
	@echo "2) Path to Internet through firewall (e.g. lynx www.google.com)"

.PHONY: ip
ip:
	$(MAKE) -C ip

.PHONY: $(DESIGNS)
$(DESIGNS): ip
	$(MAKE) -C system $@ $(filter project,$(MAKECMDGOALS))

.PHONY: project
project:;@echo -n

.PHONY: standalone
standalone:
	$(MAKE) -C standalone

.PHONY: linux
linux:
	$(MAKE) -C linux

.PHONY: trace
trace:
	$(MAKE) -C trace

.PHONY: test
test: standalone
	$(MAKE) -C test run

.PHONY: sdcard
sdcard: linux
	cd linux/boot && ./mksd.sh $(DEV)

.PHONY: clean
clean:
	$(MAKE) -C ip clean
	$(MAKE) -C system clean
	$(MAKE) -C standalone clean
	$(MAKE) -C linux clean
	$(MAKE) -C trace clean
	$(MAKE) -C test clean

.PHONY: dist
dist: clean
	tar --transform 's,^,$(PACKAGE)/,' -czf ../$(PACKAGE).tgz --exclude-vcs *
