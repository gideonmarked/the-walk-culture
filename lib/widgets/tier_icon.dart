import 'package:flutter/material.dart';

/// Per-tier colours for the currency pebble icon (doc §5 ladder).
const Map<String, Color> kTierColors = {
  'Pebbles': Color(0xFF9E9E9E), // stone grey
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

/// A smooth pebble (rounded stone) tinted with the tier's colour. Drawn with a
/// CustomPainter so it can be recoloured per tier (emoji can't be tinted): grey
/// reads as a plain pebble at the base, the jewel colours as polished stones up
/// the ladder. A glossy highlight + soft outline give it a little dimension.
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
        painter: _PebblePainter(kTierColors[tier] ?? Colors.grey),
      ),
    );
  }
}

class _PebblePainter extends CustomPainter {
  _PebblePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Organic stone silhouette — a touch wider at the bottom so it sits like a
    // pebble rather than a coin. Centre biased slightly low.
    final cx = w * 0.5, cy = h * 0.53;
    final rx = w * 0.38, ry = h * 0.34;
    final body = Path()
      ..moveTo(cx, cy - ry)
      ..cubicTo(cx + rx * 0.92, cy - ry, cx + rx, cy - ry * 0.15,
          cx + rx, cy + ry * 0.28)
      ..cubicTo(cx + rx, cy + ry * 0.82, cx + rx * 0.58, cy + ry, cx, cy + ry)
      ..cubicTo(cx - rx * 0.58, cy + ry, cx - rx, cy + ry * 0.82,
          cx - rx, cy + ry * 0.28)
      ..cubicTo(cx - rx, cy - ry * 0.15, cx - rx * 0.92, cy - ry, cx, cy - ry)
      ..close();

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..isAntiAlias = true;

    canvas.drawPath(body, fill);

    // Glossy highlight, clipped to the stone so it never spills past the edge.
    canvas.save();
    canvas.clipPath(body);
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..isAntiAlias = true;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - rx * 0.28, cy - ry * 0.38),
        width: rx * 0.9,
        height: ry * 0.55,
      ),
      highlight,
    );
    canvas.restore();

    canvas.drawPath(body, stroke);
  }

  @override
  bool shouldRepaint(_PebblePainter old) => old.color != color;
}
