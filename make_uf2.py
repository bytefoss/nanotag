"""Turn build/merged.hex into build/nanotag.uf2 for the nice!nano UF2 bootloader.

uf2conv.py fills gaps inside a 256-byte UF2 block with 0x00, but the Fast Pair partition has an
alignment gap that its SHA-256 check expects to read as erased flash (0xFF). So gaps are filled
with 0xFF first. Also refuses anything the bootloader (0.6.0) would reject: data outside
0x26000-0xAD000.
Run after `source env.sh`: python3 make_uf2.py
"""
import os
import subprocess
import sys

# Checked before importing intelhex, which also only exists inside the build shell.
if "ZEPHYR_BASE" not in os.environ:
    sys.exit("ZEPHYR_BASE is not set: enter the NCS build shell first (see the README's Install section)")

from intelhex import IntelHex

UF2_BLOCK_SIZE = 256
UF2_WRITABLE_START = 0x26000
UF2_WRITABLE_END = 0xAD000  # USER_FLASH_END in Adafruit nRF52 bootloader 0.6.0
NRF52840_FAMILY_ID = "0xADA52840"

merged_hex = IntelHex("build/merged.hex")
for segment_start, segment_end in merged_hex.segments():
    if segment_start < UF2_WRITABLE_START or segment_end > UF2_WRITABLE_END:
        sys.exit(f"Data at {segment_start:#x}-{segment_end:#x} is outside what the UF2 bootloader accepts")

data_addresses = set(merged_hex.addresses())
used_blocks = {address // UF2_BLOCK_SIZE for address in data_addresses}
for block_index in used_blocks:
    for address in range(block_index * UF2_BLOCK_SIZE, (block_index + 1) * UF2_BLOCK_SIZE):
        if address not in data_addresses:
            merged_hex[address] = 0xFF
merged_hex.write_hex_file("build/merged_filled.hex")

uf2conv_path = os.path.join(os.environ["ZEPHYR_BASE"], "scripts/build/uf2conv.py")
subprocess.run([sys.executable, uf2conv_path, "build/merged_filled.hex", "-c", "-f", NRF52840_FAMILY_ID,
                "-o", "build/nanotag.uf2"], check=True)
