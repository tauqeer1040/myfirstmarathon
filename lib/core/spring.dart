import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Spring-driven animation for [AnimationController].
///
/// Flutter ships [SpringSimulation] but no convenience wrapper, and a spring is
/// the only way to get interruptible, velocity-preserving motion — which is the
/// entire reason this app's transitions feel like objects rather than
/// crossfades. Retargeting mid-flight works here: call [springTo] again and the
/// new simulation inherits the controller's current position *and* velocity, so
/// the motion never jumps.
extension SpringAnimation on AnimationController {
  /// Springs [target], optionally seeded with the velocity of an in-flight
  /// gesture so momentum carries across the hand-off.
  TickerFuture springTo(
    double target, {
    SpringDescription spring = const SpringDescription(mass: 1, stiffness: 380, damping: 26),
    double velocity = 0,
    Tolerance tolerance = Tolerance.defaultTolerance,
  }) {
    return animateWith(
      SpringSimulation(spring, value, target, velocity, tolerance: tolerance),
    );
  }
}
