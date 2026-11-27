import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/sprite_palette.dart';
import '../core/sprite_sheet.dart';
import '../models/shop_item.dart';

/// A sprite ready to draw: its image, already recoloured, and its frames.
class LoadedSprite {
  const LoadedSprite(this.image, this.sheet);
  final ui.Image image;
  final SpriteSheet sheet;
}

/// Finds, recolours and caches item sprites.
///
/// Which file: the item's own `<id>.png` if it exists (hand-made art wins),
/// else its shared drawing `<spriteId>.png`. A `.json` beside the PNG (Aseprite
/// sprite-sheet export) adds frames, tags and the `head` slice.
///
/// Each item + colour recipe is decoded and recoloured once, then reused.
class SpriteLoader {
  SpriteLoader._();
  static final SpriteLoader instance = SpriteLoader._();

  AssetBundle _bundle = rootBundle;
  Future<Set<String>>? _manifest;
  final _pending = <String, Future<LoadedSprite?>>{};
  final _ready = <String, LoadedSprite?>{};

  /// Tests swap in a fake bundle; also clears the cache.
  @visibleForTesting
  void useBundle(AssetBundle bundle) {
    _bundle = bundle;
    _manifest = null;
    _pending.clear();
    _ready.clear();
  }

  static String keyFor(ShopItem item, ColorRecipe recipe) =>
      '${item.id}|${recipeKey(recipe)}';

  /// Whether [key] has finished loading (its value may still be null: no art).
  bool isSettled(String key) => _ready.containsKey(key);

  /// The sprite for [key] if it already finished loading, else null.
  LoadedSprite? peek(String key) => _ready[key];

  Future<Set<String>> _assets() => _manifest ??= () async {
        try {
          final m = await AssetManifest.loadFromAssetBundle(_bundle);
          return m.listAssets().toSet();
        } catch (_) {
          return <String>{};
        }
      }();

  /// The PNG to draw for [item], or null while it has no art.
  Future<String?> resolve(ShopItem item) async {
    final assets = await _assets();
    if (assets.contains(item.asset)) return item.asset;
    final shared = item.sharedAsset;
    if (shared != null && assets.contains(shared)) return shared;
    return null;
  }

  Future<LoadedSprite?> load(ShopItem item, ColorRecipe recipe) {
    final key = keyFor(item, recipe);
    return _pending[key] ??= _load(item, recipe).then((s) {
      _ready[key] = s;
      return s;
    });
  }

  Future<LoadedSprite?> _load(ShopItem item, ColorRecipe recipe) async {
    try {
      final path = await resolve(item);
      if (path == null) return null;
      final bytes = await _bundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      var image = (await codec.getNextFrame()).image;
      codec.dispose();

      final table = swapTableFor(recipe);
      if (table.isNotEmpty) {
        final data =
            await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        if (data != null) {
          final rgba = data.buffer.asUint8List();
          recolorRgba(rgba, table);
          final done = Completer<ui.Image>();
          ui.decodeImageFromPixels(rgba, image.width, image.height,
              ui.PixelFormat.rgba8888, done.complete);
          final recoloured = await done.future;
          image.dispose();
          image = recoloured;
        }
      }

      var sheet =
          SpriteSheet.single(image.width.toDouble(), image.height.toDouble());
      final jsonPath = '${path.substring(0, path.length - 4)}.json';
      if ((await _assets()).contains(jsonPath)) {
        try {
          final text = await _bundle.loadString(jsonPath);
          sheet = SpriteSheet.fromAseprite(
              jsonDecode(text) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Sprite sheet $jsonPath unreadable, using one frame: $e');
        }
      }
      return LoadedSprite(image, sheet);
    } catch (e) {
      debugPrint('Sprite for ${item.id} failed to load: $e');
      return null;
    }
  }
}

/// Draws one frame of an item's sprite, recoloured by [recipe], filling its
/// box with crisp (nearest-neighbour) pixels. Shows [fallback] when the item
/// has no art yet, and nothing while it loads.
class PixelSprite extends StatefulWidget {
  const PixelSprite({
    super.key,
    required this.item,
    this.recipe = const {},
    this.frameFor,
    this.offsetFor,
    this.fallback,
    this.onLoaded,
  });

  final ShopItem item;
  final ColorRecipe recipe;

  /// Picks the frame to draw from the sprite's sheet; default: its rest frame.
  final int Function(SpriteSheet sheet)? frameFor;

  /// Extra shift in sprite pixels for the chosen sheet (a one-frame head
  /// item following the head); default none.
  final Offset Function(SpriteSheet sheet)? offsetFor;
  final Widget? fallback;
  final ValueChanged<LoadedSprite?>? onLoaded;

  @override
  State<PixelSprite> createState() => _PixelSpriteState();
}

class _PixelSpriteState extends State<PixelSprite> {
  LoadedSprite? _sprite;
  bool _settled = false;

  String get _key => SpriteLoader.keyFor(widget.item, widget.recipe);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(PixelSprite old) {
    super.didUpdateWidget(old);
    if (SpriteLoader.keyFor(old.item, old.recipe) != _key) _start();
  }

  void _start() {
    final loader = SpriteLoader.instance;
    final key = _key;
    if (loader.isSettled(key)) {
      _sprite = loader.peek(key);
      _settled = true;
      return;
    }
    _sprite = null;
    _settled = false;
    loader.load(widget.item, widget.recipe).then((s) {
      if (!mounted || _key != key) return;
      setState(() {
        _sprite = s;
        _settled = true;
      });
      widget.onLoaded?.call(s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _sprite;
    if (s == null) {
      return _settled
          ? (widget.fallback ?? const SizedBox.shrink())
          : const SizedBox.shrink();
    }
    final frame = (widget.frameFor?.call(s.sheet) ?? s.sheet.restFrame)
        .clamp(0, s.sheet.frames.length - 1);
    return CustomPaint(
      painter: _FramePainter(
          s, frame, widget.offsetFor?.call(s.sheet) ?? Offset.zero),
      size: Size.infinite,
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.sprite, this.frame, this.offset);
  final LoadedSprite sprite;
  final int frame;
  final Offset offset;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = sprite.sheet;
    final f = sheet.frames[frame];
    final sx = size.width / sheet.width;
    final sy = size.height / sheet.height;
    final at = f.dst + offset;
    canvas.drawImageRect(
      sprite.image,
      f.src,
      Rect.fromLTWH(
          at.dx * sx, at.dy * sy, f.src.width * sx, f.src.height * sy),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.sprite != sprite || old.frame != frame || old.offset != offset;
}
