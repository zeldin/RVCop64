HW_DIR?=../../hw
BUILD_DIR?=$(HW_DIR)/build
SOC_DIRECTORY?=$(HW_DIR)/deps/litex/litex/soc
CSR_CSV?=$(BUILD_DIR)/csr.csv

UART?=/dev/ttyUSB1

export PYTHONPATH:=$(HW_DIR)/deps/litex:$(HW_DIR)/deps/migen

include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak

OBJECTS   = crt0.o main.o ssd1306.o


all: demo.bin


%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
ifneq ($(OS),Windows_NT)
	chmod -x $@
endif

vpath %.a $(PACKAGES:%=../%)

demo.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) -T linker.ld -N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-Wl,--whole-archive \
		-Wl,--gc-sections \
		-Wl,-Map,$@.map \
		$(LIBS:lib%=-l%)

ifneq ($(OS),Windows_NT)
	chmod -x $@
endif

# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)

VPATH = $(BIOS_DIRECTORY):$(BIOS_DIRECTORY)/cmds:$(CPU_DIRECTORY)


%.o: %.c
	$(compile)

%.o: %.S
	$(assemble)

clean:
	$(RM) $(OBJECTS) demo.elf demo.bin .*~ *~

run: demo.bin
	python -m litex.tools.litex_term --speed 115200 --serial-boot --kernel $< $(if $(findstring crossover,$(UART)),--csr-csv $(CSR_CSV),) $(UART)

.PHONY: all clean
