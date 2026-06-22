#!/usr/bin/env python3
"""Strip non-vanilla data packs from shop world level.dat."""
import gzip
import shutil

LEVEL_DAT = "/home/matei/minecraft-smp/servers/shop/data/shop/level.dat"

with gzip.open(LEVEL_DAT, "rb") as f:
    data = f.read()

# DataPacks.Enabled list in NBT binary format:
# Original: TAG_List("Enabled") with 5 strings: vanilla, mod:forge, mod:worldedit, mod:terraforged, file/NoCaves...
# Target: TAG_List("Enabled") with 1 string: vanilla

OLD = (
    b'\t\x00\x07Enabled\x08\x00\x00\x00\x05'
    b'\x00\x07vanilla'
    b'\x00\x09mod:forge'
    b'\x00\rmod:worldedit'
    b'\x00\x0fmod:terraforged'
    b'\x00\x1efile/NoCaves_1-16_v1.0 (1).zip'
)

NEW = (
    b'\t\x00\x07Enabled\x08\x00\x00\x00\x01'
    b'\x00\x07vanilla'
)

if OLD not in data:
    print("ERROR: Pattern not found in level.dat!")
    print("Raw bytes:", repr(data))
    exit(1)

patched = data.replace(OLD, NEW)
print(f"Patched: {len(data)} -> {len(patched)} bytes")

with gzip.open(LEVEL_DAT, "wb") as f:
    f.write(patched)

print("Done. Verifying...")
with gzip.open(LEVEL_DAT, "rb") as f:
    verify = f.read()

if b"mod:forge" in verify or b"mod:terraforged" in verify:
    print("ERROR: Bad packs still present!")
else:
    print("OK: Only vanilla data pack remains")
    if b"vanilla" in verify:
        print("  vanilla pack confirmed")
