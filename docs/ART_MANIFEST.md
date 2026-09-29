# Art Manifest — The Walk Culture

**GENERATED** by `tool/art_manifest.dart` — do not edit by hand. Regenerate with `dart run tool/art_manifest.dart > docs/ART_MANIFEST.md` after any change to `lib/data/shop_catalog.dart`.


---

## Where things stand

**6 of 592 files** exist today. But 592 is the wrong number to plan against: 500 of them are colour variants of just 50 shapes, so the real workload is about **142 distinct drawings** — 92 hand-authored plus 50 generated shapes, each exported in 10 colours.

| Slot | Files | Drawn | Drawings needed |
|---|---|---|---|
| Body | 5 | 5 | 5 |
| Bottom | 64 | 0 | 10 |
| Top | 94 | 0 | 22 |
| Shoes | 67 | 1 | 13 |
| Face | 35 | 0 | 8 |
| Hair | 73 | 0 | 19 |
| Hat | 73 | 0 | 19 |
| Accessory | 86 | 0 | 23 |
| Pet | 48 | 0 | 12 |
| Home | 47 | 0 | 11 |


---

## Rules that apply to every sprite

- **64×64** if it is worn on the body; **96×96 stage** if it stands beside him (pets, floor props). Transparent RGBA, no anti-aliasing.
- Upright anchors: crown **y3**, shoulders **y28**, ankles **y57**, centre **x32**. Ground line for stage props: **y88**, clear of the figure's column (x34–61).
- Light source top-left, shadows bottom-right. Skin and hair are 3 shades + outline from the ramp.
- The filename must match the catalog `id` exactly — that is the only link between art and code. Drop the PNG at the path in these tables and it appears; no code change.
- Full detail, palettes and the Aseprite pipeline: `docs/PIXEL_ART_GUIDE.md` and `docs/ASSETS.md`.

> **Health poses are not wired yet.** The guide's `_0`…`_6` pose suffixes are a planned contract; today the compositor loads one standing body per skin tone (`base_medium.png`, no suffix). Pose art drawn now would not be loaded by anything until that lands — so it is deliberately left out of the tables below.


---

## Draw in this order

- **P0 — Skin tones (5).** 5 of 5 done. Everything else is drawn on top of these, so they come first.
- **P1 — First week (32).** Common and Uncommon cosmetics: the only things a new player can afford, because the shop gates on banked wallet tier. If a tester quits in week one, this is all they ever saw.
- **P2 — Travel Pass (17).** Seasonal track exclusives — 5 free, 12 VIP-only. The VIP dozen is the thing a subscription actually buys, so an emoji placeholder there is the most expensive placeholder in the app.
- **P3 — Generated shapes (50 → 500 files).** One drawing each, palette-swapped into 10 colours. Cheapest coverage per hour of work by a wide margin.
- **P4 — Rare and prestige (38).** Rare through Celestial. Aspirational flex items nobody sees for weeks.


---

## P0 — Skin tones

|  | Name | File | Canvas |
|---|---|---|---|
| ✅ | Light Skin | `assets/character/base/base_light.png` | 64 sheet |
| ✅ | Fair Skin | `assets/character/base/base_fair.png` | 64 sheet |
| ✅ | Medium Skin | `assets/character/base/base_medium.png` | 64 sheet |
| ✅ | Brown Skin | `assets/character/base/base_brown.png` | 64 sheet |
| ✅ | Dark Skin | `assets/character/base/base_dark.png` | 64 sheet |


---

## P1 — First week


### Common and Uncommon — 1/32

Priced in Pebbles and Copper, so they are on the shelves from day one. Draw these before anything rarer.


#### Bottom (3)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Running Shorts | `assets/character/bottoms/bottom_shorts.png` | 64 sheet | common |
| ☐ | Jeans | `assets/character/bottoms/bottom_jeans.png` | 64 sheet | common |
| ☐ | Skirt | `assets/character/bottoms/bottom_skirt.png` | 64 sheet | uncommon |


