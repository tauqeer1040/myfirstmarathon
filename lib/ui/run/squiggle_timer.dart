import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import '../widgets/glyphs.dart';

/// The run/walk countdown face.
///
/// Material 3 Expressive's signature move is the *squiggle*: a wavy stroke used
/// for indeterminate and determinate progress. Here it carries the interval
/// countdown — the wave "fills" left to right as the block elapses, and the
/// head of the fill rides the crest of the wave rather than sitting on a flat
/// baseline. Layered underneath it is the block phase, the schedule of pips,
/// and the numerals.
class SquiggleTimer extends StatefulWidget {
  const SquiggleTimer({
    required this.phaseLabel,
    required this.remaining,
    required this.progress,
    required this.palette,
    required this.active,
    this.cycleLabel,
    this.pips = const [],
    this.activePip = 0,
    this.secondaryLine,
    this.onTapFace,
    super.key,
  });

  final String phaseLabel;
  final Duration remaining;
  final double progress;
  final AppPalette palette;
  final bool active;

  /// e.g. `Block 3 of 8`
  final String? cycleLabel;

  /// One entry per block in the run/walk pattern.
  final List<Phase> pips;
  final int activePip;

  final String? secondaryLine;
  final VoidCallback? onTapFace;

  @override
  State<SquiggleTimer> createState() => _SquiggleTimerState();
}

class _SquiggleTimerState extends State<SquiggleTimer> with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _wave.repeat();
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _wave.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.phaseLabel == 'WALK' ? widget.palette.scrim : widget.palette.accent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final faceHeight = (constraints.maxHeight * 0.56).clamp(150.0, 230.0);
        final numSize = (faceHeight * 0.62).clamp(64.0, 132.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Face ────────────────────────────────────────────────────────
            SizedBox(
              height: faceHeight,
              child: GestureDetector(
                onTap: widget.onTapFace,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_wave, _pulse]),
                  builder: (context, _) => CustomPaint(
                    painter: _SquigglePainter(
                      progress: widget.progress,
                      wavePhase: _wave.value,
                      pulse: _pulse.value,
                      groove: widget.palette.onSurface.withValues(alpha: 0.20),
                      fill: accent,
                      head: AppPalette.ink,
                      running: widget.active,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: faceHeight * 0.06),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PhaseBadge(
                              label: widget.phaseLabel,
                              accent: accent,
                              active: widget.active,
                              pulse: _pulse.value,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Fmt.countdown(widget.remaining),
                              style: AppType.hero(context, size: numSize),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Block schedule pips ─────────────────────────────────────────
            if (widget.pips.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PhasePips(
                phases: widget.pips,
                active: widget.activePip,
                progress: widget.progress,
                palette: widget.palette,
              ),
            ],

            if (widget.cycleLabel != null || widget.secondaryLine != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.secondaryLine ?? widget.cycleLabel!,
                textAlign: TextAlign.center,
                style: AppType.label(size: 12.5, color: widget.palette.onSurfaceVariant),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({
    required this.label,
    required this.accent,
    required this.active,
    this.pulse = 0,
  });

  final String label;
  final Color accent;
  final bool active;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: M3EMotion.medium2,
      curve: M3EMotion.emphasized,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: active ? 0.22 : 0.10),
        borderRadius: M3EShape.full,
        border: Border.all(color: accent.withValues(alpha: active ? 0.85 : 0.35), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: accent, pulse: active ? pulse : 0),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppType.eyebrow(size: 13).copyWith(letterSpacing: 2.4),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.pulse = 0});

  final Color color;

  /// 0..1 breathing value, driven by the parent's controller.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5 * (1 - pulse)),
            blurRadius: 8,
            spreadRadius: 3,
          ),
        ],
      ),
    );
  }
}

/// The block schedule as a run of dots — filled for elapsed, ringed for
/// upcoming, oversized for the current one. Reads at a glance which block of
/// the pattern you're in and how much is left after it.
class _PhasePips extends StatelessWidget {
  const _PhasePips({
    required this.phases,
    required this.active,
    required this.progress,
    required this.palette,
  });

