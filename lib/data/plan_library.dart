import 'models.dart';

/// The programme.
///
/// Four levels, four weeks each, three sessions a week — the same shape as the
/// app this is modelled on. Every session is a run/walk pattern repeated until
/// the device has tracked the session's distance, which is the one rule the
/// runner never has to think about.
abstract final class PlanLibrary {
  static const List<({int level, String title, String subtitle, String goal})> levels = [
    (level: 1, title: 'Level 1', subtitle: 'Jog 20 minutes', goal: '20 min continuous'),
    (level: 2, title: 'Level 2', subtitle: 'Jog 30 minutes', goal: '30 min continuous'),
    (level: 3, title: 'Level 3', subtitle: 'Jog 40 minutes', goal: '40 min continuous'),
    (level: 4, title: 'Level 4', subtitle: 'Run a full hour', goal: '60 min continuous'),
  ];

  /// Weeks 1–4 progression tables: [runSeconds, walkSeconds, repeats, targetKm].
  /// The walk gap shrinks and the run block grows until it disappears entirely.
  static const List<List<List<num>>> table = [
    // Level 1 — run 20 min
    [
      [60, 90, 8, 1.6], // W1 — brisk walk pace, short hops
      [90, 90, 7, 2.0],
      [120, 60, 7, 2.4],
      [150, 60, 6, 2.8],
    ],
    // Level 2 — run 30 min
    [
      [180, 90, 6, 3.0],
      [240, 90, 5, 3.4],
      [300, 90, 4, 3.8],
      [420, 60, 4, 4.2],
    ],
    // Level 3 — run 40 min
    [
      [480, 90, 4, 4.6],
      [600, 90, 3, 5.0],
      [720, 90, 3, 5.4],
      [840, 60, 3, 5.8],
    ],
    // Level 4 — run 60 min
    [
      [900, 60, 3, 6.4],
      [1080, 60, 2, 7.0],
      [1260, 60, 2, 7.6],
      [3600, 0, 1, 8.6], // no walk — one continuous hour
    ],
  ];

  static const List<String> notes = [
    'Walk as slowly as you like — this is a rest, not a punishment.',
    'Stay on the flat today. Distance comes later.',
    'You should finish able to say one more sentence. That is the pace.',
    'Last one before the next level. Push the walk a little shorter.',
    'Knees soft, land under your hips. Short and smooth beats fast.',
    'If the run block feels long, walk early. You will thank yourself later.',
    'Hold back by two per cent. Finishing strong is the whole point.',
    'Pick up the pace in the last two minutes of each run block.',
  ];

  static const List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<int> sessionDays = [0, 2, 4]; // Mon / Wed / Fri

  static List<Plan> all() {
    return [
      for (final l in levels) _buildLevel(l.level, l.title, l.subtitle),
    ];
  }

  static Plan _buildLevel(int level, String title, String subtitle) {
    final workouts = <Workout>[];
    final weeks = table[level - 1];

    for (var w = 0; w < weeks.length; w++) {
      final row = weeks[w];
      final run = Duration(seconds: row[0].toInt());
      final walk = Duration(seconds: row[1].toInt());
      final repeats = row[2].toInt();
      final km = row[3].toDouble();

      final pattern = <Interval>[
        Interval(Phase.run, run),
        if (walk > Duration.zero) Interval(Phase.walk, walk),
      ];

      final totalMinutes = (run.inSeconds + walk.inSeconds) * repeats / 60;

      for (var s = 0; s < sessionDays.length; s++) {
        final day = sessionDays[s];
        workouts.add(
          Workout(
            id: 'L$level-W${w + 1}-D$day',
            level: level,
            week: w + 1,
            dayIndex: day,
            title: 'Week ${w + 1} · ${days[day]}',
            pattern: pattern,
            repeats: repeats,
            targetKm: km,
            note: notes[((level - 1) * 4 + w + s) % notes.length],
            goalLabel: '${totalMinutes.round()} min · ${_mmss(run)}'
                '${walk > Duration.zero ? ' / ${_mmss(walk)}' : ''}',
          ),
        );
      }
    }

    return Plan(
      id: 'level-$level',
      title: title,
      subtitle: subtitle,
      level: level,
      workouts: workouts,
    );
  }

  /// The free-form long run offered on the home screen — no intervals, just
  /// "go until you hit the distance". Mirrors the app's LONG RUN tile.
  static Workout get longRun => const Workout(
        id: 'long-run',
        level: 0,
        week: 0,
        dayIndex: 0,
        title: 'Long Run',
        pattern: [Interval(Phase.run, Duration.zero)],
        repeats: 0,
        targetKm: 5,
        note: 'No intervals. Just run until you hit the distance.',
        goalLabel: 'Open · distance target',
      );

  static String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
