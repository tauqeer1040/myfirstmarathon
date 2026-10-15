import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Haptic vocabulary, mapped from the platform feedback generators onto what
/// Flutter + the `vibration` plugin can express cross-platform.
///
/// Rules of engagement (Apple HIG "Playing haptics", WCAG 2.3.3):
///  * every discrete user action gets feedback within the perception window;
///  * haptics only ever answer a *user-initiated* action, never a timer tick
///    or a scroll event — spam destroys the signal;
///  * haptics are always paired with a visual change, so the feature degrades
///    gracefully on devices (and platforms) without a Taptic Engine.
abstract final class Haptics {
  static bool _supported = true;
  static bool _amplitudeControl = false;

  static bool get enabled => _enabled && _supported;
  static bool _enabled = true;

  /// Probed once at startup; everything is a no-op if the device can't vibrate.
  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // iOS: rely on Flutter's own impact/selection generators, which map onto
      // UIImpactFeedbackGenerator / UISelectionFeedbackGenerator.
      _supported = defaultTargetPlatform == TargetPlatform.iOS;
      return;
    }
    _supported = await Vibration.hasVibrator();
    if (_supported) {
      _amplitudeControl = await Vibration.hasAmplitudeControl();
    }
  }

  static void setEnabled(bool value) => _enabled = value;

  // ── Impacts ────────────────────────────────────────────────────────────────

  /// Selection tick — a discrete detent crossed in a continuous control.
  static void selection() {
    if (!enabled) return;
    if (_amplitudeControl) {
      Vibration.vibrate(duration: 12, amplitude: 70);
    } else {
      Vibration.vibrate(duration: 10);
    }
    HapticFeedback.selectionClick();
  }

  /// `.light` — small item pick, chip toggle.
  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    if (_amplitudeControl) Vibration.vibrate(duration: 14, amplitude: 90);
  }

  /// `.medium` — the default for a button press or a card landing.
  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    if (_amplitudeControl) Vibration.vibrate(duration: 22, amplitude: 150);
  }

  /// `.heavy` — a large element snapping into place, a phase change.
  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    if (_amplitudeControl) Vibration.vibrate(duration: 34, amplitude: 220);
  }

  /// `.rigid` — a hard stop. Used when a run's distance target is met.
  static void rigid() {
    if (!enabled) return;
    if (_amplitudeControl) {
      Vibration.vibrate(duration: 16, amplitude: 255);
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        Vibration.vibrate(duration: 16, amplitude: 255);
      });
    } else {
      Vibration.vibrate(pattern: const [16, 90, 16]);
    }
    HapticFeedback.heavyImpact();
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// Two ascending taps — "you're done, that worked".
  static void success() {
    if (!enabled) return;
    if (_amplitudeControl) {
      Vibration.vibrate(
        pattern: const [18, 70, 18],
        intensities: const [0, 120, 200],
        sharpness: 0.6,
      );
    } else {
      Vibration.vibrate(pattern: const [18, 70, 18], sharpness: 0.6);
    }
    HapticFeedback.mediumImpact();
  }

  /// Mid-weight double tap — a state the user should notice but not panic at.
  static void warning() {
    if (!enabled) return;
    if (_amplitudeControl) {
      Vibration.vibrate(
        pattern: const [22, 60, 22],
        intensities: const [0, 180, 120],
        sharpness: 0.5,
      );
    } else {
      Vibration.vibrate(pattern: const [22, 60, 22], sharpness: 0.5);
    }
    HapticFeedback.mediumImpact();
  }

  /// Three rapid taps.
  static void error() {
    if (!enabled) return;
    Vibration.vibrate(pattern: const [20, 55, 20, 55, 20], sharpness: 0.9);
    HapticFeedback.heavyImpact();
  }

  /// The countdown "beep". Deliberately *not* heavy: at a three-minute interval
  /// this can fire dozens of times per run, and a hard buzz each time would
  /// feel like an alarm. A soft, dull double-tap carries the information —
  /// low sharpness is what stops it grating when it repeats.
  static void countdownTick() {
    if (!enabled) return;
    if (_amplitudeControl) {
      Vibration.vibrate(duration: 20, amplitude: 60, sharpness: 0.25);
    } else {
      Vibration.vibrate(duration: 18, sharpness: 0.25);
    }
  }

  /// Fires once when an interval flips run <-> walk. Heavier than a tick
  /// because it is the single most important moment in the workout.
  static void phaseChange() {
    if (!enabled) return;
    if (_amplitudeControl) {
      Vibration.vibrate(
        pattern: const [40, 80, 40],
        intensities: const [0, 230, 130],
        sharpness: 0.75,
      );
    } else {
      Vibration.vibrate(pattern: const [40, 80, 40], sharpness: 0.75);
    }
    HapticFeedback.heavyImpact();
  }

  /// Stop any in-flight vibration (used when a run is paused or abandoned).
  static void cancel() {
    if (!_supported || _enabled == false) return;
    Vibration.cancel();
  }
}
