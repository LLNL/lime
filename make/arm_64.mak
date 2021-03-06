#DEFS += -DVERSION=$(VERSION)
DEFS += -DTIMEOFDAY

ifneq ($(findstring USE_MARGS,$(DEFS)),)
  DEFS += -DMARGS='"$(RUN_ARGS)"'
endif

SRC += $(SHARED)/linux
# SRC += $(patsubst %/,$(SHARED)/linux/%,$(shell ls -d */))

ifneq ($(findstring M5,$(DEFS)),)
  SRC += $(SHARED)/m5
  MODULES += m5op_arm_A64
endif

ifneq ($(findstring CLOCKS,$(DEFS)),)
  MODULES += clocks
endif

ifneq ($(filter %STATS %TRACE,$(DEFS)),)
  MODULES += monitor
endif

ifneq ($(filter $(NEED_DEVTREE),$(DEFS)),)
  MODULES += devtree
endif

ifneq ($(filter $(NEED_STREAM),$(DEFS)),)
  # DEFS += -DUSE_SP -DUSE_OCM
  SRC += $(SHARED)/linux/xil_com
  SRC += $(SHARED)/linux/xllfifo
  SRC += $(DRIVERS)
  MODULES += xil_cache xllfifo accmem aport stream
endif

OBJECTS = $(addsuffix .o,$(MODULES))
VPATH = $(subst ' ',:,$(SRC))

ARCH ?= aarch64
ifneq ($(ARCH),$(shell uname -m))
  CROSS_COMPILE ?= aarch64-linux-gnu-
  # CROSS_COMPILE ?= arm-linux-gnueabihf- # 32-bit arm
endif
ifneq ($(CROSS_COMPILE),)
  EXE ?= .elf
  LD = $(CROSS_COMPILE)ld
  CC = $(CROSS_COMPILE)gcc
  CXX = $(CROSS_COMPILE)g++
endif

OPT ?= -O3
ifdef OMP
  OPT += -fopenmp
endif
ifeq ($(ARCH),aarch64)
  MACH = -march=armv8-a
endif
CPPFLAGS += -MMD $(DEFS)
CPPFLAGS += $(patsubst %,-I%,$(SRC))
CFLAGS += $(MACH) $(OPT) -Wall
CXXFLAGS += $(CFLAGS)
LDFLAGS += -static
ifneq ($(findstring PAPI,$(DEFS)),)
LDFLAGS += -L/usr/local/lib
LDLIBS += -lpapi -lpthread
endif

.PHONY: all
all: $(TARGET)$(EXE)

.PHONY: run
run: $(TARGET)$(EXE)
ifdef OMP
	OMP_NUM_THREADS=$(OMP) ./$(TARGET)$(EXE) $(RUN_ARGS)
else
	./$(TARGET)$(EXE) $(RUN_ARGS)
endif

.PHONY: clean
clean:
	$(RM) $(wildcard *.o) $(wildcard *.d) $(TARGET)$(EXE) makeflags

.PHONY: vars
vars:
	@echo TARGET: $(TARGET)$(EXE)
	@echo VERSION: $(VERSION)
	@echo DEFS: $(DEFS)
	@echo SRC: $(SRC)
	@echo OBJECTS: $(OBJECTS)
	@echo MAKEFILE_LIST: $(MAKEFILE_LIST)

$(TARGET)$(EXE): $(OBJECTS)
	$(LINK.cpp) $^ $(LOADLIBES) $(LDLIBS) -o $@

$(OBJECTS): $(MAKEFILE_LIST) # rebuild if MAKEFILEs change

$(OBJECTS): makeflags # rebuild if MAKEFLAGS change
# Select only command line variables
cvars = _$(strip $(foreach flag,$(MAKEFLAGS),$(if $(findstring =,$(flag)),$(flag),)))_
makeflags: FORCE
	@[ "$(if $(wildcard $@),$(shell cat $@),)" = "$(cvars)" ] || echo $(cvars)> $@
FORCE: ;

# Establish module specific dependencies
-include $(OBJECTS:.o=.d)
