import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/signature_path.dart';

/// Draws the runner's signature path — a line map of the routes they actually
/// run, distilled from their GPS history.
///
/// Layered, back to front:
///  * **ghosts** — up to six past routes at low alpha, so the shape reads as a
///    habit rather than a single trace;
///  * **mean path** — the averaged line, drawn on with an animated stroke so it
///    *writes itself* the first time a screen shows it;
///  * **nodes** — dots at the start, the high point and the finish, which is
///    the only way to give an abstract line a sense of direction;
///  * a **comet head** travelling the mean path, so the glyph is never static.
class SignaturePath extends StatefulWidget {
  const SignaturePath({
    required this.signature,
    required this.color,
    this.strokeWidth = 3.2,
    this.animate = true,
    this.showNodes = true,
    this.fallback,
    super.key,
  });

  final RunSignature signature;
  final Color color;
  final double strokeWidth;
  final bool animate;
  final bool showNodes;

  /// Rendered when there is no history yet.
  final Widget? fallback;

  @override
  State<SignaturePath> createState() => _SignaturePathState();
}

class _SignaturePathState extends State<SignaturePath> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final AnimationController _comet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _draw.forward();
      _comet.repeat();
    }
  }

  @override
  void didUpdateWidget(SignaturePath old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_comet.isAnimating) {
      _comet.repeat();
    } else if (!widget.animate && _comet.isAnimating) {
      _comet.stop();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _comet.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.signature.hasHistory) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_draw, _comet, _breathe]),
        builder: (context, _) => CustomPaint(
          painter: _SignaturePainter(
            signature: widget.signature,
            color: widget.color,
            draw: Curves.easeOutCubic.transform(_draw.value),
            comet: _comet.value,
            breathe: _breathe.value,
            strokeWidth: widget.strokeWidth,
            showNodes: widget.showNodes,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({
    required this.signature,
    required this.color,
    required this.draw,
    required this.comet,
    required this.breathe,
    required this.strokeWidth,
    required this.showNodes,
  });

  final RunSignature signature;
  final Color color;
  final double draw;
  final double comet;
  final double breathe;
  final double strokeWidth;
  final bool showNodes;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the unit square into the canvas, preserving aspect so a north-south
    // route doesn't get stretched into a blob.
    final b = signature.bounds;
    final ex = math.max(b.x, 0.001);
    final ey = math.max(b.y, 0.001);
    final scale = math.min(size.width / (ex * 2.18), size.height / (ey * 2.18));
    final center = Offset(size.width / 2, size.height / 2);

    Offset project(Offset2 p) => center + Offset(p.dx * scale, -p.dy * scale);

    Path pathFrom(List<Offset2> pts) {
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = project(pts[i]);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          // Catmull-Rom → cubic Bézier. Straight segments make an averaged GPS
          // line look like a polygon; this keeps it reading as a road.
          final p0 = pts[i < 1 ? pts.length - 2 : i - 1];
          final p1 = pts[i];
          final p2 = pts[(i + 1) < pts.length ? i + 1 : 0];
          final p3 = pts[(i + 2) < pts.length ? i + 2 : i + 1];

          final c1 = Offset(project(p1).dx + (project(p2).dx - project(p0).dx) / 6,
              project(p1).dy + (project(p2).dy - project(p0).dy) / 6);
          final c2 = Offset(project(p2).dx - (project(p3).dx - project(p1).dx) / 6,
              project(p2).dy - (project(p3).dy - project(p1).dy) / 6);

          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, project(p2).dx, project(p2).dy);
        }
      }
      return path;
    }

    // ── Ghosts ──────────────────────────────────────────────────────────────
    for (final g in signature.ghosts) {
      canvas.drawPath(
        pathFrom(g),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.10),
      );
    }

    final path = pathFrom(signature.mean);

    // ── Mean path, drawn on ─────────────────────────────────────────────────
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    Path drawn = Path();
    final t = draw.clamp(0.0, 1.0);
    for (final m in metrics) {
      drawn.addPath(m.extractPath(0, m.length * t), Offset.zero);
    }

    // Soft bloom beneath, then the crisp stroke.
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.08 + 0.04 * breathe),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.42),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.34
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.95),
    );

    if (draw < 0.99) return;

    // ── Direction nodes ─────────────────────────────────────────────────────
    if (showNodes) {
      final pts = signature.mean;
      final start = project(pts.first);
      final finish = project(pts.last);

      // Topmost point gives the loop a visual "peak" to hang the caption on.
      var topIdx = 0;
      for (var i = 1; i < pts.length; i++) {
        if (pts[i].dy > pts[topIdx].dy) topIdx = i;
      }
      final top = project(pts[topIdx]);

      _node(canvas, finish, color, filled: true, r: strokeWidth * 1.5);
      _ring(canvas, start, color, r: strokeWidth * 1.5);
      _node(canvas, top, color, filled: false, r: strokeWidth * 0.95);
    }

    // ── Comet head travelling the loop ──────────────────────────────────────
    if (draw >= 0.99) {
      final total = metrics.fold<double>(0, (a, m) => a + m.length);
      var target = total * comet;
      for (final m in metrics) {
        if (target <= m.length) {
          final tan = m.getTangentForOffset(target);
          if (tan != null) {
            canvas.drawCircle(
              tan.position,
              strokeWidth * 3.4,
              Paint()..color = color.withValues(alpha: 0.18),
            );
            canvas.drawCircle(tan.position, strokeWidth * 1.25, Paint()..color = color);
          }
          break;
        }
        target -= m.length;
      }
    }
  }

  void _node(Canvas canvas, Offset at, Color c, {required bool filled, required double r}) {
    if (filled) {
      canvas.drawCircle(at, r + 4, Paint()..color = c.withValues(alpha: 0.16));
      canvas.drawCircle(at, r, Paint()..color = c);
    } else {
      canvas.drawCircle(at, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = c.withValues(alpha: 0.8));
    }
  }

  void _ring(Canvas canvas, Offset at, Color c, {required double r}) {
    canvas.drawCircle(at, r + 4, Paint()..color = c.withValues(alpha: 0.16));
    canvas.drawCircle(at, r, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = c.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.draw != draw || old.comet != comet || old.breathe != breathe || old.signature != signature;
}

/// A synthetic loop used before any run has been logged, so the home screen's
/// centerpiece is never empty. Deliberately wide and flat — it has to read as a
/// stretch of road, not as a circle.
class PlaceholderRoute extends StatefulWidget {
  const PlaceholderRoute({
    required this.color,
    this.strokeWidth = 2.6,
    super.key,
  });

  final Color color;
  final double strokeWidth;

  @override
  State<PlaceholderRoute> createState() => _PlaceholderRouteState();
}

class _PlaceholderRouteState extends State<PlaceholderRoute>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _PlaceholderPainter(
            t: _c.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  _PlaceholderPainter({required this.t, required this.color, required this.strokeWidth});

  final double t;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.88;
    final h = (size.height * 0.52).clamp(72.0, 190.0);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );

    // One continuous line with a deliberate kink on the return leg. A plain
    // oval reads as a logo; this reads as somewhere someone actually went.
    final path = Path()
      ..moveTo(rect.left, rect.top + rect.height * 0.18)
      ..cubicTo(
        rect.left + rect.width * 0.05, rect.top - rect.height * 0.18,
        rect.right - rect.width * 0.06, rect.top - rect.height * 0.20,
        rect.right, rect.top + rect.height * 0.26,
      )
      ..cubicTo(
        rect.right + rect.width * 0.07, rect.top + rect.height * 0.62,
        rect.right - rect.width * 0.26, rect.bottom + rect.height * 0.10,
        rect.left + rect.width * 0.36, rect.bottom,
      )
      ..cubicTo(
        rect.left - rect.width * 0.05, rect.bottom - rect.height * 0.12,
        rect.left - rect.width * 0.04, rect.top + rect.height * 0.66,
        rect.left, rect.top + rect.height * 0.18,
      );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.45),
    );

    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    var target = total * t;
    for (final m in metrics) {
      if (target <= m.length) {
        final tan = m.getTangentForOffset(target);
        if (tan != null) {
          canvas.drawCircle(tan.position, strokeWidth * 3.4,
              Paint()..color = color.withValues(alpha: 0.20));
          canvas.drawCircle(tan.position, strokeWidth * 1.4,
              Paint()..color = color.withValues(alpha: 0.95));
        }
        break;
      }
      target -= m.length;
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => old.t != t;
}
