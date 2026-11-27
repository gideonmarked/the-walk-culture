import 'health.dart';

/// What the character's body is doing: which Aseprite tag on the body sheet
/// plays, how fast, and whether worn items show.
class CharacterPose {
  const CharacterPose(this.tag, {this.speed = 1.0, this.baseOnly = false});

  /// The body sheet's tag (lowercase), e.g. `walk`. A body without this tag
  /// shows its standing frame instead, clothes and all.
  final String tag;

  /// Playback speed: 2.0 plays every frame in half its Aseprite duration.
  final double speed;

  /// A downed pose (lying, crawling, hunched) is drawn as the bare body: worn
  /// items are hidden because they're drawn for the upright anchors. Pets
  /// still show.
  final bool baseOnly;

  /// Standing still, for the customiser.
  static const stand = CharacterPose('stand');
}

/// One pose per health level, worst → best (see [kHealthLevels]). The upright
/// levels share the `walk` frames, so clothing is drawn once; they differ only
/// in pace.
const List<CharacterPose> kHealthPoses = [
  CharacterPose('lying', speed: 0.6, baseOnly: true), // Drained
  CharacterPose('crawl', speed: 0.7, baseOnly: true), // Worn
  CharacterPose('hunched', speed: 0.8, baseOnly: true), // Weary
  CharacterPose('walk', speed: 1.0), // Steady
  CharacterPose('walk', speed: 1.25), // Vigorous
  CharacterPose('walk', speed: 1.5), // Radiant
  CharacterPose('walk', speed: 1.8), // Aura
];

CharacterPose poseForHealth(int level) => kHealthPoses[clampHealthLevel(level)];