#### Top (4)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Athletic Tee | `assets/character/tops/top_tee.png` | 64 sheet | common |
| ☐ | Tank Top | `assets/character/tops/top_tank.png` | 64 sheet | common |
| ☐ | Blouse | `assets/character/tops/top_blouse.png` | 64 sheet | uncommon |
| ☐ | Hoodie | `assets/character/tops/top_hoodie.png` | 64 sheet | uncommon |


#### Shoes (3)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ✅ | Running Shoes | `assets/character/shoes/shoes_run.png` | 64 sheet | common |
| ☐ | Sandals | `assets/character/shoes/shoes_sandal.png` | 64 sheet | common |
| ☐ | Hiking Boots | `assets/character/shoes/shoes_boot.png` | 64 sheet | uncommon |


#### Face (4)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Smile | `assets/character/face/face_smile.png` | 64 sheet | common |
| ☐ | Big Grin | `assets/character/face/face_grin.png` | 64 sheet | common |
| ☐ | Wink | `assets/character/face/face_wink.png` | 64 sheet | uncommon |
| ☐ | Cool | `assets/character/face/face_cool.png` | 64 sheet | uncommon |


#### Hair (6)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Short Hair | `assets/character/hair/hair_short.png` | 64 sheet | common |
| ☐ | Buzz Cut | `assets/character/hair/hair_buzz.png` | 64 sheet | common |
| ☐ | Long Hair | `assets/character/hair/hair_long.png` | 64 sheet | common |
| ☐ | Curly Hair | `assets/character/hair/hair_curly.png` | 64 sheet | uncommon |
| ☐ | Redhead | `assets/character/hair/hair_redhead.png` | 64 sheet | uncommon |
| ☐ | Ponytail | `assets/character/hair/hair_ponytail.png` | 64 sheet | uncommon |


#### Hat (4)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Runner Cap | `assets/character/hats/hat_cap.png` | 64 sheet | common |
| ☐ | Cozy Beanie | `assets/character/hats/hat_beanie.png` | 64 sheet | common |
| ☐ | Straw Hat | `assets/character/hats/hat_straw.png` | 64 sheet | uncommon |
| ☐ | Top Hat | `assets/character/hats/hat_top.png` | 64 sheet | uncommon |


#### Accessory (3)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Cool Shades | `assets/character/accessories/acc_glasses.png` | 64 sheet | uncommon |
| ☐ | Round Glasses | `assets/character/accessories/acc_specs.png` | 64 sheet | uncommon |
| ☐ | Scarf | `assets/character/accessories/acc_scarf.png` | 64 sheet | uncommon |


#### Pet (2)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Puppy | `assets/pets/pet_dog.png` | 96 stage | uncommon |
| ☐ | Kitten | `assets/pets/pet_cat.png` | 96 stage | uncommon |


#### Home (3)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Potted Plant | `assets/home/home_plant.png` | 64 sheet | common |
| ☐ | Area Rug | `assets/home/home_rug.png` | 64 sheet | uncommon |
| ☐ | Cozy Lamp | `assets/home/home_lamp.png` | 64 sheet | uncommon |


---

## P2 — Travel Pass exclusives


### Free track — 0/5

Earned on the free column at levels 5, 12, 20, 25 and 30.


#### Top (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Wayfarer Tee | `assets/character/tops/pass_wayfarer_tee.png` | 64 sheet | uncommon |


#### Shoes (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Dust Road Boots | `assets/character/shoes/pass_dust_boots.png` | 64 sheet | rare |


#### Hat (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Trail Cap | `assets/character/hats/pass_trail_cap.png` | 64 sheet | uncommon |


#### Accessory (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Pilgrim Staff | `assets/character/accessories/pass_pilgrim_staff.png` | 64 sheet | rare |


#### Home (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Road Lantern | `assets/home/pass_lantern.png` | 64 sheet | rare |


### VIP track — 0/12

VIP-only. These are what the subscription sells.


