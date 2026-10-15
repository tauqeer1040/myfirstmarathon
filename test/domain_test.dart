import 'package:flutter_test/flutter_test.dart';

import 'package:mfm/core/formatters.dart';
import 'package:mfm/data/models.dart';
import 'package:mfm/data/plan_library.dart';
import 'package:mfm/data/signature_path.dart';

void main() {
  group('PlanLibrary', () {
    test('builds four levels of twelve sessions each', () {
      final plans = PlanLibrary.all();
      expect(plans, hasLength(4));
      for (final p in plans) {
        expect(p.workouts, hasLength(12), reason: p.title);
        expect(p.weeks, 4, reason: p.title);
      }
    });

    test('interval schedules repeat the run/walk pattern', () {
      final w = PlanLibrary.all().first.workouts.first;
      expect(w.schedule.length, w.pattern.length * w.repeats);
      expect(w.schedule.first.phase, Phase.run);
      // Level 1 week 1 is the walk-heavy one.
      expect(w.schedule[1].phase, Phase.walk);
    });

    test('level 4 week 4 is a single continuous hour with no walk', () {
      final level4 = PlanLibrary.all().last;
      // workouts are ordered by week, so week 4 is the last day's entry.
      final w = level4.workouts.lastWhere((e) => e.week == 4);
      expect(w.schedule, hasLength(1));
      expect(w.schedule.single.phase, Phase.run);
      expect(w.schedule.single.duration, const Duration(hours: 1));
      expect(w.totalTime, const Duration(hours: 1));
    });

    test('the long run is open-ended — no schedule at all', () {
      final lr = PlanLibrary.longRun;
      expect(lr.repeats, 0);
      expect(lr.schedule, isEmpty);
      expect(lr.targetKm, greaterThan(0));
    });
  });

  group('Fmt', () {
    test('clock drops the hour until it needs it', () {
      expect(Fmt.clock(const Duration(minutes: 39, seconds: 46)), '39:46');
      expect(Fmt.clock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(Fmt.clock(Duration.zero), '0:00');
    });

    test('countdown always shows minutes and padded seconds', () {
      expect(Fmt.countdown(const Duration(minutes: 1, seconds: 5)), '1:05');
      expect(Fmt.countdown(Duration.zero), '0:00');
    });

    test('km uses one decimal under 10 and none above', () {
      expect(Fmt.km(6.84), '6.8');
      expect(Fmt.km(16.0), '16');
    });

    test('pace is null when meaningless', () {
      expect(Fmt.pace(null), isNull);
      expect(Fmt.pace(0), isNull);
      expect(Fmt.pace(312), '5:12');
    });
  });

  group('RunRecord', () {
    test('pace needs real distance to be meaningful', () {
      final record = RunRecord(
        id: '1',
        title: 'Long Run',
        startedAt: DateTime(2026, 10, 14),
        elapsed: Duration.zero,
        distanceKm: 0,
        calories: 0,
        route: [],
        workoutId: null,
        completed: false,
      );
      expect(record.paceSecPerKm, isNull);
    });

    test('round-trips through JSON', () {
      final record = RunRecord(
        id: 'abc',
        title: 'Week 3 · Wed',
        startedAt: DateTime(2026, 10, 14, 7, 12),
        elapsed: const Duration(minutes: 26, seconds: 30),
        distanceKm: 3.42,
        calories: 298,
        route: const [GeoPoint(51.5, -0.12, 1760000000000)],
        workoutId: 'L1-W3-D2',
        completed: true,
      );
      final back = RunRecord.fromJson(record.toJson());
      expect(back.id, record.id);
      expect(back.title, record.title);
      expect(back.elapsed, record.elapsed);
      expect(back.distanceKm, closeTo(record.distanceKm, 1e-9));
      expect(back.workoutId, record.workoutId);
      expect(back.completed, isTrue);
      expect(back.route, hasLength(1));
    });
  });

  group('RunSignature', () {
    /// A square loop, walked once — the simplest thing that *is* a route.
    List<GeoPoint> squareLoop(int n) {
      final pts = <GeoPoint>[];
      for (var i = 0; i < n; i++) {
        final t = i / n * 4;
        // Perimeter of a ~100m square, in metres, converted back to degrees.
        final side = (t % 1) * 100;
        final (x, y) = switch ((t / 1).floor()) {
          0 => (side, 0.0),
          1 => (100.0, side),
          2 => (100.0 - side, 100.0),
          _ => (0.0, 100.0 - side),
        };
        final lat = 51.5 + y / 111132;
        final lon = -0.12 + x / (111320 * 0.6217);
        pts.add(GeoPoint(lat, lon, 1760000000000 + i * 1000));
      }
      return pts;
    }

    RunRecord withRoute(List<GeoPoint> route) => RunRecord(
          id: 'r',
          title: 'Long Run',
          startedAt: DateTime(2026, 10, 14),
          elapsed: const Duration(minutes: 20),
          distanceKm: 0.4,
          calories: 150,
          route: route,
          workoutId: null,
          completed: true,
        );

    test('derives a mean path from repeated routes', () {
      final sig = SignatureBuilder.build([
        withRoute(squareLoop(120)),
        withRoute(squareLoop(120)),
      ]);
      expect(sig.hasHistory, isTrue);
      expect(sig.mean, hasLength(SignatureBuilder.samples));
      expect(sig.routeCount, 2);
    });

    test('two runs in opposite directions resolve to the same loop', () {
      final forward = squareLoop(120);
      final reversed = squareLoop(120).reversed.toList();
      final a = SignatureBuilder.build([withRoute(forward)]);
      final b = SignatureBuilder.build([withRoute(reversed)]);
      // The path is flipped, so compare the extent rather than the point order.
      // Tolerance is relative: reversing changes where the resampling grid
      // lands, which shifts the shape by parts-per-million of the route.
      expect(a.bounds.x, closeTo(b.bounds.x, b.bounds.x * 1e-3));
      expect(a.bounds.y, closeTo(b.bounds.y, b.bounds.y * 1e-3));
    });

    test('returns an empty signature with no usable history', () {
      final sig = SignatureBuilder.build([withRoute(const [])]);
      expect(sig.hasHistory, isFalse);
      expect(sig.mean, isEmpty);
    });

    test('drops routes too short to describe a shape', () {
      final sig = SignatureBuilder.build([
        withRoute([GeoPoint(51.5, -0.12, 1), GeoPoint(51.5, -0.12, 2)]),
      ]);
      expect(sig.hasHistory, isFalse);
    });
  });
}
