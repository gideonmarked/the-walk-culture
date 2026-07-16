import 'package:flutter/material.dart';

/// Per-tier colours for the currency footprint icon (doc §5 ladder).
const Map<String, Color> kTierColors = {
  'Steps': Color(0xFFFFFFFF), // white
  'Copper': Color(0xFFB87333),
  'Silver': Color(0xFFC0C0C0),
  'Gold': Color(0xFFFFD700),
  'Titanium': Color(0xFF9AA0A6),
  'Platinum': Color(0xFFE5E4E2),
  'Tanzanite': Color(0xFF6A5ACD),
  'Emerald': Color(0xFF50C878),
  'Ruby': Color(0xFFE0115F),
  'Diamond': Color(0xFFB9F2FF),
};

/// A footprint (sole + toes) tinted with the tier's colour. Drawn with a
/// CustomPainter so it can be recoloured per tier (emoji can't be tinted). A
/// faint dark outline keeps the white "Steps" print legible on light surfaces.
class TierIcon extends StatelessWidget {
  const TierIcon(this.tier, {super.key, this.size = 28});

  final String tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FootprintPainter(kTierColors[tier] ?? Colors.grey),
      ),
    );
  }
}

class _FootprintPainter extends CustomPainter {
  _FootprintPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..isAntiAlias = true;

    // Ball of the foot (main pad).
    final ball = Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.44, h * 0.40);
    // Heel.
    final heel = Rect.fromLTWH(w * 0.37, h * 0.66, w * 0.30, h * 0.26);
    canvas.drawOval(ball, fill);
    canvas.drawOval(heel, fill);
    canvas.drawOval(ball, stroke);
    canvas.drawOval(heel, stroke);

    // Toes arcing above the ball.
    final toeR = w * 0.072;
    const toes = [
      Offset(0.35, 0.26),
      Offset(0.47, 0.19),
      Offset(0.59, 0.19),
      Offset(0.70, 0.26),
    ];
    for (final t in toes) {
      final c = Offset(t.dx * w, t.dy * h);
      canvas.drawCircle(c, toeR, fill);
      canvas.drawCircle(c, toeR, stroke);
    }
  }

  @override
  bool shouldRepaint(_FootprintPainter old) => old.color != color;
}
