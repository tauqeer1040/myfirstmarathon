import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The vertical ruler down the left edge of the stats screen, with the accent
/// bracket marking the current position in the programme.
class RulerAxis extends StatelessWidget {
  const RulerAxis({
    required this.fraction,
    this.bracket = const [0.02, 0.18],
    this.color = AppPalette.ink,
    this.bracketColor = AppPalette.cobaltAccent,
    super.key,
  });

  /// 0..1 position of the current week down the ruler.
  final double fraction;

  /// Span of the bracket, as fractions of total height.
  final List<double> bracket;
  final Color color;
  final Color bracketColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      child: CustomPaint(
        painter: _RulerPainter(
          fraction: fraction.clamp(0.0, 1.0),
          bracket: bracket,
          color: color,
          bracketColor: bracketColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.fraction,
    required this.bracket,
    required this.color,
    required this.bracketColor,
  });

  final double fraction;
  final List<double> bracket;
  final Color color;
  final Color bracketColor;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * 0.42;
    final top = size.height * 0.02;
    final bottom = size.height * 0.98;

    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.45),
    );

    // Ticks: long every 5th, short between.
    const total = 41;
    final p = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < total; i++) {
      final t = i / (total - 1);
      final y = top + (bottom - top) * t;
      final major = i % 5 == 0;
      final len = major ? 11.0 : 5.5;
      final inBracket = t >= bracket.first && t <= bracket.last;
      p.color = (inBracket ? bracketColor : color)
          .withValues(alpha: inBracket ? 1.0 : (major ? 0.55 : 0.30));
      canvas.drawLine(Offset(x + 1.5, y), Offset(x + 1.5 + len, y), p);
    }

    // Bracket: a squared-off span sitting on the ruler, filled where the
    // programme currently sits.
    final by0 = top + (bottom - top) * bracket.first;
    final by1 = top + (bottom - top) * bracket.last;
    final bx = x - 5;
    final bw = 3.2;
    canvas.drawRect(
      Rect.fromLTWH(bx, by0, bw, by1 - by0),
      Paint()..color = bracketColor.withValues(alpha: 0.28),
    );
    canvas.drawRect(
      Rect.fromLTWH(bx, top + (bottom - top) * fraction, bw, 4.5),
      Paint()..color = bracketColor,
    );
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.fraction != fraction;
}

/// Shared sine geometry for the squiggle timer and its indeterminate sibling.
class Squiggle {
  /// Samples a wavy path across [width], with [amp] of vertical displacement.
  static Path path({
    required double width,
    required double height,
    required double y,
    required double amplitude,
    required double wavelength,
    required double phase,
    double? startX,
    double? endX,
  }) {
    final p = Path();
    final x0 = startX ?? 0.0;
    final x1 = endX ?? width;
    const step = 2.0;
    for (var x = x0; x <= x1; x += step) {
      final dy = math.sin((x / wavelength + phase) * 2 * math.pi) * amplitude;
      if (x == x0) {
        p.moveTo(x, y + dy);
      } else {
        p.lineTo(x, y + dy);
      }
    }
    return p;
  }
}
