AS = ca65 -t c64
LD = ld65

RM         := rm -rf
COPY       := cp -a
PATH_SEP   := /

PACKAGE    := rom

BASE_DIR   := $(dir $(lastword $(MAKEFILE_LIST)))

SRC_DIR    := $(BASE_DIR)/src
LDSCRIPT   := $(BASE_DIR)/linker.cfg

LFLAGS     := -C $(LDSCRIPT)

ifeq ($(BASE_DIR),./)
OBJ_DIR    := .obj
else
OBJ_DIR    := .
endif

ASOURCES   := $(sort $(wildcard $(SRC_DIR)/*.s))
AOBJS      := head.o $(filter-out head.o,$(notdir $(ASOURCES:.s=.o)))
OBJECTS    := $(addprefix $(OBJ_DIR)/, $(AOBJS))
VPATH      := $(SRC_DIR)

QUIET      := @

ALL        := all
TARGET     := $(PACKAGE).bin
CLEAN      := clean

$(ALL): $(TARGET)

$(OBJECTS): | $(OBJ_DIR)

$(OBJ_DIR):
	$(QUIET) mkdir $(OBJ_DIR)

$(TARGET): $(OBJECTS) $(LDSCRIPT)
	$(QUIET) echo "  LD       $@"
	$(QUIET) $(LD) -o $@ $(LFLAGS) $(OBJECTS)

$(OBJ_DIR)/%.o: %.s
	$(QUIET) echo "  AS       $<	$(notdir $@)"
	$(QUIET) $(AS) -o $@ $<

.PHONY: clean

clean:
	$(QUIET) echo "  RM      $(subst /,$(PATH_SEP),$(wildcard $(OBJ_DIR)/*.o))"
	-$(QUIET) $(RM) $(subst /,$(PATH_SEP),$(wildcard $(OBJ_DIR)/*.o))
	$(QUIET) echo "  RM      $(TARGET)"
	-$(QUIET) $(RM) $(TARGET)
