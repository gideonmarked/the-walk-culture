import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:step_quest/core/sprite_palette.dart';
import 'package:step_quest/core/sprite_sheet.dart';
import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/models/shop_item.dart';
import 'package:step_quest/widgets/pixel_sprite.dart';

/// Serves a handful of in-memory files, plus the asset manifest listing them.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);
  final Map<String, ByteData> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final k in files.keys)
          k: [
            {'asset': k}
          ],
      })!;
    }
    final f = files[key];
    if (f == null) throw StateError('missing $key');
    return f;
  }
}

ByteData _bytes(String s) => ByteData.sublistView(utf8.encode(s));

Future<ByteData> _png(int w, int h, List<int> argb) async {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < argb.length; i++) {
    rgba[i * 4] = (argb[i] >> 16) & 0xff;
    rgba[i * 4 + 1] = (argb[i] >> 8) & 0xff;
    rgba[i * 4 + 2] = argb[i] & 0xff;
    rgba[i * 4 + 3] = (argb[i] >> 24) & 0xff;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
  final img = await done.future;
  return (await img.toByteData(format: ui.ImageByteFormat.png))!;
}

int _rgbAt(Uint8List rgba, int i) =>
    (rgba[i * 4] << 16) | (rgba[i * 4 + 1] << 8) | rgba[i * 4 + 2];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('palette swap', () {
    test('key shades map to the same shade of the chosen palette', () {
      final table = swapTableFor({ColorZone.primary: 'emerald'});
      final keys = kKeyRamps[ColorZone.primary]!;
      final emerald = kGarmentPalettes['emerald']!;
      for (var i = 0; i < 3; i++) {
        expect(table[keys[i]], emerald[i]);
      }
      expect(table.length, 3); // nothing outside the zone
    });

    test('outline, untouched zones, transparent pixels and alpha are kept', () {
      final key = kKeyRamps[ColorZone.primary]![1];
      final hair = kKeyRamps[ColorZone.hair]![0];
      final rgba = Uint8List.fromList([
        (key >> 16) & 0xff, (key >> 8) & 0xff, key & 0xff, 255, // primary mid
        0, 0, 1, 255, // outline
        (hair >> 16) & 0xff, (hair >> 8) & 0xff, hair & 0xff, 255, // hair
        (key >> 16) & 0xff, (key >> 8) & 0xff, key & 0xff, 0, // invisible
      ]);
      recolorRgba(rgba, swapTableFor({ColorZone.primary: 'azure'}));
      expect(_rgbAt(rgba, 0), kGarmentPalettes['azure']![1]);
      expect(_rgbAt(rgba, 1), 0x000001);
      expect(_rgbAt(rgba, 2), hair);
      expect(_rgbAt(rgba, 3), key); // skipped: alpha 0
      expect(rgba[3], 255);
    });

    test('an unknown palette name leaves the key colours alone', () {
      expect(swapTableFor({ColorZone.primary: 'plaid'}), isEmpty);
    });

    test('the key ramps match art/palettes/walk_key.gpl exactly', () {
      final lines = File('art/palettes/walk_key.gpl').readAsLinesSync();
      int colour(String label) {
        final l = lines.firstWhere((l) => l.endsWith(label));
        final n =
            l.trim().split(RegExp(r'\s+')).take(3).map(int.parse).toList();
        return (n[0] << 16) | (n[1] << 8) | n[2];
      }

      const names = {
        ColorZone.skin: 'Skin',
        ColorZone.hair: 'Hair',
        ColorZone.primary: 'Primary',
        ColorZone.secondary: 'Secondary',
        ColorZone.accent: 'Accent',
      };
      names.forEach((zone, name) {
        expect(
            kKeyRamps[zone],
            [
              colour('$name dark'),
              colour('$name mid'),
              colour('$name light'),
            ],
            reason: name);
      });
    });

    test('every key colour is unique, so no pixel is ambiguous', () {
      final all = [for (final r in kKeyRamps.values) ...r, 0x000001];
      expect(all.toSet().length, all.length);
    });

    test('every palette has three shades', () {
      for (final zone in ColorZone.values) {
        palettesFor(zone).forEach((name, ramp) {
          expect(ramp.length, 3, reason: '${zone.name}/$name');
        });
      }
    });
  });

  group('catalog recipes', () {
    test('each colour variant shares one drawing and names a real palette', () {
      final gen = kShopCatalog.where((i) => i.id.startsWith('gen_')).toList();
      expect(gen, hasLength(500));
      for (final item in gen) {
        final colour = item.colors[ColorZone.primary];
        expect(kGarmentPalettes, contains(colour), reason: item.id);
        expect(item.id, '${item.spriteId}_$colour');
      }
      expect(gen.map((i) => i.spriteId).toSet(), hasLength(50));
    });

    test('the five skin tones share one body', () {
      final bases = kShopCatalog.where((i) => i.slot == ItemSlot.base);
      for (final b in bases) {
        expect(b.sharedAsset, 'assets/character/base/base.png');
        expect(kSkinPalettes, contains(b.colors[ColorZone.skin]), reason: b.id);
      }
    });
  });

  group('Aseprite sheet', () {
    // Array export: 3 frames, idle = 0, walk = 1–2, a head slice that drops
    // 1px on frame 2, and a trimmed frame 1.
    final json = {
      'frames': [
        {
          'frame': {'x': 0, 'y': 0, 'w': 64, 'h': 64},
          'spriteSourceSize': {'x': 0, 'y': 0, 'w': 64, 'h': 64},
          'sourceSize': {'w': 64, 'h': 64},
          'duration': 200,
        },
        {
          'frame': {'x': 64, 'y': 0, 'w': 32, 'h': 60},
          'spriteSourceSize': {'x': 16, 'y': 4, 'w': 32, 'h': 60},
          'sourceSize': {'w': 64, 'h': 64},
          'duration': 120,
        },
        {
          'frame': {'x': 96, 'y': 0, 'w': 64, 'h': 64},
          'sourceSize': {'w': 64, 'h': 64},
        },
      ],
      'meta': {
        'frameTags': [
          {'name': 'idle', 'from': 0, 'to': 0},
          {'name': 'Walk', 'from': 1, 'to': 2},
        ],
        'slices': [
          {
            'name': 'head',
            'keys': [
              {
                'frame': 2,
                'bounds': {'x': 20, 'y': 4, 'w': 24, 'h': 20}
              },
              {
                'frame': 0,
                'bounds': {'x': 20, 'y': 3, 'w': 24, 'h': 20}
              },
            ],
          },
        ],
      },
    };

    test('reads frames, trim offsets, durations and tags', () {
      final s = SpriteSheet.fromAseprite(json);
      expect(s.frames, hasLength(3));
      expect((s.width, s.height), (64.0, 64.0));
      expect(s.frames[1].dst, const Offset(16, 4));
      expect(s.frames[1].durationMs, 120);
      expect(s.frames[2].durationMs, 100); // Aseprite's default
      expect(s.tags['walk'], (1, 2)); // tag names are case-insensitive
      expect(s.restFrame, 0);
      expect([0, 1, 2, 3].map((i) => s.frameIn('walk', i)), [1, 2, 1, 2]);
      expect(s.frameIn('run', 0), isNull);
    });

    test('head offset follows slice keys, holding between them', () {
      final s = SpriteSheet.fromAseprite(json);
      expect(s.headOffset(0), Offset.zero);
      expect(s.headOffset(1), Offset.zero); // key from frame 0 still holds
      expect(s.headOffset(2), const Offset(0, 1));
    });

    test('reads the Hash layout the existing tones.json uses', () {
      final file = File('assets/character/base/tones.json').readAsStringSync();
      final s =
          SpriteSheet.fromAseprite(jsonDecode(file) as Map<String, dynamic>);
      expect(s.frames, hasLength(5));
      expect(s.frames[1].src.left, 32);
      expect(s.frames[0].dst, const Offset(16, 0));
      expect(s.head, isEmpty);
      expect(s.headOffset(0), Offset.zero);
    });
  });

  group('SpriteLoader', () {
    const tee = ShopItem(
      id: 'gen_top_tee_emerald',
      name: 'Emerald Tee',
      emoji: '👕',
      slot: ItemSlot.top,
      rarity: Rarity.common,
      priceTier: 'Pebbles',
      priceAmount: 1,
      spriteId: 'gen_top_tee',
      colors: {ColorZone.primary: 'emerald'},
    );

    tearDown(() => SpriteLoader.instance.useBundle(rootBundle));

    test('loads the shared drawing and recolours it', () async {
      final key = kKeyRamps[ColorZone.primary]!;
      final png = await _png(3, 1, [0xff000000 | key[0], 0xff000001, 0]);
      SpriteLoader.instance.useBundle(_FakeBundle({
        'assets/character/tops/gen_top_tee.png': png,
      }));

      final sprite = await SpriteLoader.instance.load(tee, tee.colors);
      expect(sprite, isNotNull);
      expect(sprite!.sheet.frames, hasLength(1));
      final data = await sprite.image
          .toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final rgba = data!.buffer.asUint8List();
      expect(_rgbAt(rgba, 0), kGarmentPalettes['emerald']![0]);
      expect(_rgbAt(rgba, 1), 0x000001); // outline untouched
      expect(rgba[11], 0); // transparent stays transparent
    });

    test('an item with its own file uses it over the shared drawing', () async {
      final own = await _png(1, 1, [0xff123456]);
      final shared = await _png(2, 2, [0, 0, 0, 0]);
      SpriteLoader.instance.useBundle(_FakeBundle({
        'assets/character/tops/gen_top_tee_emerald.png': own,
        'assets/character/tops/gen_top_tee.png': shared,
      }));
      final sprite = await SpriteLoader.instance.load(tee, const {});
      expect(sprite!.image.width, 1);
    });

    test('reads frames from a JSON beside the PNG', () async {
      final png = await _png(4, 2, List.filled(8, 0xff000001));
      SpriteLoader.instance.useBundle(_FakeBundle({
        'assets/character/tops/gen_top_tee.png': png,
        'assets/character/tops/gen_top_tee.json': _bytes(jsonEncode({
          'frames': [
            {
              'frame': {'x': 0, 'y': 0, 'w': 2, 'h': 2}
            },
            {
              'frame': {'x': 2, 'y': 0, 'w': 2, 'h': 2}
            },
          ],
          'meta': {
            'frameTags': [
              {'name': 'walk', 'from': 0, 'to': 1}
            ]
          },
        })),
      }));
      final sprite = await SpriteLoader.instance.load(tee, tee.colors);
      expect(sprite!.sheet.frames, hasLength(2));
      expect(sprite.sheet.tags['walk'], (0, 1));
    });

    test('no art at all resolves to null, not an error', () async {
      SpriteLoader.instance.useBundle(_FakeBundle({}));
      expect(await SpriteLoader.instance.load(tee, tee.colors), isNull);
    });
  });
}
