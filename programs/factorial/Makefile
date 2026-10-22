# Run from the repository root: make -C programs/factorial
PROGRAM_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR ?= $(abspath $(PROGRAM_DIR)/../../build/programs/factorial)
CROSS_COMPILE ?= riscv64-unknown-elf-
CC := $(CROSS_COMPILE)gcc
OBJDUMP := $(CROSS_COMPILE)objdump
ELF2HEX ?= elf2hex

# Zicsr enables CSR assembly syntax; multiplication is implemented in runtime.S.
CFLAGS := -march=rv32i_zicsr -mabi=ilp32 -O0 -g \
          -ffreestanding -fno-builtin -fno-pic -fno-pie \
          -fno-stack-protector -msmall-data-limit=0
LDFLAGS := -nostdlib -nostartfiles -Wl,--no-relax \
           -T$(PROGRAM_DIR)/link.ld

.PHONY: all clean
all: $(BUILD_DIR)/factorial.hex $(BUILD_DIR)/factorial.dump

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/factorial.o: $(PROGRAM_DIR)/factorial.c Makefile | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/runtime.o: $(PROGRAM_DIR)/runtime.S Makefile | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/factorial.elf: $(BUILD_DIR)/runtime.o $(BUILD_DIR)/factorial.o $(PROGRAM_DIR)/link.ld Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(BUILD_DIR)/runtime.o $(BUILD_DIR)/factorial.o -o $@

$(BUILD_DIR)/factorial.hex: $(BUILD_DIR)/factorial.elf
	$(ELF2HEX) 16 32768 $< > $@.tmp
	mv $@.tmp $@

$(BUILD_DIR)/factorial.dump: $(BUILD_DIR)/factorial.elf
	$(OBJDUMP) -d -S $< > $@

clean:
	rm -rf $(BUILD_DIR)
