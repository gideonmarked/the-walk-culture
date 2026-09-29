#!/usr/bin/env python3
"""Slices an Aseprite sprite sheet into one PNG per frame tag.

The art is authored as a single Aseprite file per slot (one layer drawn, then
palette-swapped per tag — see docs/PIXEL_ART_GUIDE.md §3) and exported as a
sheet + JSON. The app, though, loads one file per catalogue id:
`assets/<slot folder>/<id>.png`. This bridges the two.

Each output is the FULL `sourceSize` canvas with the trimmed frame pasted back
at its `spriteSourceSize` offset, so every sprite keeps the same 64x64 skeleton
and the paper-doll layers line up.

    python3 tool/slice_aseprite_sheet.py \
        assets/character/base/tones.png assets/character/base/tones.json \
        --prefix base_

writes base_medium.png / base_fair.png / base_light.png next to the sheet
(tags "Medium", "Fair", "Light" -> slugged, prefixed). So **name each tag after
the catalogue id minus the prefix** — tag `Run` + `--prefix shoes_` lands on
`shoes_run`, the id the shop item already uses.

Whole-sheet and single-tag exports both work; see [tag_frames] for why that
needs care.

Re-run it after every Aseprite re-export. Pure stdlib — no pip install.
"""

import argparse
import json
import os
import struct
import zlib


def read_png(path):
    data = open(path, 'rb').read()
    pos, idat, w, h = 8, b'', None, None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, depth, colour = struct.unpack('>IIBB', chunk[:10])
            if (depth, colour) != (8, 6):
                raise SystemExit('%s: need 8-bit RGBA, got depth %d type %d'
                                 % (path, depth, colour))
        elif typ == b'IDAT':
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    bpp, stride = 4, w * 4
    out, prev, i = bytearray(), bytearray(stride), 0
    for _ in range(h):
        f = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
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
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 255
        out += line
        prev = line
    px = [[tuple(out[y * stride + x * 4: y * stride + x * 4 + 4])
           for x in range(w)] for y in range(h)]
    return w, h, px


def write_png(path, w, h, px):
    raw = b''.join(b'\x00' + bytes(v for p in row for v in p) for row in px)

    def chunk(tag, payload):
        body = tag + payload
        return (struct.pack('>I', len(payload)) + body
                + struct.pack('>I', zlib.crc32(body)))

    open(path, 'wb').write(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b''))


def frames_in_order(meta):
    """Aseprite writes frames as a dict (hash) or a list (array).

    Yields `(key, frame)` — the key is Aseprite's per-frame name, which carries
    the tag when the sheet was exported with a `#{tag}` filename pattern. See
    [tag_frames].
    """
    frames = meta['frames']
    if isinstance(frames, list):
        return [(f.get('filename', ''), f) for f in frames]
    return [(k, frames[k]) for k in sorted(frames, key=lambda k: (len(k), k))]


def tag_frames(tags, frames):
    """Maps each tag index -> the sheet frame indices it covers.

    A tag normally indexes the sheet directly via `from`/`to`. But exporting one
    tag (Aseprite's tag filter, which writes `Assets #Blue Shoes.aseprite` as the
    frame key) emits a sheet holding only that tag's frames while leaving
    `from`/`to` at their position in the *source* file — so on a 1-frame shoe
    sheet the tag still claims frame 5. Where the key names the tag, that
    binding is authoritative and the indices are ignored; only tags that resolve
    neither way are treated as stale.
    """
    keyed = {}
    for i, (key, _) in enumerate(frames):
        if '#' not in key:
            continue
        name = key.split('#', 1)[1].rsplit('.', 1)[0].strip()
        keyed.setdefault(name, []).append(i)

    out = {}
    for i, tag in enumerate(tags):
        if tag['name'] in keyed:
            out[i] = keyed[tag['name']]
        elif max(tag['from'], tag['to']) < len(frames):
            out[i] = list(range(tag['from'], tag['to'] + 1))
        else:
            out[i] = []
    return out


