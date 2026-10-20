
# Makefile for bare-metal PicoRV32 C programs
#
# This file expects a C program "firmware/main.c" provided by the user
# plus assembly language startup programs "firmware/start.s" and "firmware/crt.c"

# Give the user some easy overrides for local configuration quirks.
# If you change one of these and it breaks, then you get to keep both pieces.
SHELL = bash
PYTHON = python3

# Start wih no optimisation - better for understanding the code
OPTIMISATION = 0

SOFTWARE_OBJS = firmware/main.o firmware/crt.o firmware/start.o
BOOTROM_OBJS  = bootrom/bootrom.o firmware/crt.o firmware/start.o
GCC_WARNS  = -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -pedantic # -Wconversion
TOOLCHAIN_PREFIX = riscv64-unknown-elf-
HEX2V = $(PYTHON) ../tools/hex2v.py
HW_VERILOG = ../hardware/verilog
UART_TTY ?= /dev/ttyUSB0

# Define optimisation level here
# Start wih no optimisation - better for understanding the code
OPT = -O0


# this controls the instruction set supported by the PicoRV32
# the possible options are:
#
#   rv32i       Integer
#   rv32im      Integer + Hardware multiply and divide
#   rv32ic      Integer + Compressed instruction set
#   rv32imc     Integer + Hardware multiply and divide + Compressed instruction set
#
# (note that the parameters of the PicoRV32 core need to be
#  changed in order to support anything other than rv32i)
#
RVARCH = rv32i


#
# makefile rules
#

all: $(SOFTWARE_OBJS) $(BOOTROM_OBJS) code.elf code.bin code.lst code.ihex code.hex code.vmem bootrom.hex bootrom.ihex bootrom.lst bootrom.elf sync-hw


code.elf: $(SOFTWARE_OBJS) linker.ld
	$(TOOLCHAIN_PREFIX)gcc $(OPT) -mabi=ilp32 -march=$(RVARCH) -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,linker.ld,-Map,code.map,--strip-debug \
		$(SOFTWARE_OBJS) -lgcc
	chmod -x $@

# raw binary of the firmware, ready to download over UART
code.bin: code.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

# the boot ROM downloader
bootrom.elf: $(BOOTROM_OBJS) bootrom/bootrom.ld
	$(TOOLCHAIN_PREFIX)gcc $(OPT) -mabi=ilp32 -march=$(RVARCH) -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,bootrom/bootrom.ld,-Map,bootrom.map,--strip-debug \
		$(BOOTROM_OBJS) -lgcc
	chmod -x $@

# copy compiled hex files into the Quartus/hardware project so Quartus
# always picks up the latest firmware and bootloader when re-synthesising.
sync-hw: bootrom.hex code.hex
	cp bootrom.hex $(HW_VERILOG)/bootrom.hex
	cp code.hex    $(HW_VERILOG)/code.hex
	@echo "[sync-hw] hardware/verilog hex files updated"

# download the firmware to the boot ROM downloader over UART
download: code.bin bootrom.hex
	$(PYTHON) ../tools/uart_download.py $(UART_TTY) code.bin

%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=$(RVARCH) $(OPT) --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<

%.o: %.s
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=$(RVARCH) $(OPT) --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<


%.s: %.c
	$(TOOLCHAIN_PREFIX)gcc -S -mabi=ilp32 -march=$(RVARCH) $(OPT) --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<

%.ihex: %.elf
	$(TOOLCHAIN_PREFIX)objcopy -O ihex $< $@

%.lst: %.elf
	$(TOOLCHAIN_PREFIX)objdump -d $< > $@


# convert the Intel format hex file to a 4 byte per line format for $readmemh
%.hex: %.ihex
	$(HEX2V) $< 4 > $@

# convert the Intel format hex file to a verilog style memory assignment
# note that the .hex file is always updated when a new .vmem file is created
%.vmem: %.ihex %.hex
	$(HEX2V) $< 4 memory > $@


clean:
	rm -vrf $(SOFTWARE_OBJS) $(BOOTROM_OBJS) \
		code.elf code.bin code.hex code.ihex code.map code.lst \
		bootrom.elf bootrom.hex bootrom.ihex bootrom.map bootrom.lst bootrom.vmem
