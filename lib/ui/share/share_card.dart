import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';

/// A social-ready 4:5 activity card, drawn at 1080×1350 and scaled down for
/// preview — the aspect every major feed renders without cropping.
///
/// The route is the hero: the runner's real GPS trace, projected to preserve
/// its aspect ratio and centred, the way a printed route card would set it.
/// Everything else is typography on the same red field as the app, so a shared
/// image is instantly recognisable as *yours* from this program.
class ShareCard extends StatelessWidget {
  const ShareCard({
    required this.record,
    this.width = 1080,
    super.key,
  });

  final RunRecord record;

  /// Logical width; height follows the 4:5 ratio.
  final double width;

  static const double aspect = 4 / 5;

  double get height => width * aspect;

  @override
  Widget build(BuildContext context) {
    final s = width / 1080; // design was authored at 1080pt

    final pace = Fmt.pace(record.paceSecPerKm) ?? '—';
    final palette = AppPalette.ember;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFC0342A),
              Color(0xFFB22A1F),
              Color(0xFF8E2118),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Soft bloom behind the route.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.25),
                    radius: 0.85,
                    colors: [
                      palette.accent.withValues(alpha: 0.28),
                      palette.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 72 * s, vertical: 66 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _wordmark(s),
                  const Spacer(flex: 2),

                  // ── Route ──────────────────────────────────────────────
                  Expanded(
                    flex: 42,
                    child: CustomPaint(
                      painter: _RoutePainter(
                        route: record.route,
                        strokeWidth: 9 * s,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── The number ─────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        record.distanceKm.toStringAsFixed(2),
                        style: AppType.hero(context, size: 190 * s),
                      ),
                      SizedBox(width: 18 * s),
                      Padding(
                        padding: EdgeInsets.only(bottom: 22 * s),
                        child: Text('KM', style: AppType.heroUnit(size: 62 * s)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6 * s),
                  Text(
                    record.title.toUpperCase(),
                    style: AppType.eyebrow(size: 34 * s).copyWith(letterSpacing: 5 * s),
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    Fmt.dateTime(record.startedAt),
                    style: AppType.label(
                      size: 26 * s,
                      color: AppPalette.ink.withValues(alpha: 0.7),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Stats strip ────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 26 * s, horizontal: 8 * s),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(34 * s),
                    ),
                    child: Row(
                      children: [
                        _cell(s, Fmt.clock(record.elapsed), 'TIME'),
                        _divider(s),
                        _cell(s, pace, 'AVG PACE'),
                        _divider(s),
                        _cell(s, '${record.calories}', 'CALORIES'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wordmark(double s) => Row(
        children: [
          Text(
            'ZERO TO 5K',
            style: AppType.eyebrow(size: 26 * s).copyWith(letterSpacing: 4.5 * s),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 9 * s),
            decoration: BoxDecoration(
              color: AppPalette.ink.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppPalette.ink.withValues(alpha: 0.25)),
            ),
            child: Text(
              record.completed ? 'COMPLETED' : 'RUN',
              style: AppType.eyebrow(size: 20 * s).copyWith(letterSpacing: 3 * s),
            ),
          ),
        ],
      );

  Widget _divider(double s) => Container(
        width: 1,
        height: 62 * s,
        margin: EdgeInsets.symmetric(horizontal: 8 * s),
        color: AppPalette.ink.withValues(alpha: 0.18),
      );

  Widget _cell(double s, String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value, style: AppType.stat(size: 52 * s)),
            SizedBox(height: 4 * s),
            Text(label, style: AppType.label(size: 20 * s)),
          ],
        ),
      );
}

/// Draws the GPS trace as a route illustration: an equirectangular projection
/// centred on the route's bounding box, aspect preserved.
class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.route, required this.strokeWidth});

  final List<GeoPoint> route;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) {
      _paintEmpty(canvas, size);
      return;
    }

    // Degrees → a square local frame centred on the route's centroid.
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLon = double.infinity, maxLon = -double.infinity;
    for (final g in route) {
      minLat = math.min(minLat, g.lat);
      maxLat = math.max(maxLat, g.lat);
      minLon = math.min(minLon, g.lon);
      maxLon = math.max(maxLon, g.lon);
    }
    final midLat = (minLat + maxLat) / 2;
    final midLon = (minLon + maxLon) / 2;
    final kx = 111320 * math.cos(midLat * math.pi / 180);

    final pts = route.map((g) {
      final x = (g.lon - midLon) * kx;
      final y = -(g.lat - midLat) * 111132;
      return Offset(x, y);
    }).toList();

    var sx = 0.0, sy = 0.0;
    for (final p in pts) {
      sx += p.dx;
      sy += p.dy;
    }
    final c = Offset(sx / pts.length, sy / pts.length);

    final spanX = pts.map((p) => (p.dx - c.dx).abs()).reduce(math.max);
    final spanY = pts.map((p) => (p.dy - c.dy).abs()).reduce(math.max);
    final span = math.max(spanX, spanY);
    final scale = span <= 0 ? 1.0 : (math.min(size.width, size.height) * 0.86) / span;

    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = Offset(
        size.width / 2 + (pts[i].dx - c.dx) * scale,
        size.height / 2 + (pts[i].dy - c.dy) * scale,
      );
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }

    // Soft bloom, then the line, then a hairline core — gives the flat stroke
    // the depth of a printed route without needing a texture.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppPalette.ink.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppPalette.ink.withValues(alpha: 0.92),
    );

    // Start dot.
    final start = Offset(
      size.width / 2 + (pts.first.dx - c.dx) * scale,
      size.height / 2 + (pts.first.dy - c.dy) * scale,
    );
    canvas.drawCircle(start, strokeWidth * 2.6, Paint()..color = AppPalette.emberAccent);
    canvas.drawCircle(start, strokeWidth * 1.1, Paint()..color = Colors.white);
  }

  void _paintEmpty(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.6,
    );
    final path = Path()
      ..addOval(rect);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = AppPalette.ink.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.route != route;
}