def slug(name):
    """Tag name -> filename stem. Mirrors `_slug` in lib/data/shop_catalog.dart
    so a tag can be named after the catalogue item it draws."""
    return name.strip().lower().replace(' ', '_')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sheet')
    ap.add_argument('json_path')
    ap.add_argument('--prefix', default='',
                    help='prepended to the slugged tag name, e.g. "base_"')
    ap.add_argument('--out-dir', default=None,
                    help='defaults to the sheet\'s own directory')
    args = ap.parse_args()

    meta = json.load(open(args.json_path))
    sheet_w, sheet_h, sheet = read_png(args.sheet)
    frames = frames_in_order(meta)
    tags = meta['meta'].get('frameTags') or []
    if not tags:
        raise SystemExit('no frameTags in %s — tag each frame in Aseprite so '
                         'the slices get names' % args.json_path)
    out_dir = args.out_dir or os.path.dirname(args.sheet) or '.'

    covers = tag_frames(tags, frames)

    # A frame with no tag has no name, so it can't become a file — and an
    # untagged frame is almost always a variant someone forgot to label.
    tagged = {i for idxs in covers.values() for i in idxs}
    untagged = [i for i in range(len(frames)) if i not in tagged]

    # A tag that resolves neither by key nor by index is a leftover from whatever
    # the .aseprite file held earlier (tags survive frame deletion). Skipping it
    # keeps the run alive, but the tags that DO resolve are just as likely to be
    # stale — and a stale name silently writes a sprite under the wrong catalogue
    # id — so this is reported as a failure, not a warning.
    stale = {i for i, idxs in covers.items() if not idxs}

    for i, tag in enumerate(tags):
        idxs = covers[i]
        if not idxs:
            print('  skip %-10s points at frame %d, sheet has %d'
                  % (tag['name'], max(tag['from'], tag['to']), len(frames)))
            continue
        if len(idxs) > 1:
            print('  skip %-10s spans frames %d-%d (animation, not a variant)'
                  % (tag['name'], idxs[0], idxs[-1]))
            continue
        fr = frames[idxs[0]][1]
        f, src, size = fr['frame'], fr['spriteSourceSize'], fr['sourceSize']
        canvas = [[(0, 0, 0, 0)] * size['w'] for _ in range(size['h'])]
        for y in range(f['h']):
            for x in range(f['w']):
                canvas[src['y'] + y][src['x'] + x] = sheet[f['y'] + y][f['x'] + x]
        name = '%s%s.png' % (args.prefix, slug(tag['name']))
        path = os.path.join(out_dir, name)
        write_png(path, size['w'], size['h'], canvas)
        print('  %-22s %dx%d  (frame %d, trimmed %dx%d at %d,%d)'
              % (name, size['w'], size['h'], idxs[0],
                 f['w'], f['h'], src['x'], src['y']))

    if untagged:
        print('\n  WARNING: frame%s %s ha%s no tag, so nothing was written for '
              '%s.\n  Tag %s in Aseprite and re-export.'
              % ('s' if len(untagged) > 1 else '',
                 ', '.join(str(i) for i in untagged),
                 'action' if len(untagged) > 1 else 's',
                 'them' if len(untagged) > 1 else 'it',
                 'them' if len(untagged) > 1 else 'it'))
        return 1
    if stale:
        print('\n  WARNING: %d tag%s (%s) point past the end of a %d-frame '
              'sheet.\n  They are left over from an earlier version of the '
              '.aseprite file — Aseprite keeps\n  tags when you delete frames. '
              'Any name written above may be stale too, so\n  delete the dead '
              'tags in Aseprite, check the survivors, and re-export.'
              % (len(stale), 's' if len(stale) > 1 else '',
                 ', '.join(tags[i]['name'] for i in sorted(stale)),
                 len(frames)))
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
