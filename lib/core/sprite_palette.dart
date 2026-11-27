import 'dart:typed_data';

/// Palette swapping for pixel art: sprites are drawn once in fixed **key
/// colours** (`art/palettes/walk_key.gpl`), and any pixel that matches a key
/// colour is swapped for the same shade of a chosen palette at load time.
/// Everything else — outline, white, metal — is left as drawn.
///
/// Each zone's ramp is three shades, dark → mid → light. Art may use only two
/// (dark + mid); the light slot then just never matches.
enum ColorZone { skin, hair, primary, secondary, accent }

/// The key ramps, exactly as in `art/palettes/walk_key.gpl` (0xRRGGBB).
/// Change one here and in the .gpl together, or old art stops recolouring.
const Map<ColorZone, List<int>> kKeyRamps = {
  ColorZone.skin: [0xbd8665, 0xd79f7d, 0xf6d39f],
  ColorZone.hair: [0x4a2c20, 0x6f4430, 0x9a6443],
  ColorZone.primary: [0x7a1e2c, 0xb9303f, 0xe2606b],
  ColorZone.secondary: [0x1e3c78, 0x2f61b7, 0x5e8fe1],
  ColorZone.accent: [0x87570f, 0xc88a1d, 0xf1bd4e],
};

/// Skin tones, sampled from the finished bodies in `assets/character/base/`
/// (shadow, mid) with a highlight added where the art had none.
const Map<String, List<int>> kSkinPalettes = {
  'light': [0xbda08c, 0xe0cdc0, 0xf8edf2],
  'fair': [0xa36f50, 0xd79f7d, 0xf6d39f],
  'medium': [0x774b31, 0xc5835b, 0xdba27a],
  'brown': [0x6e4126, 0x915a39, 0xb07650],
  'dark': [0x392011, 0x58331d, 0x774a2c],
};

const Map<String, List<int>> kHairPalettes = {
  'brown': [0x4a2c20, 0x6f4430, 0x9a6443],
  'black': [0x14141a, 0x2a2a33, 0x474756],
  'blonde': [0xa5762a, 0xd9ac4c, 0xf5d98a],
  'red': [0x7a2412, 0xb8431f, 0xe5743f],
  'silver': [0x6f7682, 0xa9b0bb, 0xe1e5ea],
};

/// The ten shop colours, plain → premium. Proposed ramps: the Pixel Art Brief
/// leaves these open, so tune them freely — no art changes when you do.
const Map<String, List<int>> kGarmentPalettes = {
  'crimson': [0x6b1424, 0xb02a3c, 0xe0596a],
  'amber': [0x8a4a0c, 0xd17f1a, 0xf5b54a],
  'emerald': [0x0f5a3a, 0x1f9160, 0x4fc98b],
  'azure': [0x173f7a, 0x2f6fc4, 0x66a3ee],
  'violet': [0x3f2275, 0x6a3fb3, 0x9c74e0],
  'onyx': [0x15161b, 0x2b2d35, 0x4a4d58],
  'ivory': [0xb8ab8c, 0xe3d9bf, 0xfbf6e6],
  'rose': [0x9c3d5c, 0xd9708f, 0xf5a8bd],
  'slate': [0x3a4652, 0x5c6b7a, 0x8d9cab],
  'golden': [0x8a5a00, 0xd49b12, 0xffe066],
};

/// Which named palettes a zone can take.
Map<String, List<int>> palettesFor(ColorZone zone) => switch (zone) {
      ColorZone.skin => kSkinPalettes,
      ColorZone.hair => kHairPalettes,
      _ => kGarmentPalettes,
    };

/// A colour recipe: which named palette each zone uses, e.g.
/// `{ColorZone.primary: 'crimson', ColorZone.secondary: 'onyx'}`. Zones left
/// out keep their key colours.
typedef ColorRecipe = Map<ColorZone, String>;

/// key colour → replacement colour (both 0xRRGGBB) for [recipe]. Unknown
/// palette names are skipped, so a typo shows the key colour, not a crash.
Map<int, int> swapTableFor(ColorRecipe recipe) {
  final table = <int, int>{};
  recipe.forEach((zone, name) {
    final ramp = palettesFor(zone)[name];
    final keys = kKeyRamps[zone]!;
    if (ramp == null) return;
    for (var i = 0; i < keys.length && i < ramp.length; i++) {
      if (keys[i] != ramp[i]) table[keys[i]] = ramp[i];
    }
  });
  return table;
}

/// A stable cache key for [recipe] (zone order doesn't matter).
String recipeKey(ColorRecipe recipe) {
  final parts = [for (final e in recipe.entries) '${e.key.name}=${e.value}']
    ..sort();
  return parts.join(',');
}

/// Swaps colours in place in straight (non-premultiplied) RGBA8888 [rgba].
/// Fully transparent pixels are skipped; alpha is kept.
void recolorRgba(Uint8List rgba, Map<int, int> table) {
  if (table.isEmpty) return;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] == 0) continue;
    final rgb = (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
    final to = table[rgb];
    if (to == null) continue;
    rgba[i] = (to >> 16) & 0xff;
    rgba[i + 1] = (to >> 8) & 0xff;
    rgba[i + 2] = to & 0xff;
  }
}
