# Graphic Assets — Pixel-Art Pipeline

How art is wired in so you can drop your own sprites in later. **Design spec:
64×64 pixel-art PNGs on a 96×96 stage (RGBA, transparent background).**
Character customisation is prioritised; home comes second.

---

> **What to draw:** [`ART_MANIFEST.md`](ART_MANIFEST.md) — every sprite the
> catalog expects, by filename, with a done/not-done column. Generated, so it
> can't drift from the catalog.

## 1. Folder layout (registered in `pubspec.yaml`)

```
assets/
  character/
    base/          skin tone / body        (ItemSlot.base)
    face/          eyes/mouth/expression    (ItemSlot.face)
    hair/          hair styles + colours    (ItemSlot.hair)
    tops/          shirts, hoodies, cloaks  (ItemSlot.top)
    bottoms/       pants, skirts, shorts    (ItemSlot.bottom)
    shoes/         footwear                 (ItemSlot.shoes)
    hats/          headwear                 (ItemSlot.hat)
    accessories/   glasses, bags, wings…    (ItemSlot.accessory)
  pets/            companions               (ItemSlot.pet)
  home/            room decor               (ItemSlot.home)
  ui/              misc UI art
```

Each folder currently holds a `_placeholder.png` so Flutter registers it. Until
you add real art, the app shows each item's **emoji fallback**.

---

## 2. How to replace a placeholder

Every item has an `id` in [`lib/data/shop_catalog.dart`](../lib/data/shop_catalog.dart).
Its sprite path is `assets/<slot folder>/<id>.png`.

Example — the "Ponytail" hair (`id: 'hair_ponytail'`, slot `hair`):
```
assets/character/hair/hair_ponytail.png
```
Drop a 64×64 PNG there, run `flutter pub get` once (only needed the first time a
folder gains files) and rebuild. No code changes — `ShopItem.asset` derives the
path from slot + id, and the UI already loads it with an emoji fallback.

> Tip: to list every expected filename, search the catalog for `id:`.

### From an Aseprite sprite sheet

Variants of one drawing (all the skin tones, all the colours of a hair style)
are authored as **one Aseprite file with a tagged frame per variant**, exported
as a sheet + JSON. Slice it into the per-id PNGs with:

```
python3 tool/slice_aseprite_sheet.py \
    assets/character/base/tones.png assets/character/base/tones.json \
    --prefix base_
```

Each frame tag becomes `<prefix><tag slugged>.png` — tag `Medium` →
`base_medium.png`, tag `Blue Shoes` → `…blue_shoes.png` (lowercased, spaces to
underscores, same rule as `_slug` in the catalog). The slicer restores each
trimmed frame onto its full `sourceSize` canvas, so the paper-doll anchors
survive Aseprite's trimming. **Re-run it after every export**, then rebuild.

The base sheet supplies all five tones (**Medium, Fair, Light, Brown, Dark**).
The `.png`/`.json` sources sit in the asset folder and ship with the app (~4 KB)
— move them to a non-bundled folder if that ever matters.

> **The tag name is the contract.** It becomes the filename, and the filename
> *is* the catalogue id. A tag named for the drawing rather than the item
> (`Blue Shoes`) writes a sprite no item equips, and it fails silently — the art
> just never shows.

**Tag each frame with the complete item id and skip `--prefix`.** A slot's ids
don't share one prefix — `shoes/` holds `shoes_run`, `gen_shoes_sneakers_azure`
and `pr_chrome_kicks` — so a single prefix can't cover a slot's sheet:

```
python3 tool/slice_aseprite_sheet.py \
    assets/character/shoes/shoes.png assets/character/shoes/shoes.json
```

`--prefix` is only useful when every frame in the sheet *does* share a stem, as
with the `base_` tones.

**Both export styles work**, which matters as a slot accumulates variants:

- **Whole sheet** — every tag in one export. Tags index the sheet directly.
- **One tag at a time** (Aseprite's tag filter, frame keys like
  `Assets #Run.aseprite`) — handy for adding a single new shoe. Aseprite emits
  just that tag's frames but leaves its `from`/`to` at the position in the
  *source* file, so a 1-frame sheet can carry a tag claiming frame 5. The slicer
  binds by the tag name in the frame key here and ignores the indices.

If a tag resolves neither way it's a leftover — Aseprite keeps tags when you
delete frames, so a file started from the tone sheet carries `Medium`/`Fair`/…
into a shoe export. The slicer names those, exits non-zero, and warns that the
names it *did* write may be stale too. Delete dead tags in Aseprite and
re-export.

---

## 3. Two canvases: the character sheet and the stage

