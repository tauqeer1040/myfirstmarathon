import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/run_engine.dart';
import '../widgets/aurora.dart';
import '../widgets/controls.dart';
import '../widgets/signature_path.dart';
import 'settings_sheet.dart';

/// The run home — the red field from the reference.
///
/// Everything here is one object: the workout you are about to do, expressed as
/// a target distance, the shape of the ground you'll cover, the three numbers
/// that will matter, and one button.
class RunHomeScreen extends ConsumerWidget {
  const RunHomeScreen({this.workout, super.key});

  /// When null, the screen points at the next unfinished workout in the plan.
  final Workout? workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.ember;
    final target = workout ?? ref.watch(nextWorkoutProvider);
    final run = ref.watch(runEngineProvider);
    final signature = ref.watch(signatureProvider);
    final busy = run.isActive || run.isPaused;

    return AuroraBackground(
      palette: palette,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(target: target, onSettings: () => showSettingsSheet(context)),
              const SizedBox(height: 26),

              // ── The number ──────────────────────────────────────────────
              _HeroDistance(
                km: busy ? run.distanceKm : (target?.targetKm ?? 0),
                label: target?.title ?? 'Free Run',
              ),

              const SizedBox(height: 18),

              // ── The ground you'll cover ─────────────────────────────────
              // Takes all the slack rather than sitting in a fixed band, so the
              // route is the largest thing on the screen after the number and
              // there is no dead air between the two.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SignaturePath(
                        signature: signature,
                        color: palette.onSurface,
                        strokeWidth: 3.0,
                        fallback: PlaceholderRoute(color: palette.onSurface),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      signature.hasHistory
                          ? 'Your usual route · ${signature.routeCount} runs'
                          : (signature.totalKm > 0
                              ? 'Your route forms as you log runs'
                              : 'Your route draws itself here'),
                      style: AppType.label(size: 12, color: palette.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── The three numbers ───────────────────────────────────────
              _StatsRow(run: run, target: target),
              const SizedBox(height: 18),

              PrimaryPill(
                label: busy ? 'Resume' : 'Start',
                icon: busy ? Icons.play_arrow_rounded : Icons.play_arrow_rounded,
                palette: palette,
                onPressed: target == null && !busy
                    ? () {}
                    : () => _onStartPressed(context, ref, target, busy),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _onStartPressed(BuildContext context, WidgetRef ref, Workout? target, bool busy) {
    final engine = ref.read(runEngineProvider.notifier);
    if (busy) {
      if (ref.read(runEngineProvider).isPaused) {
        engine.resume();
      } else {
        engine.pause();
      }
      return;
    }
    if (target == null) return;
    Navigator.of(context).pushNamed('/run');
    engine.start(target);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.target, required this.onSettings});

  final Workout? target;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final done = target == null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'ALL DONE' : (target!.title.toUpperCase()),
                  style: AppType.eyebrow(size: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  target?.goalLabel ?? 'Log a free run',
                  style: AppType.label(size: 12, color: AppPalette.ink.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
        CircleAction(icon: Icons.tune_rounded, onPressed: onSettings, semanticLabel: 'Settings'),
      ],
    );
  }
}

/// The oversized numeral plus its unit, baseline-aligned the way the reference
/// does it — `6.8` towering next to a small `KM` sitting on the same line.
class _HeroDistance extends StatelessWidget {
  const _HeroDistance({required this.km, required this.label});

  final double km;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The value springs when it changes rather than cutting.
        SpringValue(
          target: km,
          builder: (context, value, _) => Text(
            Fmt.km(value),
            style: AppType.hero(context, size: 116),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('KM', style: AppType.heroUnit(size: 34)),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.run, required this.target});

  final RunState run;
  final Workout? target;

  @override
  Widget build(BuildContext context) {
    final live = run.isActive || run.isPaused || run.isFinished;

    final pace = live ? run.livePaceSecPerKm : null;
    final time = live ? run.elapsed : (target?.totalTime ?? Duration.zero);
    final calories = live
        ? run.calories
        : _estimateCalories(target);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Not three equal columns. On an interval workout the clock is the
        // number you actually steer by, so it gets the weight; pace and
        // calories step down to a supporting tier.
        Expanded(
          flex: 3,
          child: _Stat(
            value: Fmt.clock(time),
            label: 'Time',
            size: 30,
            unit: live && run.isActive ? 'live' : null,
            highlight: live,
          ),
        ),
        _divider(),
        Expanded(
          flex: 2,
          child: _Stat(
            value: live ? (Fmt.pace(pace) ?? '—') : '—',
            label: 'Pace /km',
            size: 21,
          ),
        ),
        _divider(),
        Expanded(
          flex: 2,
          child: _Stat(value: '$calories', label: 'Calories', size: 21),
        ),
      ],
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          width: 1,
          height: 34,
          margin: const EdgeInsets.only(top: 4),
          color: AppPalette.ink.withValues(alpha: 0.18),
        ),
      );

  static int _estimateCalories(Workout? w) {
    if (w == null) return 0;
    final met = w.runTime.inSeconds > 0 ? 9.8 : 6.0;
    return (met * 70 * (w.totalTime.inMilliseconds / 3600000)).round();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.size = 24,
    this.unit,
    this.highlight = false,
  });

  final String value;
  final String label;
  final double size;
  final String? unit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: M3EMotion.medium2,
          style: AppType.stat(size: size),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.fade, softWrap: false)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: AppType.label(size: 11, color: AppPalette.ink.withValues(alpha: 0.72)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: AppType.label(size: 11)),
      ],
    );
  }
}