#### Top (2)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Cartographer's Cloak | `assets/character/tops/pass_vip_cloak.png` | 64 sheet | rare |
| ☐ | Wanderer's Coat | `assets/character/tops/pass_vip_coat.png` | 64 sheet | legendary |


#### Shoes (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Starlit Boots | `assets/character/shoes/pass_vip_boots.png` | 64 sheet | legendary |


#### Hair (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Horizon Braid | `assets/character/hair/pass_vip_braid.png` | 64 sheet | epic |


#### Hat (2)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Caravan Hat | `assets/character/hats/pass_vip_hat.png` | 64 sheet | epic |
| ☐ | Sunrise Crown | `assets/character/hats/pass_vip_crown.png` | 64 sheet | celestial |


#### Accessory (4)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Traveler's Sash | `assets/character/accessories/pass_vip_sash.png` | 64 sheet | rare |
| ☐ | Golden Compass | `assets/character/accessories/pass_vip_compass.png` | 64 sheet | epic |
| ☐ | Aurora Mantle | `assets/character/accessories/pass_vip_mantle.png` | 64 sheet | legendary |
| ☐ | Wayfinder's Halo | `assets/character/accessories/pass_vip_halo.png` | 64 sheet | celestial |


#### Pet (2)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Desert Camel | `assets/pets/pass_vip_camel.png` | 96 stage | epic |
| ☐ | Trail Phoenix | `assets/pets/pass_vip_phoenix.png` | 96 stage | legendary |


---

## P3 — Generated shapes

One drawing per row, exported 10 times with the palette swapped. The colour words are the same for every shape: Crimson, Amber, Emerald, Azure, Violet, Onyx, Ivory, Rose, Slate, Golden.

Files follow `<prefix><colour>.png`, lowercase — e.g. `gen_top_tee_crimson.png`.


#### Bottom (6 shapes → 60 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Shorts | `assets/character/bottoms/` | `gen_bottom_shorts_<colour>.png` |
| 0/10 | Jeans | `assets/character/bottoms/` | `gen_bottom_jeans_<colour>.png` |
| 0/10 | Joggers | `assets/character/bottoms/` | `gen_bottom_joggers_<colour>.png` |
| 0/10 | Skirt | `assets/character/bottoms/` | `gen_bottom_skirt_<colour>.png` |
| 0/10 | Leggings | `assets/character/bottoms/` | `gen_bottom_leggings_<colour>.png` |
| 0/10 | Cargos | `assets/character/bottoms/` | `gen_bottom_cargos_<colour>.png` |


#### Top (8 shapes → 80 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Tee | `assets/character/tops/` | `gen_top_tee_<colour>.png` |
| 0/10 | Tank | `assets/character/tops/` | `gen_top_tank_<colour>.png` |
| 0/10 | Hoodie | `assets/character/tops/` | `gen_top_hoodie_<colour>.png` |
| 0/10 | Jacket | `assets/character/tops/` | `gen_top_jacket_<colour>.png` |
| 0/10 | Sweater | `assets/character/tops/` | `gen_top_sweater_<colour>.png` |
| 0/10 | Polo | `assets/character/tops/` | `gen_top_polo_<colour>.png` |
| 0/10 | Jersey | `assets/character/tops/` | `gen_top_jersey_<colour>.png` |
| 0/10 | Windbreaker | `assets/character/tops/` | `gen_top_windbreaker_<colour>.png` |


#### Shoes (6 shapes → 60 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Sneakers | `assets/character/shoes/` | `gen_shoes_sneakers_<colour>.png` |
| 0/10 | Boots | `assets/character/shoes/` | `gen_shoes_boots_<colour>.png` |
| 0/10 | Sandals | `assets/character/shoes/` | `gen_shoes_sandals_<colour>.png` |
| 0/10 | Heels | `assets/character/shoes/` | `gen_shoes_heels_<colour>.png` |
| 0/10 | Loafers | `assets/character/shoes/` | `gen_shoes_loafers_<colour>.png` |
| 0/10 | Cleats | `assets/character/shoes/` | `gen_shoes_cleats_<colour>.png` |


