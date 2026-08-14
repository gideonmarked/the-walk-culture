# Pixel-Art Guide — characters, skin tones, hair, and health poses

How to actually *draw* the art for The Walk Culture. Pairs with
[`ASSETS.md`](ASSETS.md) (which covers where files go and how they load). Read
that first; this is the "how to make the pixels" companion.

The one rule that governs everything below: **the character is a paper doll.**
Separate 64×64 layers are stacked to make one figure, so every layer must line
up perfectly with every other. Alignment is more important than art quality —
a beautiful hat that sits 3px too high ruins every character that wears it.

---

## 0. The short version

- **Two canvases:** the **character sheet is 64×64** (the body and everything
  *worn* on it), and the **stage is 96×96** — the scene around him, where things
  that aren't worn live: a pet at his side, a bag on the floor, wings. The 64×64
  character box sits at `x16, y24` inside the stage; the floor line is `y88`.
  Both canvases: RGBA, transparent background, **no anti-aliasing** (hard pixel
  edges only). Full spec in §2.
- **Anchors come from the art, not from theory.** §2a's coordinates are measured
  off `assets/character/base/tones.png`; the figure is chibi (head = a third of
  the body), so use those numbers rather than realistic proportions.
- **Skin tones & hair colours:** draw the *shape* once, then **swap the palette**
  to make every colour. You are not redrawing — you are recolouring.
- **Health poses:** the character's **posture** reflects health — **laying down
  (worst) → crawling → hunched → walking upright (best)**, one pose per health
  level (7 total), and the top pose is **animated** later. Because a pose moves
  the whole figure, cosmetics can't reuse across the downed poses — so the
  **downed poses (laying/crawling/hunched) are simple base-only sprites**, and
  **cosmetics layer only on the upright poses** (where the head/feet anchors from
  §2 hold). That keeps clothing drawn **once** and makes "get healthy and your
  outfit shows" the hook. Full detail in §4.

---

## 1. Tools & setup

