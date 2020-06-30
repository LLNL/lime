# Input: system_wrapper.hdf, .tcl scripts, C source
# Output: parser executable

SYS = ../system
HDF = $(SYS)/system_wrapper.hdf
BDF = $(SYS)/board
LOCAL_HDF = hw_platform_0/system.hdf
XSCT := xsct$(if $(findstring Linux,$(shell uname -s)),,.bat)
# "which" doesn't find .bat files on CYGWIN so look for "xsct"
XSCT_PATH := $(shell which xsct 2>/dev/null)

ifneq ($(CROSS_COMPILE),)
  EXE ?= .elf
  LD = $(CROSS_COMPILE)ld
  CC = $(CROSS_COMPILE)gcc
  CXX = $(CROSS_COMPILE)g++
else ifneq ($(findstring win,$(shell uname -s)),)
  EXE = .exe
endif

TARGET = parser
MODULES = parser config
OBJECTS = $(addsuffix .o,$(MODULES))

OPT ?= -O3
ifeq ($(ARCH),aarch64)
  MACH = -march=armv8-a
endif
CPPFLAGS += -MMD $(DEFS)
CFLAGS += $(MACH) $(OPT) -Wall
# LDFLAGS += -static

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:
# Define suffixes of interest
.SUFFIXES: .o .c .h .d

.PHONY: all
all: config.h $(TARGET)$(EXE)

# This rule is needed because of an annoying side effect of the Xilinx
# xsct "hsi open_hw_design" command. It creates or overwrites several files
# in the same directory as the .hdf file. For easier clean up, the .hdf file
# is copied locally. Copy is used instead of link to update time stamp.
$(LOCAL_HDF): $(HDF) $(BDF)
	mkdir -p $(@D)
	-$(RM) -r $(@D)/*
	cp $(HDF) $@

config.h config.c: config.tcl $(LOCAL_HDF)
ifneq ($(XSCT_PATH),)
	$(XSCT) config.tcl $(LOCAL_HDF)
else
	@tput setaf 3; echo "xsct not in path. Using default config."; tput sgr0;
	cp def_config.h config.h
	cp def_config.c config.c
endif

$(TARGET)$(EXE): $(OBJECTS)

.PHONY: clean
clean:
	$(RM) -r .Xil $(dir $(LOCAL_HDF))
	$(RM) config.h config.c
	$(RM) $(wildcard *.o) $(wildcard *.d) $(TARGET)$(EXE)

# Establish module specific dependencies
-include $(OBJECTS:.o=.d)
