import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:step_quest/core/character_pose.dart';
import 'package:step_quest/core/health.dart';
import 'package:step_quest/core/sprite_sheet.dart';

void main() {
  test('every health level has a pose', () {
    expect(kHealthPoses, hasLength(kHealthLevels.length));
  });

  test('the bottom three levels are downed poses shown as the bare body', () {
    expect([for (final p in kHealthPoses.take(3)) p.tag],
        ['lying', 'crawl', 'hunched']);
    expect(kHealthPoses.take(3).every((p) => p.baseOnly), isTrue);
  });

  test('upright levels share the walk frames and speed up as health climbs',
      () {
    final upright = kHealthPoses.skip(3).toList();
    expect(upright.every((p) => p.tag == 'walk' && !p.baseOnly), isTrue);
    for (var i = 1; i < upright.length; i++) {
      expect(upright[i].speed, greaterThan(upright[i - 1].speed));
    }
  });

  test('out-of-range levels clamp instead of throwing', () {
    expect(poseForHealth(-3).tag, 'lying');
    expect(poseForHealth(99), kHealthPoses.last);
  });

  test('the standing frame comes from the stand tag, then idle, then 0', () {
    SpriteSheet sheet(Map<String, (int, int)> tags) => SpriteSheet(
          width: 64,
          height: 64,
          frames: [
            for (var i = 0; i < 6; i++)
              const SheetFrame(Rect.fromLTWH(0, 0, 64, 64), Offset.zero, 100)
          ],
          tags: tags,
        );
    expect(sheet({'walk': (0, 3), 'stand': (4, 4)}).restFrame, 4);
    expect(sheet({'idle': (5, 5)}).restFrame, 5);
    expect(sheet({}).restFrame, 0);
  });
}
