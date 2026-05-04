# version: C1_v1
# last_modified_cycle: C1
"""
Export PAL256.S5 palette to JSON format for Godot.
Palette data starts at offset 768, each color is 3 bytes RGB (0-255).
"""

import struct
import json
import os

PAL_PATH = "../game/games/SAN5PK/PAL256.S5"
OUT_PATH = "data/palette.json"

def export_palette():
    with open(PAL_PATH, "rb") as f:
        data = f.read()

    # Palette starts at offset 768, 256 colors × 3 bytes = 768 bytes
    pal_start = 768
    pal_raw = data[pal_start:pal_start + 768]

    colors = []
    for i in range(256):
        offset = i * 3
        r = pal_raw[offset]
        g = pal_raw[offset + 1]
        b = pal_raw[offset + 2]
        colors.append({"r": r, "g": g, "b": b})

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump({"colors": colors}, f, ensure_ascii=False)

    print(f"[PAL] Exported {len(colors)} colors to {OUT_PATH}")

if __name__ == "__main__":
    export_palette()
