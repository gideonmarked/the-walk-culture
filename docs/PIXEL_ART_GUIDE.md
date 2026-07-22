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

- **Canvas:** 64×64 px, RGBA, transparent background, **no anti-aliasing** (hard
  pixel edges only).
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

**Fixed for the upright poses (`_3`–`_6`) and every cosmetic:**
- **Head box:** centred, `x 22–42`, `y 4–24`. Faces and hair are drawn to this box.
- **Shoulder line:** `y ≈ 24`. Tops start here.
- **Hip line:** `y ≈ 40`. Bottoms start here.
- **Ankle line:** `y ≈ 58`, **ground line `y = 64`**. Feet always touch the bottom.
- **Centre line:** `x = 32`. The figure is symmetric around it.

These anchors hold for the **upright walking poses** (health levels 3–6), where
cosmetics layer on top. The **downed poses** (laying/crawling/hunched, levels
0–2) don't use this skeleton — the figure is horizontal — so they're authored as
free-form full-body sprites with no cosmetic layering (see §4). Because the
upright anchor is shared, **hats, hair, faces, glasses, shoes, and clothing are
drawn once and fit every upright level.**

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
1. Draw the base body (per pose, §4) using exactly those 4 slots.
2. Duplicate the file, swap the 4 skin colours to the next tone, export.
3. Result: 5 skin files per pose, but only **one** actual drawing.

> Keep skin to those 3 shades + outline. More shades = more work per tone and a
> muddier look at 64px.

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
- **Clothing / hair / hats / face / shoes / accessories / pets: drawn ONCE**
  (for the upright anchor), shown on levels 3–6. **No per-pose variants** — this
  is the big saving versus the body-shape plan.
- **Trade-off:** equipped cosmetics don't show while downed (0–2). That's the
  intended hook — *stand up (get healthy) and your outfit appears.*

### Naming contract (art ↔ code)

```
assets/character/base/base_medium_0.png … base_medium_6.png   (× each skin tone)
assets/character/tops/top_hoodie.png       (single upright sprite — no suffix)
assets/character/hair/hair_ponytail.png    (single upright sprite)
assets/character/hats/hat_cap.png          (single upright sprite)
```

Only the **base** gets the `_0`…`_6` pose suffix. Cosmetics stay single-file and
render only on the upright levels.

> **Code note:** the compositor doesn't do this yet — today it loads
> `assets/<slot>/<id>.png` flat with one standing body. Wiring it means: pick the
> base by `_$healthLevel`; for levels 0–2 draw only the base; for 3–6 draw base +
> equipped cosmetics on the shared anchor; later, animate `_6`. I can build that
> when you're ready — this is the contract it'll follow.

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

1. **The 4 key pose bases** in `base_medium`: `_0` laying, `_2` hunched, `_3`
   upright, `_6` upright (the future animated one). This alone shows the posture
   arc from floor to standing.
2. **Fill `_1` crawling, `_4` `_5`** (the remaining poses).
3. Recolour all 7 to the other **4 skin tones** (palette swap, §3).
4. **1 face**, **2–3 hair styles** (each in 3–4 colours), **1 top**, **1 bottom**,
   **1 hat**, **1 shoes** — each a **single upright sprite** (they show on the
   standing poses 3–6).

That gives a character that visibly rises from the floor to walking as you get
healthier, and shows off an outfit once upright — the core promise. The 7 pose
bases are the bulk of the work; every cosmetic is drawn once.

---

## 8. Checklist before you hand off a sprite

- [ ] 64×64, transparent, RGBA, no anti-aliasing.
- [ ] Light source top-left; shadows bottom-right.
- [ ] Skin = 3 shades + outline from the ramp; hair = 3 shades + outline.
- [ ] **Base body?** Delivered as `_0`…`_6` (7 poses). Upright poses `_3`–`_6`
      use the §2 anchors (head `x22–42 y4–24`, feet `y64`, centre `x32`); downed
      poses `_0`–`_2` are free-form in the frame.
- [ ] **Cosmetic** (top/bottom/hair/face/hat/accessory/shoes/pet)? A single
      upright sprite on the §2 anchors — no pose suffix.
- [ ] File name matches the catalog `id`. GUIDE layer removed.
