#!/usr/bin/env python3
"""Builds the colour-coded body-part guide for Aseprite.

Reads the finished body (assets/character/base/base_fair.png), colours every
pixel by the body part it belongs to, and writes:

  art/templates/anchor_guide.png          64x64, import as a locked guide layer
  art/templates/anchor_guide_preview.png  the same at 8x with a 1 px grid

Run from the repo root:  python3 tool/make_anchor_guide.py
Standard library only (no Pillow needed).
"""
import struct
import sys
import zlib
from pathlib import Path

SRC = Path('assets/character/base/base_fair.png')
OUT = Path('art/templates')

# Each part: name, colour (RGBA), and a test on (x, y). First match wins.
# Coordinates measured off the finished body; keep in sync with the guide doc.
# The shorts' colours, so a hand beside the shorts isn't coloured as hips.
SHORTS = {(0x6d, 0x78, 0x7a), (0x35, 0x3d, 0x46), (0x56, 0x5a, 0x63), (0x4d, 0x53, 0x58)}

# Each part: name, colour (RGBA), and a test on (x, y, rgb). First match wins.
# Coordinates measured off the finished body; keep in sync with the guide doc.
# No neck: the head sits straight on the shoulders, so the skin between the
# vest straps (y 28-30) is part of the chest.
PARTS = [
    ('head', (230, 57, 70, 170), lambda x, y, c: 3 <= y <= 27),
    ('hips', (131, 56, 236, 160), lambda x, y, c: 42 <= y <= 49 and c in SHORTS),
    ('left arm', (82, 183, 136, 170), lambda x, y, c: 29 <= y <= 41 and x <= 25),
    ('right arm', (45, 106, 79, 170), lambda x, y, c: 29 <= y <= 41 and x >= 38),
    ('left hand', (255, 209, 102, 190), lambda x, y, c: 42 <= y <= 48 and x <= 25),
    ('right hand', (230, 175, 46, 190), lambda x, y, c: 42 <= y <= 48 and x >= 38),
    ('chest', (69, 123, 157, 170), lambda x, y, c: 28 <= y <= 41),
    ('hips', (131, 56, 236, 160), lambda x, y, c: 42 <= y <= 49),
    ('legs', (42, 157, 143, 170), lambda x, y, c: 50 <= y <= 56),
    ('feet', (141, 85, 36, 190), lambda x, y, c: 57 <= y <= 62),
]


def read_rgba(path):
    data = path.read_bytes()
    i, idat = 8, b''
    while i < len(data):
        n, = struct.unpack('>I', data[i:i + 4])
        kind, body = data[i + 4:i + 8], data[i + 8:i + 8 + n]
        i += 12 + n
        if kind == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
            if depth != 8 or ctype != 6:
                sys.exit(f'{path}: expected 8-bit RGBA')
        elif kind == b'IDAT':
            idat += body
    raw, bpp = zlib.decompress(idat), 4
    stride, rows, prev, p = w * bpp, [], bytearray(w * bpp), 0
    for _ in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append([tuple(line[x * 4:x * 4 + 4]) for x in range(w)])
        prev = line
    return w, h, rows


def write_png(path, w, h, pixel):
    raw = b''.join(
        b'\x00' + bytes(v for x in range(w) for v in pixel(x, y))
        for y in range(h))

    def chunk(kind, body):
        crc = zlib.crc32(kind + body) & 0xffffffff
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', crc)

    path.write_bytes(b'\x89PNG\r\n\x1a\n'
                     + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9))
                     + chunk(b'IEND', b''))


def main():
    w, h, rows = read_rgba(SRC)
    guide = [[(0, 0, 0, 0)] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if rows[y][x][3] == 0:
                continue
            for _, colour, test in PARTS:
                if test(x, y, rows[y][x][:3]):
                    guide[y][x] = colour
                    break
    # Centre line: the figure is 28 px wide (x 18-45), so the middle falls
    # between x 31 and 32. Mark both columns faintly where nothing is drawn.
    for y in range(h):
        for x in (31, 32):
            if guide[y][x][3] == 0:
                guide[y][x] = (255, 255, 255, 40)

    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / 'anchor_guide.png', w, h, lambda x, y: guide[y][x])

    s, bg, grid = 8, (247, 247, 244, 255), (214, 214, 208, 255)

    def preview(px, py):
        x, y = px // s, py // s
        r, g, b, a = guide[y][x]
        if px % s == 0 or py % s == 0:
            base = grid if (x % 8 or px % s) and (y % 8 or py % s) else (150, 150, 145, 255)
        else:
            base = bg
        t = a / 255
        return tuple(round(c * t + bc * (1 - t)) for c, bc in zip((r, g, b), base[:3])) + (255,)

    write_png(OUT / 'anchor_guide_preview.png', w * s, h * s, preview)
    print('wrote', OUT / 'anchor_guide.png', 'and', OUT / 'anchor_guide_preview.png')


if __name__ == '__main__':
    main()
