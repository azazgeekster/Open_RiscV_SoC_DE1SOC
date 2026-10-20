#!/usr/bin/env python3
import sys

# Simple Intel HEX to Verilog converter
# Usage: hex2v.py <infile> <bytes_per_word> [memory]


def parse_ihex(filename):
    mem = {}
    hi = 0
    with open(filename) as f:
        for line in f:
            line = line.strip()
            if not line or line[0] != ':':
                continue
            count = int(line[1:3], 16)
            addr = int(line[3:7], 16)
            rectype = int(line[7:9], 16)
            data = [int(line[9+i*2:11+i*2], 16) for i in range(count)]
            if rectype == 0x00:
                base = (hi << 16) + addr
                for i, b in enumerate(data):
                    mem[base + i] = b
            elif rectype == 0x01:
                break
            elif rectype == 0x04 and len(data) >= 2:
                hi = (data[0] << 8) | data[1]
    return mem


def main():
    if len(sys.argv) < 3:
        print("usage: hex2v.py <infile> <bytes_per_word> [memory]", file=sys.stderr)
        return 1
    infile = sys.argv[1]
    width = int(sys.argv[2])
    memory = len(sys.argv) > 3
    mem = parse_ihex(infile)
    if not mem:
        return 0
    min_addr = min(mem.keys()) & ~(width - 1)
    max_addr = max(mem.keys())
    addr = min_addr
    index = 0
    while addr <= max_addr:
        word = 0
        for i in range(width):
            # little-endian: byte at the lowest address is the LSB of the word
            word |= mem.get(addr + i, 0) << (8 * i)
        if memory:
            print(f"memory[{index}] = {width*8}'h{word:0{width*2}x};")
        else:
            print(f"{word:0{width*2}x}")
        addr += width
        index += 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