- **Use [Aseprite](https://www.aseprite.org/)** (or the free
  [LibreSprite](https://libresprite.github.io/)). It's the pixel-art standard and
  has the two features you'll live in: **palette swapping** and **layers/tags**.
- New file: **64 × 64 px** for anything worn on the body, **96 × 96 px** for
  stage props (§2). Colour mode **RGBA** (you can switch to Indexed for palette
  work). Background: **transparent**.
- View → **Grid**: 1px grid, plus a **Pixel Grid** on. Turn **snapping** on.
- **One light source, top-left**, for the whole game. Every sprite is lit from
  the upper-left so shadows fall bottom-right. Be consistent or layers will fight.
- Keep a **master template file** with the guide layers from §2 — start every new
  sprite from it so anchors are identical.

---

## 2. Alignment anchors (the most important section)

### 2a. The character sheet — 64×64

Every 64×64 sprite shares the same skeleton so layers stack cleanly. Put these on
a locked "GUIDE" layer in your template (delete/hide before export). Coordinates
are (x from left, y from top), origin top-left, y increases downward.

**These numbers are measured from the real base art**
(`assets/character/base/tones.png`) rather than invented — the figure is chibi,
so the head is a third of the body and the anchors are nothing like a realistic
figure's. Match them exactly and every cosmetic will fit.

```
 y
 0  ┌────────────────────────────┐  ← top edge (3px of air)
 3  │         ▓▓▓▓▓▓▓▓           │  CROWN          x 27–36  (hats start here)
    │      ▓▓▓▓ face ▓▓▓▓        │  HEAD  y 3–23   widest x 18–45 at y17–21
23  │       ▓▓▓▓▓▓▓▓▓▓▓▓         │  ── JAW (y≈23) ──
27  │            ▒▒              │  NECK  y 24–27  x 27–36  (w10, narrowest)
28  │        ░░░░░░░░░░          │  ── SHOULDER LINE (y=28) ── tops start here
    │      ░░░░ torso ░░░░       │  arms/hands reach x 19–44 by y42
47  │       ░░░░░░░░░░░░         │  ── HIP LINE (y≈47) ── bottoms start here
48  │          ██  ██            │  LEGS  y 48–56  x 25–38  (w14)
57  │          ██  ██            │  ── ANKLE LINE (y=57) ── shoes start here
62  │         ████████           │  FEET  y 57–62  widest x 21–42
64  └────────────────────────────┘  ← ground line
    x0      18   27  36  45    64
```

**Fixed for the upright poses (`_3`–`_6`) and every cosmetic:**
- **Head:** `y 3–23`, widening from `x 27–36` at the crown to `x 18–45` by `y17`.
  Faces and hair are drawn to this box. It is **as wide as the whole body** —
  don't draw a small realistic head.
- **Neck:** `y 24–27`, only **10px wide** (`x 27–36`). The pinch point.
- **Shoulder line:** `y = 28`. Tops start here.
- **Hip line:** `y ≈ 47`. Bottoms start here; legs begin at `y48`.
- **Ankle line:** `y = 57`. Shoes occupy `y 57–62`.
- **Ground line:** the art's lowest row is `y62`, so there is **1px of air below
  the feet** — keep new sprites consistent with that rather than pushing to
  `y63`.
- **Centre line:** `x = 32` (the figure spans `x 18–45`, symmetric about the
  edge between columns 31 and 32).
- **Overall figure:** 28 px wide × 60 px tall inside the 64×64 frame.

These anchors hold for the **upright walking poses** (health levels 3–6), where
cosmetics layer on top. The **downed poses** (laying/crawling/hunched, levels
0–2) don't use this skeleton — the figure is horizontal — so they're authored as
free-form full-body sprites with no cosmetic layering (see §4). Because the
upright anchor is shared, **hats, hair, faces, glasses, shoes, and clothing are
drawn once and fit every upright level.**

### 2b. The stage — 96×96 (the room he stands in)

64×64 is exactly the character and nothing else, so there is nowhere to put a
dog, a satchel on the floor, or a pair of wings. Those live on the **stage**: a
**96 × 96** canvas with the character sheet dropped into the middle of it.

```
 stage y
  0  ┌───────────────────────────────────┐  ← stage top (96 × 96)
     │        headroom  24px             │   tall hats · halos · flying pets
 24  │  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐        │  ── CHARACTER BOX top ──
     │  │   ▓▓▓▓▓▓▓▓             │        │   the 64×64 sheet from §2a,
     │  │   character            │        │   pasted at x16, y24
     │  │      ██  ██            │        │   free floor: x0–34 and x62–96
 88  │  └ ─ ─ ─██──██─ ─ ─ ─ ─ ┘        │  ── GROUND LINE (y88) ──
 96  └───────────────────────────────────┘  ← 8px floor strip (shadows)
     x0    16       32      80        96
```

- **Stage canvas:** `96 × 96`, same rules (RGBA, transparent, no AA).
- **Character box:** `x 16–80`, `y 24–88`. Add `+16, +24` to any §2a coordinate
  to get its stage coordinate (the crown becomes `x 43–52`, `y 27`).
- **Ground line: `y = 88`.** The character's feet rest here and so does anything
  standing next to him. A prop `h` px tall sits at `y = 88 − h`.
- **Floor strip:** `y 88–96`. Contact shadows, puddles, a mat under the bag.
- **Headroom:** `y 0–24`. Tall hats, a halo, a bird or dragon in the air.
- **Free floor:** the *figure* only fills `x 34–61` of the stage, so you have
  **34 px of clear ground on each side** — plenty for a sitting dog (~22×18), a
  satchel (~14×12) or a water bowl.

**Two ways to author a stage sprite:**

1. **Full 96×96 frame** — draw the prop where it belongs in the frame and leave
   `x`/`y` at `0`. Simplest; the art positions itself.
2. **Tight sprite + coords** (**recommended for pets and props**) — export just
   the prop at its own size and set `x`/`y`/`w`/`h` in the catalog, e.g. a 22×18
   dog on the right of the ground line:
   ```dart
   ShopItem(id: 'pet_dog', …, slot: ItemSlot.pet, x: 66, y: 70, w: 22, h: 18),
   ```
   `y 70 = 88 − 18`, so it stands on the floor. This keeps the file small and —
   because the **shop thumbnail shows the raw PNG** — a tight sprite fills its
   thumbnail instead of being a dog lost in a mostly-empty 96px square.

**Stage props draw in front of the character** (pet is the last layer), and
because they don't hang off the body skeleton they are **visible at every health
level, including the downed poses** — your dog stays with you when you're on the
floor. That's the one exception to "cosmetics only show when upright" (§4).

> **Which canvas?** Worn on the body (base, face, hair, hat, top, bottom, shoes,
> glasses) → **64×64 sheet**. Stands beside/around him (pets, floor props, wings,
> auras) → **96×96 stage**. In code this is `kStageSlots` in
> [`lib/models/shop_item.dart`](../lib/models/shop_item.dart), with a per-item
> `stageSpace:` override for the odd accessory (wings) that needs the room.

---

## 3. Skin tones — draw once, recolour many

Do **not** redraw the body for each skin tone. Draw the body **once**, then swap
the palette to get every tone — one Aseprite file, one frame per tone, each
frame **tagged with the tone name**.

### The pipeline (this is what `tones.aseprite` already does)

1. Draw the body once (per pose, §4) using a **small, fixed set of skin slots**:
   outline + shadow + mid (+ an optional highlight pixel).
2. Add a frame per tone and palette-swap the skin slots. **Tag each frame** with
   the tone name — `Medium`, `Fair`, `Light`, …
3. Export **File → Export Sprite Sheet** with *JSON Data* on (Hash or Array,
   either works) → `assets/character/base/tones.png` + `tones.json`.
4. Slice the sheet into the per-id PNGs the app loads:
   ```
   python3 tool/slice_aseprite_sheet.py \
       assets/character/base/tones.png assets/character/base/tones.json \
       --prefix base_
   ```
   Tag `Medium` → `base_medium.png`, and so on — lowercased and prefixed, which
   is exactly the catalogue id. The slicer re-inflates each trimmed frame back
   onto the full `sourceSize` canvas, so **alignment survives trimming**. Re-run
   it after every export; it's the only manual step.

### The ramps actually in use

Measured from `tones.png` — use these, not invented values, so new tones sit in
the same family:

| Tone (id) | Outline | Shadow | Mid | Highlight |
|---|---|---|---|---|
| `base_light`  | `#000001` | `#bda08c` | `#e0cdc0` | `#f8edf2` |
| `base_fair`   | `#000001` | `#bd8665` | `#d79f7d` | `#f6d39f` |
| `base_medium` | `#000001` | `#774b31` | `#c5835b` | — |
| `base_brown`  | *not drawn yet* | | | |
| `base_dark`   | *not drawn yet* | | | |

The shared (never-swapped) colours are the outline `#000001` / `#000004`, the
vest `#dee5eb`, and the shorts `#6d787a` / `#353d46` / `#565a63`.

> **Keep the ramp to 2–3 shades + outline.** `Fair` and `Light` are clean: 2 skin
> shades each. `Medium` currently carries **23** near-identical skin shades
> (`#c5835b`, `#c68b60`, `#bf7d53`, `#ba7b52` … all within a few points of each
> other), which makes it read slightly muddier and turns each future palette swap
> into a 23-slot mapping instead of a 2-slot one. Flatten it in the `.aseprite`
> source — Aseprite's *Edit → Replace Color* with a tolerance, or Indexed mode
> with a 4-colour palette — before drawing `base_brown` and `base_dark`.

---

## 4. Health poses — laying down → walking upright

This is the mechanic: as the player's **health level** rises, their **posture**
improves — from flat on the ground to standing tall and moving. The compositor
picks the pose by the `healthLevel` **index (0–6)**, so that index **is** the
base sprite's suffix.

| Level | Name | Suffix | Pose |
|---|---|---|---|
| 0 | Idle | `_0` | **laying down** — flat on the ground |
| 1 | Sluggish | `_1` | **crawling** — on hands & knees |
| 2 | Strolling | `_2` | **hunched** — bent forward, trudging |
| 3 | Steady | `_3` | standing, slight stoop — walking |
| 4 | Brisk | `_4` | upright, purposeful walk |
| 5 | Swift | `_5` | tall, striding |
| 6 | Soaring | `_6` | upright & moving — **animated later** (walk/run cycle) |

### The consequence: a pose moves the whole figure

Unlike a body-shape morph, changing *pose* relocates the head and feet — laying
and crawling are horizontal, there's no "head at top, feet at bottom." That
breaks the paper-doll reuse. The model that handles it (and is *cheaper* than
per-body clothing):

**Two tiers:**

- **Downed poses — `_0` laying, `_1` crawling, `_2` hunched:** authored as
  **whole-figure base sprites, no cosmetic layering.** These are "you're unwell"
  states; the goal is to get up, not to model an outfit on the floor. Draw them
  free-form in the 64×64 frame (the §2 anchors don't apply).
- **Upright poses — `_3`…`_6`:** all share the **same upright anchor** (§2 head
  box + feet + shoulder/hip lines), so **every cosmetic layers on them and is
  drawn once.** Keep the torso anchor identical across `_3`–`_6` so a top/hat
  fits all four; put the posture difference in the **legs/stance** (straightening
  and lengthening the stride from 3→6), not the torso.
- **`_6` is the future animated frame.** Author it as a static upright now; add
  the walk-cycle frames later (naming decided when we build the animator).

### What this costs (it's cheaper than the old plan)

- **Base body:** 7 pose sprites × skin tones — but 7 drawings recoloured via
  palette swap (§3), so 5 tones = **35 files from 7 drawings**. The 3 downed poses
  are genuinely distinct drawings; `_3`–`_6` are one upright body with small
  stance changes.
- **Clothing / hair / hats / face / shoes / accessories: drawn ONCE**
  (for the upright anchor), shown on levels 3–6. **No per-pose variants** — this
  is the big saving versus the body-shape plan.
- **Pets and floor props: drawn once on the stage** (§2b) and shown at **every**
  level. They stand on the ground line, not on the body, so no pose can break
  them.
- **Trade-off:** equipped *worn* cosmetics don't show while downed (0–2). That's
  the intended hook — *stand up (get healthy) and your outfit appears* — while
  the pet keeps you company on the floor.

### Naming contract (art ↔ code)

```
assets/character/base/base_medium_0.png … base_medium_6.png   (× each skin tone)
assets/character/tops/top_hoodie.png       (64×64 — single upright sprite, no suffix)
assets/character/hair/hair_ponytail.png    (64×64 — single upright sprite)
assets/character/hats/hat_cap.png          (64×64 — single upright sprite)
assets/pets/pet_dog.png                    (stage sprite — tight + x/y/w/h, or 96×96)
```

Only the **base** gets the `_0`…`_6` pose suffix. Worn cosmetics stay single-file
64×64 and render only on the upright levels; stage sprites (§2b) render always.

> **Code note:** the **stage is live** — the compositor renders on the 96×96
> canvas, offsets every worn sprite by the character origin, and honours
> `x`/`y`/`w`/`h` for tight props. **Health poses are not wired yet:** it still
> loads one standing body per slot. Wiring them means: pick the base by
> `_$healthLevel`; for levels 0–2 draw only the base (+ stage props); for 3–6
> draw base + worn cosmetics on the shared anchor; later, animate `_6`. I can
> build that when you're ready — this is the contract it'll follow.

### Alternative (expensive)

Full per-pose customisation — every cosmetic redrawn for all 7 poses — is only
worth it if showing outfits *while crawling* matters. Say so and I'll spec it,
but the two-tier model above is the recommended default.

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

- **PNG, RGBA, transparent.** **64×64** for anything worn on the body; for stage
  props either **96×96** or the sprite's own tight size with `x`/`y`/`w`/`h` set
  in the catalog (§2b). No JPEG (kills transparency + adds artifacts).
- **No anti-aliasing / no smoothing.** Hard edges only. In Aseprite this is the
  default pencil; just never use the AA brushes or blur.
- Hide/delete the GUIDE layer first.
- File name = the exact `id` (+ body suffix where required). Drop into the folder
  from [`ASSETS.md`](ASSETS.md). Run `flutter pub get` the first time a folder
  gains real files; rebuild.
- The app upscales 3× with nearest-neighbor (96 → 288), so **do not** pre-scale —
  deliver true 64×64. Design *at* 64px; don't shrink a big illustration down.

---

## 7. Minimum viable art set (what to make first)

Prioritised so the game looks real fast, cheapest first:

1. **The 4 key pose bases** in `base_medium`: `_0` laying, `_2` hunched, `_3`
   upright, `_6` upright (the future animated one). This alone shows the posture
   arc from floor to standing.
2. **Fill `_1` crawling, `_4` `_5`** (the remaining poses).
3. Recolour all 7 to the other **4 skin tones** (palette swap, §3).
4. **1 face**, **2–3 hair styles** (each in 3–4 colours), **1 top**, **1 bottom**,
   **1 hat**, **1 shoes** — each a **single upright 64×64 sprite** (they show on
   the standing poses 3–6).
5. **1 pet** (e.g. the dog) as a **stage sprite** (§2b) standing on the ground
   line beside him — the cheapest way to make the scene feel inhabited, and it
   shows at every health level.

That gives a character that visibly rises from the floor to walking as you get
healthier, and shows off an outfit once upright — the core promise. The 7 pose
bases are the bulk of the work; every cosmetic is drawn once.

---

## 8. Checklist before you hand off a sprite

- [ ] Right canvas: **64×64** if it's worn on the body, **96×96 stage** (or a
      tight sprite + `x`/`y`/`w`/`h`) if it stands beside him. Transparent, RGBA,
      no anti-aliasing.
- [ ] Light source top-left; shadows bottom-right.
- [ ] Skin = 3 shades + outline from the ramp; hair = 3 shades + outline.
- [ ] **Base body?** Delivered as `_0`…`_6` (7 poses). Upright poses `_3`–`_6`
      use the §2 anchors (crown `y3`, shoulders `y28`, ankles `y57`, centre
      `x32`); downed
      poses `_0`–`_2` are free-form in the frame.
- [ ] **Worn cosmetic** (top/bottom/hair/face/hat/glasses/shoes)? A single
      upright 64×64 sprite on the §2a anchors — no pose suffix.
- [ ] **Stage prop** (pet/floor item/wings)? Standing on the ground line
      (`y88`), clear of the figure's column (`x34–61`), and it reads at every
      health level — no pose suffix.
- [ ] File name matches the catalog `id`. GUIDE layer removed.
