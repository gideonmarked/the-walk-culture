import 'dart:ui';

/// One frame of a sprite sheet: where it sits in the image ([src]) and where it
/// lands on its full canvas ([dst] — non-zero only for frames Aseprite trimmed).
class SheetFrame {
  const SheetFrame(this.src, this.dst, this.durationMs);
  final Rect src;
  final Offset dst;
  final int durationMs;
}

/// Frames, tags and the `head` anchor of a sprite, read from the JSON that
/// Aseprite's **Export Sprite Sheet** writes next to the PNG. A PNG with no
/// JSON is one frame the size of the image.
///
/// - Tags (`stand`, `walk`, `lying`…) name runs of frames, as in the
///   Aseprite timeline. See `lib/core/character_pose.dart` for the poses.
/// - The `head` slice marks where the head is on each frame. Only the body
///   needs it: head items (hair, hats, faces) are drawn once and moved by it.
class SpriteSheet {
  SpriteSheet({
    required this.width,
    required this.height,
    required this.frames,
    this.tags = const {},
    this.head = const [],
  });

  /// A plain image: one frame, no tags.
  factory SpriteSheet.single(double width, double height) => SpriteSheet(
        width: width,
        height: height,
        frames: [
          SheetFrame(Rect.fromLTWH(0, 0, width, height), Offset.zero, 100)
        ],
      );

  /// Parses Aseprite's JSON, in either its Array or Hash frame layout.
  factory SpriteSheet.fromAseprite(Map<String, dynamic> json) {
    final raw = json['frames'];
    final list = raw is List
        ? raw.cast<Map<String, dynamic>>()
        : (raw as Map<String, dynamic>)
            .values
            .cast<Map<String, dynamic>>()
            .toList();
    if (list.isEmpty) throw const FormatException('sprite sheet has no frames');

    Rect rect(Map<String, dynamic> m) => Rect.fromLTWH(
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['w'] as num).toDouble(),
        (m['h'] as num).toDouble());

    final frames = <SheetFrame>[];
    var width = 0.0, height = 0.0;
    for (final f in list) {
      final src = rect(f['frame'] as Map<String, dynamic>);
      final placed = f['spriteSourceSize'] as Map<String, dynamic>?;
      final size = f['sourceSize'] as Map<String, dynamic>?;
      width = (size?['w'] as num?)?.toDouble() ?? src.width;
      height = (size?['h'] as num?)?.toDouble() ?? src.height;
      frames.add(SheetFrame(
        src,
        placed == null ? Offset.zero : rect(placed).topLeft,
        (f['duration'] as num?)?.toInt() ?? 100,
      ));
    }

    final meta = (json['meta'] as Map<String, dynamic>?) ?? const {};
    final tags = <String, (int, int)>{};
    for (final t in (meta['frameTags'] as List?) ?? const []) {
      final m = t as Map<String, dynamic>;
      final from = (m['from'] as num).toInt();
      final to = (m['to'] as num).toInt();
      if (from >= 0 && to < frames.length && from <= to) {
        tags[(m['name'] as String).toLowerCase()] = (from, to);
      }
    }

    // A slice key holds from its frame until the next key.
    var head = <Offset?>[];
    for (final s in (meta['slices'] as List?) ?? const []) {
      final m = s as Map<String, dynamic>;
      if ((m['name'] as String?)?.toLowerCase() != 'head') continue;
      final keys = ((m['keys'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => (a['frame'] as num).compareTo(b['frame'] as num));
      head = List<Offset?>.filled(frames.length, null);
      Offset? current;
      var k = 0;
      for (var i = 0; i < frames.length; i++) {
        while (k < keys.length && (keys[k]['frame'] as num) <= i) {
          current = rect(keys[k]['bounds'] as Map<String, dynamic>).topLeft;
          k++;
        }
        head[i] = current;
      }
    }

    return SpriteSheet(
        width: width, height: height, frames: frames, tags: tags, head: head);
  }

  /// Size of one frame's full canvas (64×64 for worn items).
  final double width;
  final double height;
  final List<SheetFrame> frames;

  /// Tag name (lowercase) → first and last frame, inclusive.
  final Map<String, (int, int)> tags;

  /// Top-left of the `head` slice on each frame; empty when there is none.
  final List<Offset?> head;

  bool get animated => frames.length > 1;

  /// The frame [step] frames into [tag], looping; null when there's no such tag.
  int? frameIn(String tag, int step) {
    final t = tags[tag];
    if (t == null) return null;
    final len = t.$2 - t.$1 + 1;
    return t.$1 + step % len;
  }

  /// The frame to show at rest: the first `stand` frame (`idle` in older
  /// files), else frame 0.
  int get restFrame => tags['stand']?.$1 ?? tags['idle']?.$1 ?? 0;

  /// How far the head has moved on [frame] compared with the rest frame.
  Offset headOffset(int frame) {
    if (frame < 0 || frame >= head.length) return Offset.zero;
    final here = head[frame];
    final rest = head[restFrame];
    if (here == null || rest == null) return Offset.zero;
    return here - rest;
  }
}
