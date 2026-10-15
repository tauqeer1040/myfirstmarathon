import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Type stack.
///
/// `Anton` carries every oversized numeral and label — it is the condensed
/// heavy grotesk that gives the reference screens their poster-like weight.
/// `Barlow` is the workhorse UI face; `BarlowCondensed` handles small caps
/// labels and stat readouts where horizontal space is at a premium.
abstract final class AppType {
  static const String display = 'Anton';
  static const String body = 'Barlow';
  static const String condensed = 'BarlowCondensed';

  /// Hero numeral — e.g. `6.8` on the run home, `16` on stats.
  static TextStyle hero(BuildContext context, {double size = 132}) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      height: 0.86,
      letterSpacing: -size * 0.012,
      color: AppPalette.ink,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// The unit that rides baseline-aligned with the hero numeral (`KM`).
  static TextStyle heroUnit({double size = 44}) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      height: 0.9,
      letterSpacing: 0.4,
      color: AppPalette.ink,
    );
  }

  /// Small-caps eyebrow above a numeral — `LONG RUN`.
  ///
  /// This is the app's one typographic tic, inherited from the reference. Keep
  /// it to the single line that names the thing on screen; stacking a second
  /// one below the first is decoration, not information.
  static TextStyle eyebrow({double size = 15}) {
    return TextStyle(
      fontFamily: condensed,
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      height: 1.1,
      color: AppPalette.ink,
    );
  }

  /// Secondary / metadata text.
  ///
  /// Never below 11pt — that's the legibility floor for a phone held at arm's
  /// length in daylight, halfway through a run. Never lighter than 0.72 alpha
  /// on the chroma fields, or it stops being grey and starts being invisible.
  static TextStyle label({double size = 12, Color? color}) {
    return TextStyle(
      fontFamily: body,
      fontSize: size < 11 ? 11 : size,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.2,
      color: color ?? AppPalette.ink.withValues(alpha: 0.74),
    );
  }

  static TextStyle stat({double size = 26}) {
    return TextStyle(
      fontFamily: condensed,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.0,
      color: AppPalette.ink,
    );
  }

  static TextStyle bodyText({
    double size = 15,
    Color? color,
    double? height,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return TextStyle(
      fontFamily: body,
      fontSize: size,
      fontWeight: fontWeight,
      height: height ?? 1.35,
      color: color ?? AppPalette.ink,
    );
  }

  static TextStyle buttonLabel({double size = 17}) {
    return TextStyle(
      fontFamily: body,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      height: 1.0,
      color: AppPalette.ink,
    );
  }
}

ThemeData buildThemeFor(AppPalette palette) {
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.surface,
    brightness: Brightness.dark,
  ).copyWith(
    surface: palette.surface,
    onSurface: palette.onSurface,
    primary: palette.accent,
    onPrimary: palette.onAccent,
    outline: palette.outline,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.surface,
    fontFamily: AppType.body,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _ExpressivePageTransitionsBuilder(),
        TargetPlatform.iOS: _ExpressivePageTransitionsBuilder(),
      },
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppType.label(
          size: 10.5,
          color: states.contains(WidgetState.selected)
              ? AppPalette.ink
              : AppPalette.ink.withValues(alpha: 0.62),
        ),
      ),
    ),
  );
}

/// Shared-axis style transitions: the outgoing page slides and fades while the
/// incoming one leads slightly, which reads as depth without the horizontal
/// "card swipe" of the platform default.
class _ExpressivePageTransitionsBuilder extends PageTransitionsBuilder {
  const _ExpressivePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: M3EMotion.emphasized,
      reverseCurve: M3EMotion.emphasizedAccelerate,
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: M3EMotion.emphasizedAccelerate,
    );

    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(enter),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0, -0.025),
          ).animate(exit),
          child: child,
        ),
      ),
    );
  }
}