#### Face (3 shapes → 30 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Smirk | `assets/character/face/` | `gen_face_smirk_<colour>.png` |
| 0/10 | Blush | `assets/character/face/` | `gen_face_blush_<colour>.png` |
| 0/10 | Focus | `assets/character/face/` | `gen_face_focus_<colour>.png` |


#### Hair (6 shapes → 60 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Bob | `assets/character/hair/` | `gen_hair_bob_<colour>.png` |
| 0/10 | Braids | `assets/character/hair/` | `gen_hair_braids_<colour>.png` |
| 0/10 | Waves | `assets/character/hair/` | `gen_hair_waves_<colour>.png` |
| 0/10 | Bun | `assets/character/hair/` | `gen_hair_bun_<colour>.png` |
| 0/10 | Pixie | `assets/character/hair/` | `gen_hair_pixie_<colour>.png` |
| 0/10 | Dreads | `assets/character/hair/` | `gen_hair_dreads_<colour>.png` |


#### Hat (6 shapes → 60 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Cap | `assets/character/hats/` | `gen_hat_cap_<colour>.png` |
| 0/10 | Beanie | `assets/character/hats/` | `gen_hat_beanie_<colour>.png` |
| 0/10 | Fedora | `assets/character/hats/` | `gen_hat_fedora_<colour>.png` |
| 0/10 | Sunhat | `assets/character/hats/` | `gen_hat_sunhat_<colour>.png` |
| 0/10 | Visor | `assets/character/hats/` | `gen_hat_visor_<colour>.png` |
| 0/10 | Bucket Hat | `assets/character/hats/` | `gen_hat_bucket_hat_<colour>.png` |


#### Accessory (7 shapes → 70 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Shades | `assets/character/accessories/` | `gen_accessory_shades_<colour>.png` |
| 0/10 | Glasses | `assets/character/accessories/` | `gen_accessory_glasses_<colour>.png` |
| 0/10 | Scarf | `assets/character/accessories/` | `gen_accessory_scarf_<colour>.png` |
| 0/10 | Watch | `assets/character/accessories/` | `gen_accessory_watch_<colour>.png` |
| 0/10 | Gloves | `assets/character/accessories/` | `gen_accessory_gloves_<colour>.png` |
| 0/10 | Belt | `assets/character/accessories/` | `gen_accessory_belt_<colour>.png` |
| 0/10 | Pendant | `assets/character/accessories/` | `gen_accessory_pendant_<colour>.png` |


#### Pet (4 shapes → 40 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Hamster | `assets/pets/` | `gen_pet_hamster_<colour>.png` |
| 0/10 | Panda | `assets/pets/` | `gen_pet_panda_<colour>.png` |
| 0/10 | Owl | `assets/pets/` | `gen_pet_owl_<colour>.png` |
| 0/10 | Penguin | `assets/pets/` | `gen_pet_penguin_<colour>.png` |


#### Home (4 shapes → 40 files)

|  | Shape | Folder | File prefix |
|---|---|---|---|
| 0/10 | Vase | `assets/home/` | `gen_home_vase_<colour>.png` |
| 0/10 | Candle | `assets/home/` | `gen_home_candle_<colour>.png` |
| 0/10 | Cactus | `assets/home/` | `gen_home_cactus_<colour>.png` |
| 0/10 | Painting | `assets/home/` | `gen_home_painting_<colour>.png` |


---

## P4 — Rare and prestige


### Rare through Celestial — 0/38

Gated behind Silver, Gold, Titanium and above. Weeks of walking away for most players.


#### Bottom (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Cargo Pants | `assets/character/bottoms/bottom_cargo.png` | 64 sheet | rare |


