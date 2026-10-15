import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/spring.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';

/// Press feedback that follows the Apple rule exactly: compress fast on
/// touch-down (~80ms, ease-in), spring back on release (~300ms, overshoot).
/// The press state appears on `pointerdown`, not `tap`, so the response is
/// sub-frame and the control never feels laggy.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.955,
    this.dimOpacity = 0.0,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final double dimOpacity;

  /// Set false for controls that live inside a parent that already fires the
  /// matching haptic — avoids the double-fire anti-pattern.
  final bool haptic;
  final HitTestBehavior behavior;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  /// Unbounded so the release spring can overshoot past 0 — that sub-1%
  /// counter-overshoot on scale is the entire "physical button" illusion.
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setDown(bool down) {
    if (!_enabled) return;
    // Compress fast and hard; release slow and springy.
    if (down) {
      _c.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOutCubic);
    } else {
      _c.springTo(0, spring: M3EMotion.fast);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: _enabled
            ? () {
                if (widget.haptic) Haptics.light();
                widget.onTap?.call();
              }
            : null,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                if (widget.haptic) Haptics.medium();
                widget.onLongPress!();
              },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value.clamp(0.0, 1.0);
            final s = 1 - (1 - widget.scale) * t;
            return widget.dimOpacity > 0
                ? Opacity(opacity: 1 - widget.dimOpacity * t, child: Transform.scale(scale: s, child: child))
                : Transform.scale(scale: s, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// The signature control: a full-width white pill carrying a colored glyph and
/// a colored label. Present on every screen in the reference — it is the app's
/// single primary action and reads as the same object everywhere.
///
/// It is the *only* control in the app that casts a shadow. Depth is the
/// navigation layer's job; everything else separates through the colour field.
class PrimaryPill extends StatelessWidget {
  const PrimaryPill({
    required this.label,
    required this.onPressed,
    this.icon,
    this.palette = AppPalette.ember,
    this.height = 60,
    this.showGlyph = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final AppPalette palette;
  final double height;
  final bool showGlyph;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppPalette.ink,
          borderRadius: M3EShape.full,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && showGlyph) ...[
              Icon(icon, size: height * 0.36, color: palette.surface),
              const SizedBox(width: 12),
            ],
            Text(
              label.toUpperCase(),
              style: AppType.buttonLabel(size: height * 0.29)
                  .copyWith(color: palette.surface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular translucent icon button used for the top-corner affordances.
class CircleAction extends StatelessWidget {
  const CircleAction({
    required this.icon,
    required this.onPressed,
    this.size = 46,
    this.iconSize = 21,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: 0.9,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppPalette.ink.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.ink.withValues(alpha: 0.22), width: 1),
        ),
        child: Icon(icon, size: iconSize, color: AppPalette.ink),
      ),
    );
  }
}

/// A value that springs toward its target instead of tweening linearly. Used
/// for numerals and progress so a state change reads as a physical response.
class SpringValue extends StatefulWidget {
  const SpringValue({
    required this.target,
    required this.builder,
    this.spring,
    super.key,
  });

  final double target;
  final Widget Function(BuildContext context, double value, double velocity) builder;

  /// Defaults to the house spatial spring when omitted — it can't be a
  /// parameter default because SpringDescription isn't const-constructible.
  final SpringDescription? spring;

  SpringDescription get _spring => spring ?? M3EMotion.defaultSpring;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.target,
  );

  @override
  void didUpdateWidget(SpringValue old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _c.springTo(widget.target, spring: widget._spring);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(context, _c.value, _c.velocity),
    );
  }
}