Constants live in [`lib/models/shop_item.dart`](../lib/models/shop_item.dart);
everything is scaled up with `FilterQuality.none` so pixels stay crisp.

| | Size | What goes here |
|---|---|---|
| **Character sheet** (`kCanvas`) | 64×64 | The body and everything *worn* on it — base, face, hair, hat, top, bottom, shoes, glasses. |
| **Stage** (`kStage`) | 96×96 | The scene around him — pets, a bag on the floor, wings. Room to the sides and above. |

The character sheet is pasted into the stage at `kCharOriginX, kCharOriginY` =
**(16, 24)**, so the character box is `x16–80, y24–88` and the **ground line is
`kGroundY` = 88** (feet and any prop standing beside him rest there, leaving an
8px floor strip for shadows).

- **Which space an item uses:** `kStageSlots` (currently `pet`) → stage coords;
  everything else → character-sheet coords, auto-offset by the origin. A single
  item can override with `stageSpace: true` (e.g. wings that need the room).
- **Layer order (back → front)** is `kCharacterSlots`:
  `base → bottom → top → shoes → face → hair → hat → accessory → pet` — so stage
  props draw in front of the figure.
- **Placement is fixed, not user-movable.** The player can equip/unequip but
  never drag things around.

Two ways to author any sprite:

```dart
// 1. Full frame (64 or 96 square) — the art positions itself, x/y stay 0.
ShopItem(id: 'top_hoodie', ..., slot: ItemSlot.top),

// 2. Tight sprite + exact placement — the PNG is just the prop, at its own size.
//    y 70 = ground line 88 − 18px tall, so the dog stands on the floor.
ShopItem(id: 'pet_dog', ..., slot: ItemSlot.pet, x: 66, y: 70, w: 22, h: 18),
```

Prefer **tight sprites for pets and props**: the shop thumbnail renders the raw
PNG, so a tight file fills its thumbnail instead of showing a small dog adrift in
a 96px square.

---

## 4. Authoring guidelines

- **Size:** 64×64 for worn items, 96×96 (or tight + `w`/`h`) for stage props.
  **Format:** PNG, RGBA, transparent where empty.
- Keep the character centred and consistently proportioned across slots so
  layers line up (e.g., the head region for hair/hat/face always at the same
  rows). Exact anchor coordinates are in
  [`PIXEL_ART_GUIDE.md`](PIXEL_ART_GUIDE.md) §2.
- No anti-aliasing if you want a clean pixel look — the renderer disables
  smoothing.
- Home decor sprites can also be 64×64; they're placed in the room grid.

---

## 5. Where the rendering lives

| Piece | File |
|---|---|
| Slots, canvas size, `asset` / `sharedAsset` paths, colour recipe | `lib/models/shop_item.dart` |
| Key colours and palettes | `lib/core/sprite_palette.dart` (mirrors `art/palettes/walk_key.gpl`) |
| Aseprite frames, tags, `head` slice | `lib/core/sprite_sheet.dart` |
| Load, recolour and cache; draw one frame | `lib/widgets/pixel_sprite.dart` |
| Layered character compositor (idle / walk) | `lib/features/character/character_profile.dart` |
| Item thumbnail (shop / customiser) | `lib/widgets/sprite_thumb.dart` |
| Catalog (all item ids + coords) | `lib/data/shop_catalog.dart` |

Missing art degrades gracefully to the emoji, so you can replace sprites
piecemeal, in any order.

## 6. Recolouring and frames

Draw an item once in the **key colours** of `art/palettes/walk_key.gpl`; the app
swaps each key colour for the same shade of the item's palette at load time.

- **Which file:** the item's own `<id>.png` wins. Otherwise its shared drawing
  `<spriteId>.png` is used: all ten `gen_top_tee_<colour>` items draw
  `gen_top_tee.png`, and the five skin tones draw `base.png` (the existing
  `base_<tone>.png` files keep working until they're removed).
- **Which colours:** the item's `colors` recipe, e.g. `{ColorZone.primary:
  'crimson'}`. Palette names and their 3-shade ramps live in
  `lib/core/sprite_palette.dart`. Worn layers also take the body's skin tone.
- **Frames:** export with **File → Export Sprite Sheet** and keep the `.json`
  beside the PNG (Array or Hash, with Tags and Slices). Tags `idle` and `walk`
  name the poses; Home plays `walk`, the customiser shows `idle`.
- **Head items** (hair, hats, faces, accessories) drawn as one frame are moved
  by the body's `head` slice on each frame, so they never need walk frames.

The step-by-step Aseprite guide is the "Recolourable Sprites in Aseprite" doc.
