# version: C1_v1
# last_modified_cycle: C1
"""
Export MAP256.S5 + PAL256.S5 to a full-color PNG for Godot.
MAP256.S5 is 800x592, each byte = palette index.
PAL256.S5 contains the color palette at offset 768.
"""

import struct
import zlib
import os

MAP_PATH = "../game/games/SAN5PK/MAP256.S5"
PAL_PATH = "../game/games/SAN5PK/PAL256.S5"
OUT_PATH = "data/map_full.png"

W, H = 800, 592

def load_palette(path):
    with open(path, "rb") as f:
        data = f.read()
    pal_raw = data[768:768 + 768]
    palette = []
    for i in range(256):
        r = pal_raw[i * 3]
        g = pal_raw[i * 3 + 1]
        b = pal_raw[i * 3 + 2]
        palette.append((r, g, b))
    return palette

def create_png(filename, pixels, w, h, palette):
    """Create a truecolor PNG from pixel indices and palette."""
    rgb = bytearray()
    for idx in pixels:
        idx = idx & 0xFF
        r, g, b = palette[idx]
        rgb.extend([r, g, b])

    def png_chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack(">I", len(data)) + c + crc

    raw = b""
    stride = w * 3
    for y in range(h):
        raw += b"\x00"  # filter byte
        raw += bytes(rgb[y * stride:(y + 1) * stride])

    with open(filename, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(png_chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(png_chunk(b"IDAT", zlib.compress(raw)))
        f.write(png_chunk(b"IEND", b""))

def export_map():
    palette = load_palette(PAL_PATH)

    with open(MAP_PATH, "rb") as f:
        map_data = bytearray(f.read())

    # MAP256.S5 should be exactly 800*592 = 473600 bytes
    expected = W * H
    if len(map_data) != expected:
        print(f"[MAP] Warning: expected {expected} bytes, got {len(map_data)}")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    create_png(OUT_PATH, map_data, W, H, palette)
    print(f"[MAP] Exported {OUT_PATH} ({W}x{H})")

if __name__ == "__main__":
    export_map()
