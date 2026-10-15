import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Thin JSON-on-shared-preferences store. Deliberately tiny: the app has no
/// backend, and everything the user cares about is a plan's progress and a
/// list of runs.
class AppStore {
  AppStore(this._prefs);

  static const _kCompleted = 'mfm.completedWorkouts';
  static const _kRuns = 'mfm.runs';
  static const _kStartDate = 'mfm.startDate';
  static const _kLastDistance = 'mfm.lastDistanceKm';
  static const _kHaptics = 'mfm.haptics';
  static const _kUnits = 'mfm.units';

  final SharedPreferences _prefs;

  static Future<AppStore> open() async =>
      AppStore(await SharedPreferences.getInstance());

  // ── Plan progress ──────────────────────────────────────────────────────────

  Set<String> get completedWorkouts =>
      (_prefs.getStringList(_kCompleted) ?? const []).toSet();

  Future<void> setWorkoutCompleted(String id, bool done) async {
    final s = completedWorkouts;
    if (done) {
      s.add(id);
      HapticNote.completed();
    } else {
      s.remove(id);
    }
    await _prefs.setStringList(_kCompleted, s.toList());
  }

  // ── Runs ───────────────────────────────────────────────────────────────────

  List<RunRecord> get runs {
    final raw = _prefs.getString(_kRuns);
    if (raw == null) return const [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => RunRecord.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    } catch (e) {
      debugPrint('AppStore: corrupt run history ($e) — starting fresh');
      return const [];
    }
  }

  Future<void> saveRun(RunRecord r) async {
    final all = runs.where((e) => e.id != r.id).toList()..insert(0, r);
    await _writeRuns(all);
  }

  Future<void> deleteRun(String id) async =>
      _writeRuns(runs.where((e) => e.id != id).toList());

  Future<void> _writeRuns(List<RunRecord> all) => _prefs.setString(
        _kRuns,
        jsonEncode(all.take(200).map((e) => e.toJson()).toList()),
      );

  // ── Preferences ────────────────────────────────────────────────────────────

  DateTime get startDate {
    final ms = _prefs.getInt(_kStartDate);
    return ms == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setStartDate(DateTime d) =>
      _prefs.setInt(_kStartDate, d.millisecondsSinceEpoch);

  double get lastDistanceKm => _prefs.getDouble(_kLastDistance) ?? 5;

  Future<void> setLastDistanceKm(double v) => _prefs.setDouble(_kLastDistance, v);

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setHapticsEnabled(bool v) => _prefs.setBool(_kHaptics, v);

  bool get imperial => _prefs.getBool(_kUnits) ?? false;

  Future<void> setImperial(bool v) => _prefs.setBool(_kUnits, v);
}

/// Tiny seam so the store can trigger a success haptic when a workout is
/// completed, without the store importing the whole UI layer.
abstract final class HapticNote {
  static void Function()? onCompleted;
  static void completed() => onCompleted?.call();
}
