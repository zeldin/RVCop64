AS = ca65 -t c64
LD = ld65

RM         := rm -rf
COPY       := cp -a
PATH_SEP   := /

PACKAGE    := rom

ifeq ($(LITEX),1)
BASE_DIR   := ../../../../sw
else
BASE_DIR   := .
endif

SRC_DIR    := $(BASE_DIR)/src
LDSCRIPT   := $(BASE_DIR)/linker.cfg

LFLAGS     := -C $(LDSCRIPT)

OBJ_DIR    := .obj

ASOURCES   := $(wildcard $(SRC_DIR)/*.s)
AOBJS      := $(addprefix $(OBJ_DIR)/, $(notdir $(ASOURCES:.s=.o)))
OBJECTS    := $(AOBJS)
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
