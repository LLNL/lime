LABEL = V$(subst .,_,$(VERSION))

# Cancel version control implicit rules
%:: %,v
%:: RCS/%
%:: RCS/%,v
%:: s.%
%:: SCCS/s.%
# Delete default suffixes
.SUFFIXES:
# Define suffixes of interest
.SUFFIXES: .o .c .cc .cpp .h .hpp .d .mak .ld

ifdef D
  SEP := ,
  DEFS += $(patsubst %,-D%,$(subst $(SEP), ,$(D)))
endif

# See $(SHARED)/config.h
NEED_STREAM = %CLIENT %SERVER %OFFLOAD %SYSTEMC
NEED_ACC = %DIRECT $(NEED_STREAM)
NEED_DEVTREE = %CLOCKS %STATS %TRACE $(NEED_STREAM)

LIME := $(patsubst %/,%,$(dir $(MAKDIR)))
# $(info LIME root directory is $(LIME))
SHARED := $(LIME)/shared
SCRIPTS := $(MAKDIR)/sdk
SC_IP := $(LIME)/ip/sysc
DRIVERS := $(LIME)/linux/drivers
SA_SDK := $(LIME)/standalone/sdk
