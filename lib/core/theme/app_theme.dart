import 'package:flutter/material.dart';

/// Motion tokens inspired by Material 3 Expressive.
///
/// Everything that moves in this app resolves a spring (or an emphasized
/// easing curve) from here — no ad-hoc `Duration`s scattered through widgets.
/// Springs are interruptible: a gesture can retarget an in-flight animation
/// without a velocity discontinuity, which fixed-duration curves cannot do.
abstract final class M3EMotion {
  // ── Spatial springs ────────────────────────────────────────────────────────
  /// Snappy, for state flips that must feel instantaneous (chips, toggles).
  static final SpringDescription fast = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1400,
    ratio: 0.72,
  );

  /// The workhorse. Buttons, nav selections, small layout shifts.
  static final SpringDescription defaultSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.82,
  );

  /// Large travel — sheets expanding, cards morphing, hero transitions.
  static final SpringDescription slow = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 210,
    ratio: 0.86,
  );

  /// Bouncy. Reserved for celebration and reward moments only. Apple-style
  /// restraint: bounce is a seasoning, not the base flavor.
  static final SpringDescription bouncy = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 320,
    ratio: 0.55,
  );

  // ── Effect springs ─────────────────────────────────────────────────────────
  static final SpringDescription effects = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 900,
    ratio: 0.9,
  );

  // ── Emphasis curves (non-spring, for one-shot property tweens) ─────────────
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);

  /// A single overshoot-and-settle, for controls that are physically *pushed*
  /// (a switch knob, a card flicked aside). Reserved — most motion here should
  /// use a spring or [emphasized] instead.
  static const Curve springy = Cubic(0.34, 1.42, 0.64, 1.0);

  // ── Durations ──────────────────────────────────────────────────────────────
  static const Duration short2 = Duration(milliseconds: 100);
  static const Duration short4 = Duration(milliseconds: 200);
  static const Duration medium2 = Duration(milliseconds: 300);
  static const Duration medium4 = Duration(milliseconds: 400);
  static const Duration long2 = Duration(milliseconds: 500);
  static const Duration extraLong = Duration(milliseconds: 700);

  /// Stagger between siblings in a list reveal. 20–40ms reads as "these
  /// belong together"; much beyond that and the list feels like it is loading.
  static const Duration stagger = Duration(milliseconds: 34);
}

/// Shape tokens. M3 Expressive leans on generously-rounded, "squircle"-ish
/// geometry and on shapes that morph rather than swap.
abstract final class M3EShape {
  /// Pill / stadium.
  static const BorderRadius full = BorderRadius.all(Radius.circular(999));

  /// The house corner radius for cards and sheets.
  static const BorderRadius card = BorderRadius.all(Radius.circular(28));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(36));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(20));
  static const BorderRadius small = BorderRadius.all(Radius.circular(12));
}

/// Which color world a screen is living in. The reference app uses two
/// distinct, high-chroma fields — a warm red for "run" and a deep blue for
/// "stats" — and switching between them is a deliberate identity change rather
/// than a light/dark flip.
enum PaletteKind { ember, cobalt }

/// The full color contract for a palette.
@immutable
class AppPalette {
  const AppPalette({
    required this.kind,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerLow,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.accent,
    required this.onAccent,
    required this.scrim,
  });

  final PaletteKind kind;

  /// The full-bleed background field.
  final Color surface;

  /// Nav bar / chip resting color.
  final Color surfaceContainer;

  /// Raised elements: nav bar, cards lifted off the field.
  final Color surfaceContainerHigh;

  /// Recessed wells: track grooves, inactive segments.
  final Color surfaceContainerLow;

  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;

  /// The single hot accent (playheads, active states, the ruler bracket).
  final Color accent;

  /// Text/icon color that sits on top of [accent].
  final Color onAccent;

  /// Used for map tiles and route strokes so they belong to the palette.
  final Color scrim;

  static const AppPalette ember = AppPalette(
    kind: PaletteKind.ember,
    surface: Color(0xFFB22A1F),
    surfaceContainer: Color(0xFFC43A2C),
    surfaceContainerHigh: Color(0xFF8E2118),
    surfaceContainerLow: Color(0xFF98251B),
    onSurface: ink,
    onSurfaceVariant: Color(0xFFFFDAD3),
    outline: Color(0x3DFFFFFF),
    accent: Color(0xFFFF6B57),
    onAccent: Color(0xFF3A0A04),
    scrim: Color(0xFFFF8A75),
  );

  static const AppPalette cobalt = AppPalette(
    kind: PaletteKind.cobalt,
    surface: Color(0xFF1B3CA0),
    surfaceContainer: Color(0xFF2A4FBE),
    surfaceContainerHigh: Color(0xFF12307F),
    surfaceContainerLow: Color(0xFF163494),
    onSurface: ink,
    onSurfaceVariant: Color(0xFFCAD8FF),
    outline: Color(0x3DFFFFFF),
    // Cobalt's accent is the *other* red — the ruler bracket in the reference.
    accent: Color(0xFFFF4A38),
    onAccent: Color(0xFF3A0A04),
    scrim: Color(0xFF9FB6FF),
  );

  static AppPalette of(PaletteKind kind) =>
      kind == PaletteKind.ember ? ember : cobalt;

  /// Ink on a chroma field — the only text colour either palette uses. The
  /// reference screens are monochrome-on-chroma, and it reads far stronger than
  /// tinted text would.
  static const Color ink = Color(0xFFFFFFFF);

  // ── Const-usable colour handles ───────────────────────────────────────────
  // Dart's const evaluator cannot read instance fields, so widgets that need a
  // `const` BoxDecoration pull the raw colour from here instead. These are the
  // same values as the palettes above, kept adjacent so they can't drift.

  static const Color emberSurface = Color(0xFFB22A1F);
  static const Color emberHigh = Color(0xFF8E2118);
  static const Color emberContainer = Color(0xFFC43A2C);
  static const Color emberLow = Color(0xFF98251B);
  static const Color emberAccent = Color(0xFFFF6B57);

  static const Color cobaltSurface = Color(0xFF1B3CA0);
  static const Color cobaltHigh = Color(0xFF12307F);
  static const Color cobaltContainer = Color(0xFF2A4FBE);
  static const Color cobaltLow = Color(0xFF163494);
  static const Color cobaltAccent = Color(0xFFFF4A38);
}

/// Ambient background treatment.
///
/// Deliberately almost nothing: a single flat field with one very shallow
/// vertical falloff so large areas don't band on OLED. The richness in this app
/// comes from the colour field itself and from line-drawn route geometry — not
/// from radial blooms floating behind content, which read as decoration and age
/// the screen.
class FieldBackground extends StatelessWidget {
  const FieldBackground({
    required this.palette,
    required this.child,
    super.key,
  });

  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(palette.surface, Colors.white, 0.035)!,
            palette.surface,
            Color.lerp(palette.surface, Colors.black, 0.09)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
