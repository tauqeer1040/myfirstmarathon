import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../data/plan_library.dart';
import '../data/signature_path.dart';

/// Overridden at startup once shared preferences have been opened.
final storeProvider = Provider<AppStore>(
  (ref) => throw UnimplementedError('storeProvider must be overridden in main()'),
);

final plansProvider = Provider<List<Plan>>((ref) => PlanLibrary.all());

/// Ids of workouts the runner has already banked.
class CompletedWorkouts extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(storeProvider).completedWorkouts;

  Future<void> toggle(String id) async {
    final next = {...state};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    await ref.read(storeProvider).setWorkoutCompleted(id, next.contains(id));
  }
}

final completedProvider =
    NotifierProvider<CompletedWorkouts, Set<String>>(CompletedWorkouts.new);

/// Run history, newest first.
class RunHistory extends Notifier<List<RunRecord>> {
  @override
  List<RunRecord> build() => ref.read(storeProvider).runs;

  Future<void> add(RunRecord r) async {
    state = [r, ...state.where((e) => e.id != r.id)];
    await ref.read(storeProvider).saveRun(r);
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await ref.read(storeProvider).deleteRun(id);
  }

  void clear() => state = const [];
}

final runHistoryProvider = NotifierProvider<RunHistory, List<RunRecord>>(RunHistory.new);

class DistanceTarget extends Notifier<double> {
  @override
  double build() => ref.read(storeProvider).lastDistanceKm;

  Future<void> set(double km) async {
    state = km;
    await ref.read(storeProvider).setLastDistanceKm(km);
  }
}

final distanceTargetProvider = NotifierProvider<DistanceTarget, double>(DistanceTarget.new);

class Preferences extends Notifier<({bool haptics, bool imperial})> {
  @override
  ({bool haptics, bool imperial}) build() {
    final s = ref.read(storeProvider);
    return (haptics: s.hapticsEnabled, imperial: s.imperial);
  }

  Future<void> setHaptics(bool v) async {
    state = (haptics: v, imperial: state.imperial);
    await ref.read(storeProvider).setHapticsEnabled(v);
  }

  Future<void> setImperial(bool v) async {
    state = (haptics: state.haptics, imperial: v);
    await ref.read(storeProvider).setImperial(v);
  }
}

final preferencesProvider =
    NotifierProvider<Preferences, ({bool haptics, bool imperial})>(Preferences.new);

/// Aggregate stats for the blue stats screen.
class Totals {
  const Totals({
    required this.distanceKm,
    required this.runs,
    required this.duration,
    required this.calories,
    required this.weeklyKm,
    required this.bestPaceSecPerKm,
  });

  final double distanceKm;
  final int runs;
  final Duration duration;
  final int calories;

  /// Distance per ISO week index, oldest → newest.
  final List<double> weeklyKm;
  final double? bestPaceSecPerKm;

  static const empty = Totals(
    distanceKm: 0,
    runs: 0,
    duration: Duration.zero,
    calories: 0,
    weeklyKm: [0, 0, 0, 0, 0, 0, 0, 0],
    bestPaceSecPerKm: null,
  );
}

final totalsProvider = Provider<Totals>((ref) {
  final runs = ref.watch(runHistoryProvider);
  if (runs.isEmpty) return Totals.empty;

  final now = DateTime.now();
  final startOfWeek = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final weeks = List<double>.filled(8, 0);
  double distance = 0;
  double? best;
  var duration = Duration.zero;
  var calories = 0;

  for (final r in runs) {
    distance += r.distanceKm;
    duration += r.elapsed;
    calories += r.calories;
    final p = r.paceSecPerKm;
    if (p != null && (best == null || p < best)) best = p;

    final delta = r.startedAt.difference(startOfWeek).inDays;
    if (delta >= 0 && delta < 7) {
      final idx = weeks.length - 1 - delta;
      weeks[idx] += r.distanceKm;
    }
  }

  return Totals(
    distanceKm: distance,
    runs: runs.length,
    duration: duration,
    calories: calories,
    weeklyKm: weeks,
    bestPaceSecPerKm: best,
  );
});

/// The runner's signature path, recomputed only when history changes. This is
/// expensive enough (resampling + PCA + averaging every route) that it should
/// never sit inside a `build()`.
final signatureProvider = Provider<RunSignature>(
  (ref) => SignatureBuilder.build(ref.watch(runHistoryProvider)),
);

/// Progress through the active plan level, in workouts.
class PlanProgress {
  const PlanProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  double get fraction => total == 0 ? 0 : completed / total;

  int get level {
    // Levels unlock as each is finished; everyone starts at 1.
    return 1 + (completed ~/ 12).clamp(0, 3);
  }
}

final planProgressProvider = Provider<PlanProgress>((ref) {
  final done = ref.watch(completedProvider);
  final plans = ref.watch(plansProvider);
  final total = plans.fold<int>(0, (a, p) => a + p.workouts.length);
  return PlanProgress(completed: done.length, total: total);
});

/// The workout the home screen is currently pointing at: the next unfinished
/// workout in the active level, falling back to the long run when the
/// programme is complete.
final nextWorkoutProvider = Provider<Workout?>((ref) {
  final done = ref.watch(completedProvider);
  final plans = ref.watch(plansProvider);
  final progress = ref.watch(planProgressProvider);

  for (final p in plans) {
    if (p.level != progress.level) continue;
    for (final w in p.workouts) {
      if (!done.contains(w.id)) return w;
    }
  }
  for (final p in plans) {
    for (final w in p.workouts) {
      if (!done.contains(w.id)) return w;
    }
  }
  return null;
});

@visibleForTesting
String debugPlanSignature() {
  final plans = PlanLibrary.all();
  return '${plans.length} plans, ${plans.fold<int>(0, (a, p) => a + p.workouts.length)} workouts';
}
