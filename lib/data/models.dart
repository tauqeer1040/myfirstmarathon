import 'dart:math' as math;

enum Phase { run, walk }

extension PhaseX on Phase {
  String get label => this == Phase.run ? 'RUN' : 'WALK';
  String get verb => this == Phase.run ? 'Run' : 'Walk';
}

/// One contiguous block of the interval workout.
class Interval {
  const Interval(this.phase, this.duration);

  final Phase phase;
  final Duration duration;

  int get seconds => duration.inSeconds;

  Map<String, dynamic> toJson() => {'p': phase.name, 's': seconds};

  factory Interval.fromJson(Map<String, dynamic> j) =>
      Interval(Phase.values.firstWhere((p) => p.name == j['p']), Duration(seconds: j['s'] as int));
}

/// A single workout from the plan: a run/walk pattern repeated N times, with a
/// distance the device must actually track before the workout counts as done.
class Workout {
  const Workout({
    required this.id,
    required this.level,
    required this.week,
    required this.dayIndex,
    required this.title,
    required this.pattern,
    required this.repeats,
    required this.targetKm,
    required this.note,
    required this.goalLabel,
  });

  final String id;
  final int level;
  final int week;

  /// 0 = Mon … 6 = Sun.
  final int dayIndex;

  /// `Run 1:30 · Walk 1:30`
  final String title;

  /// The run/walk pattern that repeats [repeats] times.
  final List<Interval> pattern;
  final int repeats;
  final double targetKm;
  final String note;

  /// Short coaching line shown under the title, e.g. `8 min total`.
  final String goalLabel;

  /// Flattened schedule: run, walk, run, walk…
  List<Interval> get schedule {
    final out = <Interval>[];
    for (var i = 0; i < repeats; i++) {
      out.addAll(pattern);
    }
    return out;
  }

  Duration get totalTime =>
      schedule.fold(Duration.zero, (a, b) => a + b.duration);

  Duration get runTime => schedule
      .where((i) => i.phase == Phase.run)
      .fold(Duration.zero, (a, b) => a + b.duration);

  Duration get walkTime => schedule
      .where((i) => i.phase == Phase.walk)
      .fold(Duration.zero, (a, b) => a + b.duration);

  /// `1:30 / 1:30 × 7`
  String get patternLabel {
    final p = pattern
        .map((i) => '${i.phase == Phase.run ? 'Run' : 'Walk'} ${_mmss(i.duration)}')
        .join('  ·  ');
    return repeats > 1 ? '$p  ×  $repeats' : p;
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'week': week,
        'dayIndex': dayIndex,
        'title': title,
        'pattern': pattern.map((i) => i.toJson()).toList(),
        'repeats': repeats,
        'targetKm': targetKm,
        'note': note,
        'goalLabel': goalLabel,
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'] as String,
        level: j['level'] as int,
        week: j['week'] as int,
        dayIndex: j['dayIndex'] as int,
        title: j['title'] as String,
        pattern: (j['pattern'] as List).map((e) => Interval.fromJson((e as Map).cast<String, dynamic>())).toList(),
        repeats: j['repeats'] as int,
        targetKm: (j['targetKm'] as num).toDouble(),
        note: j['note'] as String,
        goalLabel: j['goalLabel'] as String,
      );
}

/// A named block of the programme — the unit the home screen shows in its list.
class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.workouts,
  });

  final String id;
  final String title;
  final String subtitle;
  final int level;
  final List<Workout> workouts;

  int get weeks {
    final w = workouts.map((e) => e.week).toSet();
    return w.isEmpty ? 0 : w.reduce(math.max);
  }

  /// Total minutes across every workout in the plan.
  int get totalMinutes => workouts.fold(0, (a, w) => a + w.totalTime.inMinutes);

  double get totalKm => workouts.fold(0.0, (a, w) => a + w.targetKm);

  Plan copyWith({List<Workout>? workouts}) => Plan(
        id: id,
        title: title,
        subtitle: subtitle,
        level: level,
        workouts: workouts ?? this.workouts,
      );
}

class GeoPoint {
  const GeoPoint(this.lat, this.lon, this.epochMs, {this.speed = 0});

  final double lat;
  final double lon;
  final int epochMs;
  final double speed;

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 't': epochMs, 's': speed};

  factory GeoPoint.fromJson(Map<String, dynamic> j) =>
      GeoPoint((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble(), j['t'] as int,
          speed: (j['s'] as num?)?.toDouble() ?? 0);
}

/// A completed (or abandoned) run. This is what the stats screen aggregates and
/// what the share card renders.
class RunRecord {
  const RunRecord({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.elapsed,
    required this.distanceKm,
    required this.calories,
    required this.route,
    required this.workoutId,
    required this.completed,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final Duration elapsed;
  final double distanceKm;
  final int calories;
  final List<GeoPoint> route;
  final String? workoutId;
  final bool completed;

  bool get isInterval => workoutId != null;

  /// Seconds per kilometre. Null when the distance is too small to be meaningful.
  double? get paceSecPerKm {
    if (distanceKm < 0.02) return null;
    return elapsed.inSeconds / distanceKm;
  }

  /// Top speed, m/s → km/h.
  double get topSpeedKmh {
    if (route.length < 2) return 0;
    final s = route.map((e) => e.speed).fold<double>(0, math.max);
    return s * 3.6;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'elapsed': elapsed.inSeconds,
        'distanceKm': distanceKm,
        'calories': calories,
        'route': route.map((e) => e.toJson()).toList(),
        'workoutId': workoutId,
        'completed': completed,
      };

  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
        id: j['id'] as String,
        title: j['title'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        elapsed: Duration(seconds: j['elapsed'] as int),
        distanceKm: (j['distanceKm'] as num).toDouble(),
        calories: j['calories'] as int,
        route: (j['route'] as List? ?? const [])
            .map((e) => GeoPoint.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        workoutId: j['workoutId'] as String?,
        completed: j['completed'] as bool? ?? true,
      );
}
