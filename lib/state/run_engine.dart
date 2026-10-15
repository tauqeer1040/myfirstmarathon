import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/haptics.dart';
import '../data/models.dart';

enum RunStatus { idle, active, paused, finished }

@immutable
class RunState {
  const RunState({
    this.status = RunStatus.idle,
    this.workout,
    this.schedule = const [],
    this.intervalIndex = 0,
    this.cycles = 0,
    this.intervalRemaining = Duration.zero,
    this.elapsed = Duration.zero,
    this.distanceKm = 0,
    this.calories = 0,
    this.route = const [],
    this.startedAt,
    this.gpsReady = false,
    this.gpsError,
    this.distanceReached = false,
    this.currentSpeedKmh = 0,
    this.livePaceSecPerKm,
  });

  final RunStatus status;
  final Workout? workout;
  final List<Interval> schedule;

  /// Index into [schedule] of the *current* block.
  final int intervalIndex;

  /// How many times the run/walk pattern has fully repeated.
  final int cycles;

  final Duration intervalRemaining;
  final Duration elapsed;
  final double distanceKm;
  final int calories;
  final List<GeoPoint> route;
  final DateTime? startedAt;
  final bool gpsReady;
  final String? gpsError;
  final bool distanceReached;
  final double currentSpeedKmh;
  final double? livePaceSecPerKm;

  bool get isIdle => status == RunStatus.idle;
  bool get isActive => status == RunStatus.active;
  bool get isPaused => status == RunStatus.paused;
  bool get isFinished => status == RunStatus.finished;

  /// Open-ended runs (LONG RUN) have no schedule at all.
  bool get isOpenEnded => (workout?.repeats ?? 0) == 0;

  Interval? get current =>
      schedule.isEmpty ? null : schedule[intervalIndex % schedule.length];

  Phase get phase => current?.phase ?? Phase.run;

  double get targetKm => workout?.targetKm ?? 0;

  double get distanceProgress =>
      targetKm <= 0 ? 0 : (distanceKm / targetKm).clamp(0.0, 1.0);

  double get intervalProgress {
    final cur = current;
    if (cur == null || cur.duration == Duration.zero) return 1;
    final total = cur.duration.inMilliseconds;
    final left = intervalRemaining.inMilliseconds;
    return (1 - left / total).clamp(0.0, 1.0);
  }

  /// Progress through the whole run/walk pattern (one cycle).
  double get cycleProgress {
    if (schedule.isEmpty) return 0;
    final inCycle = schedule.indexWhere(
      (i) => i.duration == current?.duration && i.phase == phase,
    );
    final idx = inCycle < 0 ? intervalIndex : inCycle;
    final done = schedule
        .take(idx)
        .fold<int>(0, (a, i) => a + i.duration.inMilliseconds);
    final total = schedule.fold<int>(0, (a, i) => a + i.duration.inMilliseconds);
    final block = schedule[idx % schedule.length];
    if (total == 0) return 0;
    return ((done + block.duration.inMilliseconds - intervalRemaining.inMilliseconds) / total)
        .clamp(0.0, 1.0);
  }

  RunState copyWith({
    RunStatus? status,
    Workout? workout,
    List<Interval>? schedule,
    int? intervalIndex,
    int? cycles,
    Duration? intervalRemaining,
    Duration? elapsed,
    double? distanceKm,
    int? calories,
    List<GeoPoint>? route,
    DateTime? startedAt,
    bool? gpsReady,
    String? gpsError,
    bool clearGpsError = false,
    bool? distanceReached,
    double? currentSpeedKmh,
    double? livePaceSecPerKm,
  }) {
    return RunState(
      status: status ?? this.status,
      workout: workout ?? this.workout,
      schedule: schedule ?? this.schedule,
      intervalIndex: intervalIndex ?? this.intervalIndex,
      cycles: cycles ?? this.cycles,
      intervalRemaining: intervalRemaining ?? this.intervalRemaining,
      elapsed: elapsed ?? this.elapsed,
      distanceKm: distanceKm ?? this.distanceKm,
      calories: calories ?? this.calories,
      route: route ?? this.route,
      startedAt: startedAt ?? this.startedAt,
      gpsReady: gpsReady ?? this.gpsReady,
      gpsError: clearGpsError ? null : (gpsError ?? this.gpsError),
      distanceReached: distanceReached ?? this.distanceReached,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      livePaceSecPerKm: livePaceSecPerKm ?? this.livePaceSecPerKm,
    );
  }
}

