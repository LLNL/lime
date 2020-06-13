TARGET = dre
VERSION = 1.0
SRC += ../src $(SHARED)
MODULES += dre
ifneq ($(filter $(NEED_STREAM),$(DEFS)),)
  DEFS += -DUSE_LSU
  MODULES += lsu_cmd
endif
RUN_ARGS = 
# CXXFLAGS += -std=c++11
# LDFLAGS += 
# LDLIBS += -lstdc++
