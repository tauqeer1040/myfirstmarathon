import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/models.dart';

/// Derives a runner's "signature path" from their GPS history.
///
/// The idea: every logged route, resampled to a fixed number of equidistant
/// points, centred on its own centroid, rotated onto its principal axis and
/// scaled by one *shared* metres-per-unit factor. Averaging those aligned point
/// sets produces a single line that is literally the shape of how this person
/// runs — the same road, the same loop, the same park path.
///
/// Sharing one scale (rather than fitting each run to the box) is what keeps
/// the geometry honest: a short out-and-back and a long loop stay visibly
/// different sizes instead of being normalised into the same shape.
@immutable
class RunSignature {
  const RunSignature({
    required this.mean,
    required this.ghosts,
    required this.routeCount,
    required this.totalKm,
  });

  /// The averaged path, in unit space centred on the origin.
  final List<Offset2> mean;

  /// Individual past routes, same space — drawn faintly behind [mean].
  final List<List<Offset2>> ghosts;

  final int routeCount;
  final double totalKm;

  bool get hasHistory => mean.length > 1;

  /// Half-extent of the drawing, in unit space.
  ({double x, double y}) get bounds {
    var mx = 0.0, my = 0.0;
    for (final p in mean) {
      if (p.dx.abs() > mx) mx = p.dx.abs();
      if (p.dy.abs() > my) my = p.dy.abs();
    }
    return (x: mx, y: my);
  }
}

/// Minimal 2D point so this file doesn't depend on dart:ui.
@immutable
class Offset2 {
  const Offset2(this.dx, this.dy);
  final double dx;
  final double dy;
}

abstract final class SignatureBuilder {
  /// Points each route is resampled to. Enough to hold a road's shape without
  /// making averaging slow.
  static const int samples = 96;

  /// Ignore routes whose extent is wildly outside the pack — usually a GPS
  /// jump that slipped through, and it would smear the average.
  static const double _outlierFactor = 3.0;

  static RunSignature build(List<RunRecord> runs) {
    final prepared = <_Prepared>[];
    for (final r in runs) {
      if (r.route.length < 6) continue;
      final p = _prepare(r.route);
      if (p != null) prepared.add(p);
    }

    if (prepared.isEmpty) return const RunSignature(mean: [], ghosts: [], routeCount: 0, totalKm: 0);

    // One shared scale from the 90th percentile of route extent.
    final extents = prepared.map((e) => math.max(e.halfWidth, e.halfHeight)).toList()..sort();
    final p90 = extents[(extents.length * 0.9).floor().clamp(0, extents.length - 1)];
    final scale = p90 <= 0 ? 1.0 : 0.5 / p90;

    final inliers = prepared.where((e) {
      final ext = math.max(e.halfWidth, e.halfHeight);
      return ext <= p90 * _outlierFactor || prepared.length < 4;
    }).toList();

    // Weighted mean of corresponding points.
    final mean = List<Offset2>.generate(samples, (i) {
      var sx = 0.0, sy = 0.0;
      for (final r in inliers) {
        sx += r.points[i].dx;
        sy += r.points[i].dy;
      }
      final n = inliers.length;
      return Offset2(sx / n, sy / n);
    }, growable: false);

    final ghosts = [
      for (final r in inliers.take(6))
        r.points.map((p) => Offset2(p.dx * scale, p.dy * scale)).toList(growable: false),
    ];

    return RunSignature(
      mean: _smooth(mean, passes: 3, radius: 2),
      ghosts: ghosts,
      routeCount: runs.where((r) => r.route.length >= 6).length,
      totalKm: runs.fold(0.0, (a, r) => a + r.distanceKm),
    );
  }

  /// Route → local metric coordinates, equidistant-resampled, centred, and
  /// rotated so the dominant axis points "up".
  static _Prepared? _prepare(List<GeoPoint> route) {
    // Project to metres relative to the first fix (equirectangular is plenty
    // at the scale of a single run).
    final lat0 = route.first.lat * math.pi / 180;
    const mPerDegLat = 111132.0;
    final mPerDegLon = 111320.0 * math.cos(lat0);

    final xs = <double>[];
    final ys = <double>[];
    for (final g in route) {
      xs.add((g.lon - route.first.lon) * mPerDegLon);
      ys.add((g.lat - route.first.lat) * mPerDegLat);
    }

    // Resample by arc length so a slow section and a fast section contribute
    // equally — otherwise standing still would dominate the shape.
    final resampled = _resample(xs, ys, samples);
    if (resampled == null) return null;

    var cx = 0.0, cy = 0.0;
    for (final p in resampled) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= samples;
    cy /= samples;

    final centred = resampled.map((p) => Offset2(p.dx - cx, p.dy - cy)).toList();

    // Principal axis via the covariance matrix.
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in centred) {
      sxx += p.dx * p.dx;
      syy += p.dy * p.dy;
      sxy += p.dx * p.dy;
    }
    sxx /= samples;
    syy /= samples;
    sxy /= samples;

    final theta = 0.5 * math.atan2(2 * sxy, sxx - syy);
    final cos = math.cos(-theta), sin = math.sin(-theta);

    final rotated = centred.map((p) => Offset2(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos)).toList();

    var hw = 0.0, hh = 0.0;
    for (final p in rotated) {
      if (p.dx.abs() > hw) hw = p.dx.abs();
      if (p.dy.abs() > hh) hh = p.dy.abs();
    }
    if (hw <= 0 && hh <= 0) return null;

    // Traces that are almost perfectly straight carry no shape information.
    if (hh / hw < 0.12) return null;

    return _Prepared(points: rotated, halfWidth: hw, halfHeight: hh);
  }

  static List<Offset2>? _resample(List<double> xs, List<double> ys, int n) {
    final cum = List<double>.filled(xs.length, 0);
    for (var i = 1; i < xs.length; i++) {
      final dx = xs[i] - xs[i - 1];
      final dy = ys[i] - ys[i - 1];
      cum[i] = cum[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    final total = cum.last;
    if (total <= 1) return null; // a single dot — not a route

    final out = <Offset2>[];
    var seg = 1;
    for (var i = 0; i < n; i++) {
      final target = total * i / (n - 1);
      while (seg < cum.length - 1 && cum[seg] < target) {
        seg++;
      }
      final segStart = cum[seg - 1];
      final segLen = cum[seg] - segStart;
      final t = segLen <= 0 ? 0.0 : (target - segStart) / segLen;
      out.add(Offset2(
        xs[seg - 1] + (xs[seg] - xs[seg - 1]) * t,
        ys[seg - 1] + (ys[seg] - ys[seg - 1]) * t,
      ));
    }
    return out;
  }

  /// Moving average, wrapping at the ends. The path is a closed loop in the
  /// general case and near-closed when it isn't, so wrapping avoids a visible
  /// seam at the join.
  static List<Offset2> _smooth(List<Offset2> pts, {required int passes, required int radius}) {
    var current = pts;
    for (var pass = 0; pass < passes; pass++) {
      final next = List<Offset2>.generate(current.length, (i) {
        var sx = 0.0, sy = 0.0, n = 0;
        for (var k = -radius; k <= radius; k++) {
          final j = (i + k) % current.length;
          sx += current[j].dx;
          sy += current[j].dy;
          n++;
        }
        return Offset2(sx / n, sy / n);
      }, growable: false);
      current = next;
    }
    return current;
  }
}

class _Prepared {
  const _Prepared({required this.points, required this.halfWidth, required this.halfHeight});

  final List<Offset2> points;
  final double halfWidth;
  final double halfHeight;
}