  final List<Phase> phases;
  final int active;
  final double progress;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < phases.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.5),
              child: _Pip(
                phase: phases[i],
                state: i < active
                    ? _PipState.done
                    : (i == active ? _PipState.current : _PipState.upcoming),
                progress: i == active ? progress : (i < active ? 1 : 0),
                palette: palette,
              ),
            ),
        ],
      ),
    );
  }
}

enum _PipState { done, current, upcoming }

class _Pip extends StatelessWidget {
  const _Pip({
    required this.phase,
    required this.state,
    required this.progress,
    required this.palette,
  });

  final Phase phase;
  final _PipState state;
  final double progress;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final isRun = phase == Phase.run;
    final color = isRun ? palette.accent : palette.scrim;
    final d = switch (state) {
      _PipState.current => 20.0,
      _PipState.done => 11.0,
      _PipState.upcoming => 9.0,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: d * 0.6, end: d),
      duration: M3EMotion.medium2,
      curve: M3EMotion.emphasizedDecelerate,
      builder: (context, size, _) => SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: state == _PipState.current
                ? CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 3,
                    backgroundColor: color.withValues(alpha: 0.22),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state == _PipState.done
                          ? color
                          : color.withValues(alpha: 0.18),
                      border: state == _PipState.done
                          ? null
                          : Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({
    required this.progress,
    required this.wavePhase,
    required this.pulse,
    required this.groove,
    required this.fill,
    required this.head,
    required this.running,
  });

  final double progress;
  final double wavePhase;
  final double pulse;
  final Color groove;
  final Color fill;
  final Color head;
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    const amplitude = 7.0;
    const wavelength = 46.0;
    final y = size.height * 0.62;
    final p = progress.clamp(0.0, 1.0);
    final headX = size.width * p;

    // ── Groove: the full-length track the wave travels along ────────────────
    final groovePath = Squiggle.path(
      width: size.width,
      height: size.height,
      y: y,
      amplitude: amplitude,
      wavelength: wavelength,
      phase: wavePhase,
    );
    canvas.drawPath(
      groovePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = groove,
    );

    // ── Fill: the elapsed portion ──────────────────────────────────────────
    if (p > 0.001) {
      final fillPath = Squiggle.path(
        width: size.width,
        height: size.height,
        y: y,
        amplitude: amplitude,
        wavelength: wavelength,
        phase: wavePhase,
        endX: headX,
      );
      canvas.drawPath(
        fillPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round
          ..color = fill,
      );

      // A brighter, thinner core inside the fill gives the wave depth.
      canvas.drawPath(
        fillPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = head.withValues(alpha: 0.85),
      );
    }

    // ── Head: a bright bead riding the crest, breathing while the clock runs ─
    if (p > 0.001) {
      final headY = y + math.sin((headX / wavelength + wavePhase) * 2 * math.pi) * amplitude;
      final r = 5.5 + (running ? pulse * 1.4 : 0);
      canvas.drawCircle(Offset(headX, headY), r, Paint()..color = head);
    }
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.progress != progress || old.wavePhase != wavePhase || old.pulse != pulse;
}

/// The indeterminate squiggle used on the share card and the loading state —
/// the M3 Expressive "loading" wave.
class IndeterminateSquiggle extends StatefulWidget {
  const IndeterminateSquiggle({this.color = AppPalette.ink, this.height = 6, super.key});

  final Color color;
  final double height;

  @override
  State<IndeterminateSquiggle> createState() => _IndeterminateSquiggleState();
}

class _IndeterminateSquiggleState extends State<IndeterminateSquiggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _IndeterminatePainter(t: _c.value, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _IndeterminatePainter extends CustomPainter {
  _IndeterminatePainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const amplitude = 4.0;
    const wavelength = 30.0;
    final y = size.height / 2;
    final head = t * (size.width + 140) - 70;

    canvas.drawPath(
      Squiggle.path(
        width: size.width,
        height: size.height,
        y: y,
        amplitude: amplitude,
        wavelength: wavelength,
        phase: t * 0.6,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.28),
    );

    canvas.drawPath(
      Squiggle.path(
        width: size.width,
        height: size.height,
        y: y,
        amplitude: amplitude,
        wavelength: wavelength,
        phase: t * 0.6,
        startX: (head - 110).clamp(0.0, size.width),
        endX: head.clamp(0.0, size.width),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_IndeterminatePainter old) => old.t != t;
}
