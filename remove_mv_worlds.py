#!/usr/bin/env python3
"""Remove shop and hub worlds from SMP Multiverse worlds.yml."""
import re

WORLDS_YML = "/home/matei/minecraft-smp/data/plugins/Multiverse-Core/worlds.yml"

with open(WORLDS_YML, "r") as f:
    content = f.read()

# Split on top-level world keys (lines starting with 'minecraft:')
# Each world block ends just before the next 'minecraft:' key or EOF
blocks = re.split(r'^(?=minecraft:)', content, flags=re.MULTILINE)

REMOVE = {"minecraft:hub:", "minecraft:shop:"}

kept = []
removed = []
for block in blocks:
    key = block.split('\n')[0].strip()
    if key in REMOVE:
        removed.append(key)
    else:
        kept.append(block)

result = "".join(kept)

with open(WORLDS_YML, "w") as f:
    f.write(result)

print(f"Removed: {removed}")
print(f"Kept worlds: {[b.split(chr(10))[0].strip() for b in kept if b.strip()]}")
