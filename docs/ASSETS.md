# Graphic Assets — Pixel-Art Pipeline

How art is wired in so you can drop your own sprites in later. **Design spec:
64×64 pixel-art PNGs (RGBA, transparent background).** Character customisation is
prioritised; home comes second.

---

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

---

## 3. The character canvas & fixed placement

- All character sprites are composited on a **64×64 logical canvas** (`kCanvas`
  in [`lib/models/shop_item.dart`](../lib/models/shop_item.dart)), scaled up with
  `FilterQuality.none` so pixels stay crisp.
- **Layer order (back → front)** is `kCharacterSlots`:
  `base → bottom → top → shoes → face → hair → hat → accessory → pet`.
- **Placement is fixed, not user-movable.** Each item has `x` / `y` (top-left on
  the 64px canvas). Author sprites as **full 64×64 frames** and leave `x`/`y` at
  `0` (the art itself positions the element) — or set `x`/`y` to nudge a small
  element to an exact, locked spot. The player can equip/unequip but never drag
  things around.

To position something precisely, set its coords in the catalog, e.g.:
```dart
ShopItem(id: 'pet_dog', ..., slot: ItemSlot.pet, x: 38, y: 40),
```

---

## 4. Authoring guidelines

- **Size:** 64×64. **Format:** PNG, RGBA, transparent where empty.
- Keep the character centred and consistently proportioned across slots so
  layers line up (e.g., the head region for hair/hat/face always at the same
  rows).
- No anti-aliasing if you want a clean pixel look — the renderer disables
  smoothing.
- Home decor sprites can also be 64×64; they're placed in the room grid.

---

## 5. Where the rendering lives

| Piece | File |
|---|---|
| Slots, canvas size, `asset` path | `lib/models/shop_item.dart` |
| Layered character compositor | `lib/features/character/character_profile.dart` |
| Item thumbnail (shop / customiser) | `lib/widgets/sprite_thumb.dart` |
| Catalog (all item ids + coords) | `lib/data/shop_catalog.dart` |

Both the compositor and the thumbnail use `Image.asset(item.asset, errorBuilder:
… emoji)`, so missing art degrades gracefully to the emoji — you can replace
sprites piecemeal, in any order.