/// Drives one run: the interval countdown, the GPS track, distance, pace and
/// calories. All timing is derived from wall-clock deltas rather than counting
/// ticks, so a dropped frame or a backgrounded app can't desynchronise the
/// countdown from reality.
class RunEngine extends Notifier<RunState> {
  Timer? _ticker;
  StreamSubscription<Position>? _geoSub;
  DateTime? _lastTick;
  GeoPoint? _lastFix;
  DateTime? _lastFixAt;
  double _recentSpeed = 0;

  @override
  RunState build() {
    ref.onDispose(_teardown);
    return const RunState();
  }

  void _teardown() {
    _ticker?.cancel();
    _geoSub?.cancel();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start(Workout workout) async {
    final schedule = workout.schedule;
    state = RunState(
      status: RunStatus.active,
      workout: workout,
      schedule: schedule,
      intervalIndex: 0,
      cycles: 0,
      intervalRemaining: schedule.isEmpty ? Duration.zero : schedule.first.duration,
      startedAt: DateTime.now(),
    );
    _lastTick = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    await _startTracking();
  }

  void pause() {
    if (!state.isActive) return;
    _ticker?.cancel();
    _geoSub?.pause();
    state = state.copyWith(status: RunStatus.paused, currentSpeedKmh: 0);
    Haptics.medium();
  }

  void resume() {
    if (!state.isPaused) return;
    _lastTick = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    _geoSub?.resume();
    state = state.copyWith(status: RunStatus.active);
    Haptics.medium();
  }

  /// Skip to the next run/walk block. The escape hatch for anyone whose legs
  /// have stopped working.
  void skipInterval() {
    if (!state.isActive) return;
    Haptics.rigid();
    _advanceInterval();
  }

  /// End the run and produce the record. Returns null if nothing was recorded.
  Future<RunRecord?> finish({bool completed = false}) async {
    if (state.isIdle) return null;
    _ticker?.cancel();
    await _geoSub?.cancel();
    _geoSub = null;
    Haptics.cancel();

    final s = state;
    final record = RunRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: s.workout?.title ?? 'Long Run',
      startedAt: s.startedAt ?? DateTime.now(),
      elapsed: s.elapsed,
      distanceKm: s.distanceKm,
      calories: s.calories,
      route: s.route,
      workoutId: s.workout?.id,
      completed: completed || s.distanceReached,
    );

    state = s.copyWith(status: RunStatus.finished, currentSpeedKmh: 0);
    if (record.completed) Haptics.success();
    return record;
  }

  void reset() {
    _teardown();
    Haptics.cancel();
    state = const RunState();
  }

  // ── Clock ──────────────────────────────────────────────────────────────────

  void _tick() {
    if (!state.isActive) return;
    final now = DateTime.now();
    final delta = now.difference(_lastTick!);
    _lastTick = now;

    if (state.isOpenEnded) {
      state = state.copyWith(
        elapsed: state.elapsed + delta,
        calories: _caloriesFor(state.elapsed + delta, Phase.run),
      );
      return;
    }

    var remaining = state.intervalRemaining - delta;
    var index = state.intervalIndex;
    var cycles = state.cycles;
    final total = state.elapsed + delta;

    if (remaining <= Duration.zero) {
      // Carry the overshoot into the next block so long sessions don't drift.
      var carry = -remaining;
      var flipped = false;
      index += 1;
      while (carry > Duration.zero) {
        if (index >= state.schedule.length) {
          index = 0;
          cycles += 1;
        }
        final block = state.schedule[index];
        if (carry < block.duration) {
          remaining = block.duration - carry;
          carry = Duration.zero;
        } else {
          carry -= block.duration;
          index += 1;
        }
        flipped = true;
      }
      if (flipped) Haptics.phaseChange();
    }

    // Warn on the last three seconds of each block, then on the second it flips.
    final secondsLeft = remaining.inMilliseconds / 1000;
    if (secondsLeft <= 3.05 && secondsLeft > 2.0 && state.intervalRemaining.inMilliseconds ~/ 1000 != remaining.inMilliseconds ~/ 1000) {
      Haptics.countdownTick();
    }

    final phase = state.schedule.isEmpty ? Phase.run : state.schedule[index % state.schedule.length].phase;

    state = state.copyWith(
      elapsed: total,
      intervalRemaining: remaining,
      intervalIndex: index,
      cycles: cycles,
      calories: _caloriesFor(total, phase),
    );
  }

