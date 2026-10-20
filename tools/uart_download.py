#!/usr/bin/env python3
"""Download a raw binary to the RISC-V SoC over UART.

The bootloader announces itself by sending "READY\\n" over the UART,
then expects a 4 byte big-endian length prefix followed by the payload
bytes. It stores the payload at the RAM base address and jumps to it.

Usage: uart_download.py <tty> <binfile>
"""

import os
import select
import struct
import sys
import termios
import time

BANNER = b"READY\n"


def main():
    if len(sys.argv) < 3:
        print("usage: uart_download.py <tty> <binfile>", file=sys.stderr)
        return 1

    tty = sys.argv[1]
    with open(sys.argv[2], "rb") as f:
        payload = f.read()

    # open the port ONCE — avoid stty which re-opens and toggles DTR
    fd = os.open(tty, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)

    try:
        # configure 115200 8N1 raw — set baud rate in cflag AND in
        # the ispeed/ospeed fields (Linux uses cflag & CBAUD, but some
        # drivers also look at the speed fields).
        iflag, oflag, cflag, lflag, ispeed, ospeed, cc = termios.tcgetattr(fd)
        cflag = (termios.CREAD | termios.CLOCAL | termios.CS8
                 | termios.B115200)
        lflag = 0
        iflag = 0
        oflag = 0
        termios.tcsetattr(fd, termios.TCSANOW,
                          [iflag, oflag, cflag, lflag, 115200, 115200, cc])
        termios.tcflush(fd, termios.TCIOFLUSH)

        print(f"connected to {tty} at 115200 8N1")
        print(f"firmware: {len(payload)} bytes")
        print(">>> Press KEY[2] on the board now to reset! <<<")

        # wait for the bootloader's READY banner (30 s timeout)
        got = b""
        deadline = time.time() + 30.0
        while BANNER not in got and time.time() < deadline:
            r, _, _ = select.select([fd], [], [], 0.2)
            if r:
                try:
                    chunk = os.read(fd, 256)
                    if chunk:
                        got += chunk
                except BlockingIOError:
                    pass

        if BANNER not in got:
            print("no READY banner — did you press KEY[2]?", file=sys.stderr)
            return 1

        print("got READY — sending firmware...")
        # small delay so bootloader is ready to receive
        time.sleep(0.05)

        # send bytes with small inter-byte pacing to prevent RX buffer overrun on FPGA UART
        def write_all(data, show_progress=False):
            total = len(data)
            for i, byte_val in enumerate(data):
                b = bytes([byte_val])
                while True:
                    try:
                        os.write(fd, b)
                        break
                    except BlockingIOError:
                        time.sleep(0.0005)
                time.sleep(0.0003)
                if show_progress and ((i + 1) % 128 == 0 or (i + 1) == total):
                    pct = ((i + 1) * 100) // total
                    print(f"\r  downloading: {i+1}/{total} bytes ({pct}%)", end="", flush=True)
            if show_progress:
                print()

        length_bytes = struct.pack(">I", len(payload))
        print(f"sending length: {length_bytes.hex()} ({len(payload)} bytes)")
        write_all(length_bytes)

        # wait for bootloader to finish reading length before sending payload
        time.sleep(0.05)

        print(f"sending payload ({len(payload)} bytes)...")
        write_all(payload, show_progress=True)

        # ensure all TX bytes are flushed to the wire before waiting for OK
        try:
            termios.tcdrain(fd)
        except termios.error:
            pass

        # wait for OK acknowledgement — bootloader sends this just
        # before jumping to the firmware.
        time.sleep(0.1)
        got = b""
        deadline = time.time() + 6.0
        while b"OK" not in got and time.time() < deadline:
            r, _, _ = select.select([fd], [], [], 0.2)
            if r:
                try:
                    chunk = os.read(fd, 256)
                    if chunk:
                        got += chunk
                except BlockingIOError:
                    pass

        if b"OK" in got:
            print(f"got OK — firmware running!")
            # Stream any initial UART banner printed by the firmware
            time.sleep(0.2)
            banner_out = b""
            while True:
                r, _, _ = select.select([fd], [], [], 0.3)
                if r:
                    try:
                        chunk = os.read(fd, 256)
                        if chunk:
                            banner_out += chunk
                        else:
                            break
                    except BlockingIOError:
                        break
                else:
                    break
            if banner_out:
                try:
                    print(banner_out.decode("utf-8", errors="replace"))
                except Exception:
                    pass
        else:
            print(f"ERROR: no OK received (got: {got!r})", file=sys.stderr)
            print("bootloader may not have received the payload correctly.",
                  file=sys.stderr)
            return 1

    finally:
        os.close(fd)

    return 0


if __name__ == "__main__":
    sys.exit(main())
