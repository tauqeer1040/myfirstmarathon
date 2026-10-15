import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// An aurora borealis painted behind the app.
///
/// Rather than dropping a stock green aurora in — which would erase the red /
/// cobalt split the whole design rests on — the ribbons are tinted to whichever
/// palette is active: amber and salmon over the ember field, cyan and teal over
/// cobalt. The *motion* is the aurora's; the colour stays ours.
///
/// Each ribbon is a band bounded by two wavy edges, filled with a vertical
/// gradient that fades to nothing at both edges. That fade is what separates an
/// aurora from a ribbon: light with no hard boundary. Overlapping a few of them
/// at low alpha fakes the bloom far more cheaply than a real blur filter, which
/// would cost a full-screen offscreen pass every frame.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    required this.palette,
    required this.child,
    this.intensity = 1.0,
    super.key,
  });

  final AppPalette palette;
  final Widget child;

  /// Scales the ribbons' opacity. The run screen drops this so the map stays
  /// calm and legible.
  final double intensity;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  // Slow enough that you notice it only if you're already looking — the brief
  // for the whole app is "calm", and motion that announces itself fights that.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  );

  @override
  void initState() {
    super.initState();
    // Starting the animation is left to didChangeDependencies — reading an
    // inherited widget like MediaQuery from initState is not allowed.
    _c.value = 0.18;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      // Honour the OS "reduce motion" setting by parking on a still frame
      // instead of animating. The aurora becomes a static composition.
      _c.stop();
      _c.value = 0.18;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // A solid base stays underneath so the field is never transparent and the
      // white type always has a guaranteed contrast floor.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(widget.palette.surface, Colors.white, 0.04)!,
            widget.palette.surface,
            Color.lerp(widget.palette.surface, Colors.black, 0.10)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _AuroraPainter(
                    t: _c.value,
                    palette: widget.palette,
                    intensity: widget.intensity,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t, required this.palette, required this.intensity});

  final double t;
  final AppPalette palette;
  final double intensity;

  /// Ribbons live in the upper two-thirds; the bottom stays quieter so the stat
  /// row and the primary button sit on calm ground.
  static const List<_Ribbon> _ribbons = [
    _Ribbon(base: 0.10, amp: 0.075, freq: 0.9, speed: 1.00, thickness: 0.30, alpha: 0.30),
    _Ribbon(base: 0.30, amp: 0.095, freq: 0.65, speed: -0.74, thickness: 0.26, alpha: 0.24),
    _Ribbon(base: 0.52, amp: 0.070, freq: 1.15, speed: 0.56, thickness: 0.22, alpha: 0.19),
    _Ribbon(base: 0.68, amp: 0.055, freq: 1.45, speed: -0.40, thickness: 0.18, alpha: 0.13),
  ];

  List<Color> get _hue {
    switch (palette.kind) {
      case PaletteKind.ember:
        // Hot light over a dark red field: amber, coral, blush.
        return const [
          Color(0xFFFFC46B),
          Color(0xFFFF8F6B),
          Color(0xFFFFB9A3),
          Color(0xFFFFD9A0),
        ];
      case PaletteKind.cobalt:
        // Cold light over a deep blue field: cyan, teal, periwinkle.
        return const [
          Color(0xFF7FE3FF),
          Color(0xFF6FD1C8),
          Color(0xFFA9A6FF),
          Color(0xFF8FC4FF),
        ];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final colors = _hue;
    final phase = t * 2 * math.pi;

    for (var i = 0; i < _ribbons.length; i++) {
      final r = _ribbons[i];
      final colour = colors[i % colors.length].withValues(
        alpha: r.alpha * intensity,
      );
      if (colour.a <= 0.001) continue;

      final path = _band(size, r, phase * r.speed + i * 1.7);

      final top = (r.base - r.amp) * size.height;
      final bottom = (r.base + r.amp + r.thickness) * size.height;

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colour.withValues(alpha: 0),
              colour,
              colour.withValues(alpha: colour.a * 0.55),
              colour.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.34, 0.62, 1.0],
          ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
      );

      // The bright filament along the upper edge — the part of a real aurora
      // that reads as a distinct line rather than a wash.
      final crest = _crest(size, r, phase * r.speed + i * 1.7);
      canvas.drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = colors[i % colors.length]
              .withValues(alpha: 0.30 * intensity),
      );
    }
  }

  /// Three summed harmonics. One sine reads as a mechanical wave; three
  /// incommensurate ones read as something drifting in air.
  double _edge(Size size, _Ribbon r, double phase, double x) {
    final u = x / size.width;
    return r.base
        + math.sin(u * r.freq * 2 * math.pi + phase) * r.amp
        + math.sin(u * r.freq * 2.3 * 2 * math.pi + phase * 1.7) * r.amp * 0.45
        + math.sin(u * r.freq * 0.6 * 2 * math.pi - phase * 0.8) * r.amp * 0.70;
  }

  Path _band(Size size, _Ribbon r, double phase) {
    const step = 6.0;
    final top = Path();
    final bottom = Path();
    var first = true;

    for (var x = 0.0; x <= size.width + step; x += step) {
      final y = _edge(size, r, phase, x) * size.height;
      if (first) {
        top.moveTo(x, y);
        bottom.moveTo(x, y);
        first = false;
      } else {
        top.lineTo(x, y);
        bottom.lineTo(x, y);
      }
    }

    // Close the shape by walking the lower edge back the other way.
    for (var x = size.width + step; x >= 0; x -= step) {
      final y = _edge(size, r, phase, x) * size.height + r.thickness * size.height;
      bottom.lineTo(x, y);
    }

    return Path()
      ..addPath(top, Offset.zero)
      ..addPath(bottom, Offset.zero)
      ..close();
  }

  Path _crest(Size size, _Ribbon r, double phase) {
    const step = 6.0;
    final p = Path();
    var first = true;
    for (var x = 0.0; x <= size.width + step; x += step) {
      final y = _edge(size, r, phase, x) * size.height + r.thickness * size.height * 0.34;
      if (first) {
        p.moveTo(x, y);
        first = false;
      } else {
        p.lineTo(x, y);
      }
    }
    return p;
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.palette != palette || old.intensity != intensity;
}

class _Ribbon {
  const _Ribbon({
    required this.base,
    required this.amp,
    required this.freq,
    required this.speed,
    required this.thickness,
    required this.alpha,
  });

  /// Vertical centre of the band, as a fraction of height.
  final double base;
  final double amp;
  final double freq;
  final double speed;

  /// Band depth as a fraction of height.
  final double thickness;
  final double alpha;
}
