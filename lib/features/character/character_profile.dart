import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sprite_palette.dart';
import '../../core/sprite_sheet.dart';
import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';
import '../../widgets/pixel_sprite.dart';

/// Where a slot's emoji sits inside its own frame while it has no real sprite
/// yet (so the composite still reads sensibly). Real art ignores this and uses
/// [ShopItem.x]/[y]. Alignments are frame-relative, so they survive a canvas
/// resize.
const Map<ItemSlot, Alignment> _fallbackAlign = {
  ItemSlot.base: Alignment.center,
  ItemSlot.bottom: Alignment(0, 0.35),
  ItemSlot.top: Alignment(0, -0.05),
  ItemSlot.shoes: Alignment(0, 0.9),
  ItemSlot.face: Alignment(0, -0.4),
  ItemSlot.hair: Alignment(0, -0.72),
  ItemSlot.hat: Alignment(0, -1.0),
  ItemSlot.accessory: Alignment(0.55, -0.15),
  ItemSlot.pet: Alignment(0.8, 0.72), // beside the feet, on the ground line
};

/// Composites the equipped character sprites (back→front) on the [kStage]
/// canvas. The [kCanvas] character box sits centred inside the stage; pets and
/// floor props live in the room around it. Placement is data-driven and not
/// user-movable.
///
/// [size] is a *maximum* — the stage is drawn at the largest whole-number
/// upscale that fits it and the incoming constraints, so nearest-neighbour
/// pixels stay perfectly square (96 → 192 → 288).
class CharacterProfile extends ConsumerWidget {
  const CharacterProfile({super.key, this.size = 288, this.pose = 'idle'});

  final double size;

  /// The body's Aseprite tag to play: `idle` or `walk`. Falls back to the
  /// body's rest frame when its sheet has no such tag (or no frames yet).
  final String pose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var budget = size;
        if (constraints.hasBoundedWidth) {
          budget = math.min(budget, constraints.maxWidth);
        }
        if (constraints.hasBoundedHeight) {
          budget = math.min(budget, constraints.maxHeight);
        }
        final scale = math.max(1, (budget / kStage).floor()).toDouble();
        return _Stage(scale: scale, pose: pose);
      },
    );
  }
}

class _Stage extends ConsumerStatefulWidget {
  const _Stage({required this.scale, required this.pose});

  final double scale;
  final String pose;

  @override
  ConsumerState<_Stage> createState() => _StageState();
}

class _StageState extends ConsumerState<_Stage>
    with SingleTickerProviderStateMixin {
  /// The body's frames; every other layer keys its frame off this.
  SpriteSheet? _body;
  Ticker? _ticker;
  int _step = 0;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Stage old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _onBody(LoadedSprite? s) {
    if (!mounted || s?.sheet == _body) return;
    setState(() => _body = s?.sheet);
    _syncTicker();
  }

  /// The run of frames the current pose plays, with each frame's duration.
  List<int> get _durations {
    final body = _body;
    final tag = body?.tags[widget.pose];
    if (body == null || tag == null) return const [];
    return [
      for (var i = tag.$1; i <= tag.$2; i++)
        math.max(16, body.frames[i].durationMs)
    ];
  }

  /// Runs the clock only while there is something to animate.
  void _syncTicker() {
    final durations = _durations;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final run = durations.length > 1 && !reduceMotion;
    if (!run) {
      _ticker?.stop();
      _step = 0; // every caller rebuilds next, so no setState here
      return;
    }
    _ticker ??= createTicker((elapsed) {
      final d = _durations;
      if (d.length < 2) return;
      final total = d.fold<int>(0, (a, b) => a + b);
      var t = elapsed.inMilliseconds % total;
      var i = 0;
      while (t >= d[i]) {
        t -= d[i];
        i++;
      }
      if (i != _step) setState(() => _step = i);
    });
    if (!_ticker!.isActive) _ticker!.start();
  }

  @override
  Widget build(BuildContext context) {
    final equipped = ref.watch(playerControllerProvider).equipped;
    final scale = widget.scale;
    final size = kStage * scale;

    ShopItem? itemFor(ItemSlot slot) {
      final id = equipped[slot];
      if (id == null) return null;
      for (final item in kShopCatalog) {
        if (item.id == id) return item;
      }
      return null;
    }

    final base = itemFor(ItemSlot.base);
    // Clothing that shows skin (gloves, a face) takes the body's tone.
    final skin = base?.colors[ColorZone.skin];
    final body = _body;
    final bodyFrame =
        body == null ? 0 : (body.frameIn(widget.pose, _step) ?? body.restFrame);

    int frameFor(SpriteSheet sheet) {
      final tagged = sheet.frameIn(widget.pose, _step);
      if (tagged != null) return tagged;
      // Untagged but laid out like the body: follow it frame for frame.
      if (body != null && sheet.frames.length == body.frames.length) {
        return bodyFrame;
      }
      return sheet.restFrame;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          if (base == null)
            Positioned(
              left: kCharOriginX * scale,
              top: kCharOriginY * scale,
              width: kCanvas * scale,
              height: kCanvas * scale,
              child: Center(
                child: Text('🧍',
                    style: TextStyle(fontSize: kCanvas * scale * 0.55)),
              ),
            ),
          for (final slot in kCharacterSlots)
            if (itemFor(slot) case final item?)
              _Layer(
                item: item,
                scale: scale,
                recipe: {
                  if (skin != null) ColorZone.skin: skin,
                  ...item.colors,
                },
                frameFor: frameFor,
                offsetFor: (sheet) =>
                    item.followsHead && body != null && sheet.frames.length == 1
                        ? body.headOffset(bodyFrame)
                        : Offset.zero,
                onLoaded: slot == ItemSlot.base ? _onBody : null,
              ),
        ],
      ),
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({
    required this.item,
    required this.scale,
    required this.recipe,
    required this.frameFor,
    required this.offsetFor,
    this.onLoaded,
  });

  final ShopItem item;
  final double scale;
  final ColorRecipe recipe;
  final int Function(SpriteSheet sheet) frameFor;
  final Offset Function(SpriteSheet sheet) offsetFor;
  final ValueChanged<LoadedSprite?>? onLoaded;

  @override
  Widget build(BuildContext context) {
    final w = item.frameW * scale;
    final h = item.frameH * scale;
    // A tight prop fills its own little frame; a full frame is mostly empty, so
    // the emoji is drawn small and parked where that slot belongs.
    final emojiSize = math.min(w, h) * (item.isTight ? 0.9 : 0.27);

    return Positioned(
      left: item.stageX * scale,
      top: item.stageY * scale,
      width: w,
      height: h,
      child: PixelSprite(
        item: item,
        recipe: recipe,
        frameFor: frameFor,
        // A one-frame head item rides the head; anything with its own frames
        // was drawn in place for each one.
        offsetFor: offsetFor,
        onLoaded: onLoaded,
        fallback: Align(
          alignment: item.isTight
              ? Alignment.center
              : (_fallbackAlign[item.slot] ?? Alignment.center),
          child: Text(item.emoji, style: TextStyle(fontSize: emojiSize)),
        ),
      ),
    );
  }
}
