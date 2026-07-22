# Pixel-Art Guide — characters, skin tones, hair, and health body types

How to actually *draw* the art for The Walk Culture. Pairs with
[`ASSETS.md`](ASSETS.md) (which covers where files go and how they load). Read
that first; this is the "how to make the pixels" companion.

The one rule that governs everything below: **the character is a paper doll.**
Separate 64×64 layers are stacked to make one figure, so every layer must line
up perfectly with every other. Alignment is more important than art quality —
a beautiful hat that sits 3px too high ruins every character that wears it.

---

## 0. The short version

- **Canvas:** 64×64 px, RGBA, transparent background, **no anti-aliasing** (hard
  pixel edges only).
- **Skin tones & hair colours:** draw the *shape* once, then **swap the palette**
  to make every colour. You are not redrawing — you are recolouring.
- **Health body types:** the body changes shape from **obese → very fit** as
  health rises — **7 body types, one per health level**. To keep this from
  exploding, **the head and feet never move between them**, so only body-wrapping
  clothes (base, tops, bottoms) need a version per body type; everything else
  (hair, face, hats, glasses, shoes, pets) is drawn **once**. Adjacent bodies
  differ only slightly, so you're nudging edges, not redrawing.

---

## 1. Tools & setup

- **Use [Aseprite](https://www.aseprite.org/)** (or the free
  [LibreSprite](https://libresprite.github.io/)). It's the pixel-art standard and
  has the two features you'll live in: **palette swapping** and **layers/tags**.
- New file: **64 × 64 px**, colour mode **RGBA** (you can switch to Indexed for
  palette work). Background: **transparent**.
- View → **Grid**: 1px grid, plus a **Pixel Grid** on. Turn **snapping** on.
- **One light source, top-left**, for the whole game. Every sprite is lit from
  the upper-left so shadows fall bottom-right. Be consistent or layers will fight.
- Keep a **master template file** with the guide layers from §2 — start every new
  sprite from it so anchors are identical.

---

## 2. Alignment anchors (the most important section)

Every 64×64 sprite shares the same skeleton so layers stack cleanly. Put these on
a locked "GUIDE" layer in your template (delete/hide before export). Coordinates
are (x from left, y from top), origin top-left, y increases downward.

```
 y
 0  ┌───────────────────────────┐  ← top edge
 4  │        ▓▓▓▓▓▓▓▓▓          │  HEAD top       (hats/hair sit here)
    │      ▓▓ face box ▓▓        │  head:  x 22–42, y 4–24
24  │        ▓▓▓▓▓▓▓▓▓          │  ── SHOULDER LINE (y≈24) ──
    │     ░░░░ torso ░░░░        │  torso: tops live here
40  │      ░░░░░░░░░░░░          │  ── HIP LINE (y≈40) ──
    │        ██  ██              │  legs:  bottoms live here
58  │        ██  ██              │  ── ANKLE LINE (y≈58) ──
62  │       ████████            │  FEET / shoes   (y 58–64)
64  └───────────────────────────┘  ← ground line (feet touch here)
    x0        22   42        64
```

**Fixed forever, across all body types and all items:**
- **Head box:** centred, `x 22–42`, `y 4–24`. Faces and hair are drawn to this box.
- **Shoulder line:** `y ≈ 24`. Tops start here.
- **Hip line:** `y ≈ 40`. Bottoms start here.
- **Ankle line:** `y ≈ 58`, **ground line `y = 64`**. Feet always touch the bottom.
- **Centre line:** `x = 32`. The figure is symmetric around it.

Because the head box and feet never move, **hats, hair, faces, glasses, and shoes
are drawn once and fit every character.** Only the region *between* shoulder and
ankle (the body) changes shape — that's §4.

---

## 3. Skin tones — draw once, recolour many

Do **not** redraw the body for each skin tone. Draw the body **once** in a
neutral mid-tone, using a **4-step ramp** (outline + 3 skin shades), then swap the
ramp to get every tone. In Aseprite: keep the 4 skin colours together in the
palette, then **Sprite → Color Mode → Indexed** and edit the palette, or use
**Edit → Replace Color**.

Each tone is a ramp of **outline / shadow / mid / highlight**. Starter palette
(hex — tune to taste, keep the same 4 *slots* so swapping is mechanical):

| Tone (id) | Outline | Shadow | Mid | Highlight |
|---|---|---|---|---|
| `base_light`  | `#3b2a25` | `#e8b89a` | `#f5cfb0` | `#ffe0c4` |
| `base_fair`   | `#3b2a25` | `#e0a878` | `#f0c090` | `#ffd8a8` |
| `base_medium` | `#33241c` | `#b57a52` | `#cd9366` | `#e0aa7e` |
| `base_brown`  | `#2a1c12` | `#7a4a2b` | `#955e38` | `#b0764a` |
| `base_dark`   | `#1f140d` | `#4a2e1e` | `#5e3b28` | `#78503a` |

**Method:**
1. Draw the base body (per body type, §4) using exactly those 4 slots.
2. Duplicate the file, swap the 4 skin colours to the next tone, export.
3. Result: 5 skin files per body type, but only **one** actual drawing.

> Keep skin to those 3 shades + outline. More shades = more work per tone and a
> muddier look at 64px.

---

## 4. Health body types — obese → very fit (7 bodies)

This is the mechanic: as the player's **health level** rises, the body visibly
morphs from **obese** to **very fit** — **one body per level, 7 in total**. Because
they're a smooth progression, you draw the two extremes first and the middle five
are small steps between them, not seven independent illustrations.

### The 7 bodies map 1:1 to health level

The character compositor picks the body by the player's `healthLevel` **index
(0–6)**, so that index **is** the file suffix.

| Level | Name | Suffix | Silhouette |
|---|---|---|---|
| 0 | Withered\* | `_0` | most **obese** — widest belly & hips, round torso |
| 1 | Ailing | `_1` | very heavy |
| 2 | Weary | `_2` | heavy / soft |
| 3 | Balanced | `_3` | neutral, straight build (the starting body) |
| 4 | Vital | `_4` | lean, waist starting to define |
| 5 | Thriving | `_5` | fit, broader shoulders, trim waist |
| 6 | Radiant | `_6` | **very fit** — athletic, defined, broadest shoulders |

\* Heads-up: "Withered" reads as *frail/thin*, but body `_0` is drawn **obese**
per the design. If that clashes, rename the level (e.g. "Sluggish") rather than
the art — the suffix is the numeric index, so level *names* can change freely
without touching filenames.

### The rule that keeps 7 bodies affordable

**Only the body between the shoulder line and the ankle line changes. The head
box and the feet stay identical across all 7.** So:

- **Vary by body (7× each):** `base` (body), `top`, `bottom`.
- **Draw once, fits all 7:** `hair`, `face`, `hat`, `accessory`, `shoes`, `pet`
  — they attach to the fixed head box or feet.

Silhouette progression at 64px — only the torso/belly/hip **width** changes;
shoulders gently broaden toward fit; head (`x22–42`) and feet (`y64`) never move:

```
        _0 obese        _3 balanced        _6 very fit
 head    x22–42          x22–42             x22–42        ← identical
 should. x18–46          x20–44             x16–48 (broad)
 chest   x15–49          x22–42             x20–44
 BELLY   x12–52 ●●       x23–41             x24–40 (flat)
 hips    x14–50          x23–41             x23–41
 feet    y64             y64                y64           ← identical
```

Bodies `_1`,`_2` interpolate between `_0` and `_3`; `_4`,`_5` between `_3` and
`_6`. Keep the **outline colour and skin ramp identical** across all seven — only
the *outline shape* moves. Author `_0`, `_3`, `_6` first (the anchors), then fill
`_1 _2 _4 _5` by nudging edges.

### Naming contract (art ↔ code)

Body-varying slots append the level index `_0`…`_6`:

```
assets/character/base/base_medium_0.png … base_medium_6.png   (× each skin tone)
assets/character/tops/top_hoodie_0.png  … top_hoodie_6.png
assets/character/bottoms/bottom_jeans_0.png … bottom_jeans_6.png
```

Body-independent slots keep the plain id (no suffix):

```
assets/character/hair/hair_ponytail.png
assets/character/hats/hat_cap.png
assets/character/face/face_smile.png
```

> **Code note:** the app does **not** yet pick the body by health — today it loads
> `assets/<slot>/<id>.png` flat. Adding the `_$healthLevel` selection is a small
> change to the compositor (append the index for base/top/bottom, fall back to the
> plain file when a variant is missing). I can wire it when you're ready — this
> naming is the contract it will follow.

### Cost, plainly

Seven bodies multiplies your torso/leg clothing by 7:
- A top or bottom = **7 sprites** each.
- A skin tone = **7 base shapes**, but still one *drawing* per body recoloured
  (§3): so 5 tones × 7 bodies = **35 base files from 7 drawings**.
- Hair / face / hats / shoes / accessories / pets = **unchanged** (1 each).

This is a real commitment — the clothing count is the driver. To keep it sane:
keep the number of **body-varying garments** small (a handful of tops/bottoms,
each in 7), and lean on hats/hair/accessories (drawn once) for variety. The
smooth-progression trick (anchors + interpolate) is what makes 7 bodies × a
garment closer to "2 real drawings + 5 tweaks" than 7 from scratch.

---

## 5. Hair — one shape, many colours

Same palette-swap idea as skin. Draw each **hair style** once (its silhouette),
using a **3-step ramp** (shadow / mid / highlight) plus the shared outline, then
recolour for each hair colour. Hair attaches to the fixed head box (§2), so it is
**not** body-type-varied.

Starter hair ramps:

| Colour | Shadow | Mid | Highlight |
|---|---|---|---|
| Black   | `#1a1a22` | `#2b2b38` | `#3d3d4e` |
| Brown   | `#3a2418` | `#5a3a24` | `#7a5236` |
| Blonde  | `#b8862f` | `#e0b34d` | `#f5d77a` |
| Ginger  | `#7a2e18` | `#a8482a` | `#c86a44` |
| Silver  | `#6a6a72` | `#9a9aa2` | `#c8c8d0` |
| Fun (blue) | `#2a4a8a` | `#3f6fd0` | `#6f9cf0` |

Workflow for "N styles × M colours":
1. Draw each **style** once (e.g. `ponytail`, `afro`, `mohawk`) in the neutral ramp.
2. Palette-swap to each **colour**, export as `hair_<style>_<colour>.png` (match
   the ids you want in `lib/data/shop_catalog.dart`).
3. Faces underneath must fit the same head box so any hair sits correctly on any
   face.

> The shop already generates colour-named variants (e.g. "Crimson", "Golden") —
> keep your file ids aligned with the catalog entries so they load automatically.

---

## 6. Export settings

- **PNG, 64×64, RGBA, transparent.** No JPEG (kills transparency + adds artifacts).
- **No anti-aliasing / no smoothing.** Hard edges only. In Aseprite this is the
  default pencil; just never use the AA brushes or blur.
- Hide/delete the GUIDE layer first.
- File name = the exact `id` (+ body suffix where required). Drop into the folder
  from [`ASSETS.md`](ASSETS.md). Run `flutter pub get` the first time a folder
  gains real files; rebuild.
- The app upscales ~3× with nearest-neighbor, so **do not** pre-scale — deliver
  true 64×64. Design *at* 64px; don't shrink a big illustration down.

---

## 7. Minimum viable art set (what to make first)

Prioritised so the game looks real fast, cheapest first:

1. **3 anchor bodies** — `_0` (obese), `_3` (balanced), `_6` (very fit) — in the
   `base_medium` tone. This alone proves the morph at its extremes.
2. **Fill the in-between bodies** `_1 _2 _4 _5` by nudging edges between the
   anchors (§4).
3. Recolour all 7 to the other **4 skin tones** (palette swap, §3).
4. **1 face** (`face_smile`) — fits every body.
5. **2–3 hair styles**, each in **3–4 colours** (§5).
6. **1 top + 1 bottom**, each in all **7 bodies** (author `_0/_3/_6`, interpolate
   the rest) — proves clothing-per-body.
7. **1 pair of shoes**, **1 hat** — body-independent, one each.

That gives a fully dressable character that visibly morphs obese→fit as you walk
— the core promise. The base + one outfit is the bulk of the work; everything
head-and-feet is drawn once.

---

## 8. Checklist before you hand off a sprite

- [ ] 64×64, transparent, RGBA, no anti-aliasing.
- [ ] Head box `x22–42 y4–24`, feet on ground line `y64`, centre `x32`.
- [ ] Light source top-left; shadows bottom-right.
- [ ] Skin = 3 shades + outline from the ramp; hair = 3 shades + outline.
- [ ] Body-varying slot (base/top/bottom)? Delivered as `_0`…`_6` (7 bodies).
- [ ] Body-independent slot (hair/face/hat/accessory/shoes/pet)? Single file.
- [ ] File name matches the catalog `id`. GUIDE layer removed.
