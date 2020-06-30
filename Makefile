
PACKAGE = lime-2.2.0

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:

DESIGNS := $(patsubst system/%.tcl,%,$(wildcard system/*.tcl))

.PHONY: all help
all help:
	@echo "Design targets:"
	@for i in $(DESIGNS); do echo "  $$i"; done
	@echo -e "\nOS targets: can be specified with design targets"
	@echo "  linux"
	@echo "  standalone"
	@echo -e "\nOther targets:"
	@echo "  clean   - Remove build files"
	@echo "  dist    - Package the release for distribution (tar)"
	@echo "  ip      - Build IP libraries"
	@echo "  kernel  - Use with linux target to force kernel rebuild"
	@echo "  project - Use with design target to only create a project"
	@echo "  sdcard  - Format and copy Linux to an SD card"
	@echo "            Use the make variable 'DEV' to specify the SD device."
	@echo "            e.g., make sdcard DEV=/dev/mmcblk0"
	@echo "  test    - Run hardware tests"
	@echo "  trace   - Build the trace parser"
	@echo -e "\nPreconditions:"
	@echo "  1) Xilinx tools in path"
	@echo "     e.g., source /opt/Xilinx/Vivado/<version>/settings64.sh"
	@echo "  2) Path to Internet through firewall"
	@echo "     e.g., lynx www.google.com"

.PHONY: ip
ip:
	$(MAKE) -C ip

.PHONY: $(DESIGNS)
$(DESIGNS): ip
	$(MAKE) -C system $@ $(filter project,$(MAKECMDGOALS))

.PHONY: project kernel
project kernel:;@echo -n

.PHONY: standalone
standalone:
	$(MAKE) -C standalone

.PHONY: linux
linux:
	$(MAKE) -C linux $(filter kernel,$(MAKECMDGOALS))

.PHONY: trace
trace:
	$(MAKE) -C trace

.PHONY: test
test: standalone
	$(MAKE) -C test fpga run

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