#### Top (7)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Winter Coat | `assets/character/tops/top_coat.png` | 64 sheet | rare |
| ☐ | Kimono | `assets/character/tops/top_kimono.png` | 64 sheet | epic |
| ☐ | Phoenix Robe | `assets/character/tops/top_phoenix.png` | 64 sheet | legendary |
| ☐ | Starlit Cloak | `assets/character/tops/top_starcloak.png` | 64 sheet | celestial |
| ☐ | Frost Cloak | `assets/character/tops/pr_frost_cloak.png` | 64 sheet | legendary |
| ☐ | Void Hood | `assets/character/tops/pr_void_hood.png` | 64 sheet | legendary |
| ☐ | Eternity Cloak | `assets/character/tops/pr_eternity_cloak.png` | 64 sheet | celestial |


#### Shoes (2)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Party Heels | `assets/character/shoes/shoes_heels.png` | 64 sheet | rare |
| ☐ | Chrome Kicks | `assets/character/shoes/pr_chrome_kicks.png` | 64 sheet | legendary |


#### Face (1)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Freckles | `assets/character/face/face_freckles.png` | 64 sheet | rare |


#### Hair (6)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Afro | `assets/character/hair/hair_afro.png` | 64 sheet | rare |
| ☐ | Silver Hair | `assets/character/hair/hair_silver.png` | 64 sheet | rare |
| ☐ | Mohawk | `assets/character/hair/hair_mohawk.png` | 64 sheet | rare |
| ☐ | Rainbow Hair | `assets/character/hair/hair_rainbow.png` | 64 sheet | epic |
| ☐ | Galaxy Hair | `assets/character/hair/hair_galaxy.png` | 64 sheet | legendary |
| ☐ | Inferno Mane | `assets/character/hair/pr_inferno_mane.png` | 64 sheet | celestial |


#### Hat (6)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Graduation Cap | `assets/character/hats/hat_grad.png` | 64 sheet | rare |
| ☐ | Golden Crown | `assets/character/hats/hat_crown.png` | 64 sheet | epic |
| ☐ | Mystic Antlers | `assets/character/hats/hat_antlers.png` | 64 sheet | legendary |
| ☐ | Titanium Helm | `assets/character/hats/pr_titan_helm.png` | 64 sheet | legendary |
| ☐ | Platinum Crown | `assets/character/hats/pr_plat_crown.png` | 64 sheet | legendary |
| ☐ | Diamond Crown | `assets/character/hats/pr_diamond_crown.png` | 64 sheet | celestial |


#### Accessory (8)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Day Pack | `assets/character/accessories/acc_backpack.png` | 64 sheet | rare |
| ☐ | Fitness Watch | `assets/character/accessories/acc_watch.png` | 64 sheet | rare |
| ☐ | Gold Chain | `assets/character/accessories/acc_necklace.png` | 64 sheet | epic |
| ☐ | Aurora Wings | `assets/character/accessories/acc_wings.png` | 64 sheet | legendary |
| ☐ | Celestial Halo | `assets/character/accessories/acc_halo.png` | 64 sheet | celestial |
| ☐ | Tanzanite Wings | `assets/character/accessories/pr_tanz_wings.png` | 64 sheet | legendary |
| ☐ | Emerald Charm | `assets/character/accessories/pr_emerald_charm.png` | 64 sheet | legendary |
| ☐ | Ruby Halo | `assets/character/accessories/pr_ruby_halo.png` | 64 sheet | celestial |


#### Pet (4)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Bunny | `assets/pets/pet_bunny.png` | 96 stage | rare |
| ☐ | Fox | `assets/pets/pet_fox.png` | 96 stage | epic |
| ☐ | Baby Dragon | `assets/pets/pet_dragon.png` | 96 stage | legendary |
| ☐ | Jade Dragon | `assets/pets/pr_jade_dragon.png` | 96 stage | legendary |


#### Home (3)

|  | Name | File | Canvas | Rarity |
|---|---|---|---|---|
| ☐ | Wall Clock | `assets/home/home_clock.png` | 64 sheet | rare |
| ☐ | Aquarium | `assets/home/home_aquarium.png` | 64 sheet | epic |
| ☐ | Crystal Fountain | `assets/home/home_fountain.png` | 64 sheet | legendary |

