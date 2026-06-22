#!/usr/bin/env python3
"""Strip non-vanilla data packs from level.dat using regex on the decompressed NBT bytes."""
import gzip
import re
import shutil
import os

LEVEL_DAT = "/home/matei/minecraft-smp/servers/shop/data/shop/level.dat"
BACKUP = LEVEL_DAT + ".bak"

shutil.copy2(LEVEL_DAT, BACKUP)
print(f"Backup: {BACKUP}")

with gzip.open(LEVEL_DAT, "rb") as f:
    data = f.read()

print(f"Original size: {len(data)} bytes")

# The DataPacks section in NBT stores enabled/disabled pack names as TAG_String entries
# We need to find and see what packs are referenced
# Look for known problematic pack name strings
BAD_PACKS = [
    b"mod:forge",
    b"mod:worldedit",
    b"mod:terraforged",
    b"file/NoCaves",
    b"terraforged",
]

for pack in BAD_PACKS:
    if pack in data:
        print(f"  Found: {pack.decode()}")
    else:
        print(f"  Not found: {pack.decode()}")