  void _advanceInterval() {
    if (state.schedule.isEmpty) return;
    final index = (state.intervalIndex + 1) % state.schedule.length;
    final cycles = state.intervalIndex + 1 >= state.schedule.length ? state.cycles + 1 : state.cycles;
    state = state.copyWith(
      intervalIndex: index,
      cycles: cycles,
      intervalRemaining: state.schedule[index].duration,
    );
  }

  /// MET-based estimate: 9.8 for running, 4.3 for walking, 70 kg reference.
  int _caloriesFor(Duration d, Phase phase) {
    final met = phase == Phase.run ? 9.8 : 4.3;
    final hours = d.inMilliseconds / 3600000;
    return (met * 70 * hours).round();
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<void> _startTracking() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = state.copyWith(gpsError: 'Location services are off');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        state = state.copyWith(gpsError: 'Location permission denied');
        return;
      }

      _geoSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(_onPosition, onError: (Object e) {
        state = state.copyWith(gpsError: 'GPS unavailable');
      });
    } catch (e) {
      state = state.copyWith(gpsError: 'GPS unavailable');
    }
  }

  void _onPosition(Position p) {
    final now = DateTime.now();
    final fix = GeoPoint(p.latitude, p.longitude, now.millisecondsSinceEpoch, speed: p.speed);

    if (!state.gpsReady) {
      state = state.copyWith(gpsReady: true, clearGpsError: true);
    }

    double added = 0;
    final prev = _lastFix;
    if (prev != null) {
      final dt = (now.millisecondsSinceEpoch - _lastFixAt!.millisecondsSinceEpoch) / 1000.0;
      final d = _haversine(prev.lat, prev.lon, p.latitude, p.longitude);
      // Reject teleports and stationary jitter: anything implying > 12 m/s
      // between fixes, or a step smaller than the reported accuracy.
      final implied = dt <= 0 ? 9999.0 : d / dt;
      if (implied < 12.0 && (d > 0.8 || (p.speed > 0.4 && d > 0.3))) {
        added = d;
      }
      if (dt > 0 && dt < 20) {
        // Light smoothing — GPS speed is noisy enough to be unusable raw.
        _recentSpeed = _recentSpeed * 0.7 + (d / dt) * 0.3;
      }
    }

    _lastFix = fix;
    _lastFixAt = now;

    final distance = state.distanceKm + added;
    final route = [...state.route, fix];
    final elapsedSec = state.elapsed.inSeconds;

    var paceSecPerKm = state.livePaceSecPerKm;
    if (elapsedSec > 25 && distance > 0.05) {
      paceSecPerKm = elapsedSec / distance;
    } else if (_recentSpeed > 0.6) {
      paceSecPerKm = 1000 / (_recentSpeed * 3.6);
    }

    var reached = state.distanceReached;
    if (!reached && state.targetKm > 0 && distance >= state.targetKm) {
      reached = true;
      Haptics.success();
      unawaited(finish(completed: true));
    }

    state = state.copyWith(
      distanceKm: distance,
      route: route.length > 4000 ? route.sublist(route.length - 4000) : route,
      currentSpeedKmh: _recentSpeed * 3.6,
      livePaceSecPerKm: paceSecPerKm,
      distanceReached: reached,
    );
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  static double _rad(double d) => d * math.pi / 180.0;
}

final runEngineProvider = NotifierProvider<RunEngine, RunState>(RunEngine.new);
