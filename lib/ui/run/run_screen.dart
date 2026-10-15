import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import '../../state/run_engine.dart';
import '../widgets/controls.dart';
import '../widgets/run_map.dart';
import 'squiggle_timer.dart';

/// The workout screen: map on top, interval countdown underneath.
///
/// The map is the reason the app exists, so it gets the top of the screen and
/// an uninterrupted view. The timer is a squiggle because that is what M3
/// Expressive uses for progress, and because a wave reads as *flowing* — the
/// opposite of the stopwatch dread this app is meant to remove.
class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  final Map<String, GlobalKey> _mapKeys = {};
  bool _mapVisible = true;

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runEngineProvider);
    final engine = ref.read(runEngineProvider.notifier);
    final palette = AppPalette.ember;

    // Nothing loaded (deep link, or state was reset) — don't strand the user.
    if (run.isIdle) {
      return const _NothingToRun();
    }

    final accent = run.phase == Phase.walk ? palette.scrim : palette.accent;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quit = await _confirmAbandon(context);
        if (quit) {
          engine.reset();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: palette.surface,
        body: FieldBackground(
          palette: palette,
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: run.workout?.title ?? 'Free Run',
                  subtitle: run.isFinished ? 'Finished' : null,
                  onClose: () async {
                    final quit = await _confirmAbandon(context, finishing: false);
                    if (!quit) return;
                    await engine.finish();
                    engine.reset();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  onToggleMap: () => setState(() => _mapVisible = !_mapVisible),
                  mapVisible: _mapVisible,
                ),

                // ── Map ────────────────────────────────────────────────────
                AnimatedSize(
                  duration: M3EMotion.medium4,
                  curve: M3EMotion.emphasized,
                  child: _mapVisible
                      ? SizedBox(
                          height: MediaQuery.of(context).size.height * 0.34,
                          child: RunMap(
                            key: _mapKeys['map'],
                            route: run.route,
                            accent: accent,
                            follow: run.isActive,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),

                // ── Live readouts ─────────────────────────────────────────
                _LiveRow(run: run, accent: accent),

                // ── Timer face ────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: SquiggleTimer(
                      phaseLabel: run.isFinished ? 'DONE' : run.phase.label,
                      remaining: run.intervalRemaining,
                      progress: run.intervalProgress,
                      palette: palette,
                      active: run.isActive,
                      pips: run.schedule.map((e) => e.phase).toList(),
                      activePip: run.schedule.isEmpty ? 0 : run.intervalIndex % run.schedule.length,
                      secondaryLine: run.isOpenEnded
                          ? 'Open run · ${run.distanceKm.toStringAsFixed(2)} of ${run.targetKm.toStringAsFixed(1)} km'
                          : (run.schedule.isEmpty
                              ? null
                              : 'Block ${(run.intervalIndex % run.schedule.length) + 1} of ${run.schedule.length}'
                                  '${run.cycles > 0 ? '  ·  cycle ${run.cycles + 1}' : ''}'),
                      onTapFace: () => run.isActive
                          ? engine.pause()
                          : (run.isPaused ? engine.resume() : null),
                    ),
                  ),
                ),

                // ── Distance goal bar ─────────────────────────────────────
                if (!run.isOpenEnded && run.targetKm > 0)
                  _DistanceBar(run: run),

                // ── Controls ───────────────────────────────────────────────
                _Controls(
                  run: run,
                  accent: accent,
                  onSkip: run.isActive ? engine.skipInterval : null,
                  onToggle: run.isFinished
                      ? null
                      : () => run.isActive ? engine.pause() : engine.resume(),
                  onFinish: run.isFinished ? null : () => _finish(context, engine),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, RunEngine engine) async {
    final confirmed = await _confirmFinish(context);
    if (!confirmed || !context.mounted) return;
    final record = await engine.finish();
    if (!context.mounted) return;
    if (record == null) return;
    await Navigator.of(context).pushReplacementNamed('/summary', arguments: record);
  }

  Future<bool> _confirmFinish(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Finish this run?',
        body: 'Your route and stats are saved to your history.',
        confirm: 'Finish',
        cancel: 'Keep going',
      ),
    );
    return res ?? false;
  }

  Future<bool> _confirmAbandon(BuildContext context, {bool finishing = true}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: finishing ? 'Leave the run?' : 'Abandon this run?',
        body: finishing
            ? 'You can come back to it from the home screen.'
            : 'This run will not be saved to your history.',
        confirm: 'Leave',
        cancel: 'Stay',
        destructive: true,
      ),
    );
    return res ?? false;
  }
}

class _NothingToRun extends ConsumerWidget {
  const _NothingToRun();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppPalette.emberSurface,
      body: FieldBackground(
        palette: AppPalette.ember,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No run in progress', style: AppType.eyebrow(size: 16)),
                  const SizedBox(height: 18),
                  PrimaryPill(
                    label: 'Back',
                    palette: AppPalette.ember,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.onToggleMap,
    required this.mapVisible,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final VoidCallback onToggleMap;
  final bool mapVisible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        children: [
          CircleAction(
            icon: Icons.close_rounded,
            onPressed: onClose,
            size: 42,
            iconSize: 20,
            semanticLabel: 'Close',
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(title.toUpperCase(), style: AppType.eyebrow(size: 13)),
                  if (subtitle != null)
                    Text(subtitle!, style: AppType.label(size: 11)),
                ],
              ),
            ),
          ),
          CircleAction(
            icon: mapVisible ? Icons.map_rounded : Icons.terrain_rounded,
            onPressed: onToggleMap,
            size: 42,
            iconSize: 20,
            semanticLabel: 'Toggle map',
          ),
        ],
      ),
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.run, required this.accent});

  final RunState run;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pace = Fmt.pace(run.livePaceSecPerKm);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpringValue(
                  target: run.distanceKm,
                  builder: (context, v, _) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(v.toStringAsFixed(2), style: AppType.hero(context, size: 46)),
                      const SizedBox(width: 5),
                      Text('KM', style: AppType.heroUnit(size: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _metric(pace ?? '—', 'Pace /km'),
          const SizedBox(width: 18),
          _metric(Fmt.clock(run.elapsed), 'Elapsed'),
          const SizedBox(width: 18),
          _metric('${run.calories}', 'Cal'),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value, style: AppType.stat(size: 19)),
          const SizedBox(height: 1),
          Text(label, style: AppType.label(size: 9.5)),
        ],
      );
}

class _DistanceBar extends StatelessWidget {
  const _DistanceBar({required this.run});

  final RunState run;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpringValue(
            target: run.distanceProgress,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(height: 6, color: AppPalette.ink.withValues(alpha: 0.14)),
                  FractionallySizedBox(
                    widthFactor: v.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: run.distanceReached ? AppPalette.ink : AppPalette.emberAccent,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(999)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                run.distanceReached
                    ? 'TARGET REACHED'
                    : '${(run.targetKm - run.distanceKm).clamp(0, 999).toStringAsFixed(2)} km to go',
                style: AppType.label(size: 11, color: AppPalette.ink.withValues(alpha: 0.7)),
              ),
              const Spacer(),
              Text(
                '${(run.distanceProgress * 100).round()}%',
                style: AppType.stat(size: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.run,
    required this.accent,
    required this.onSkip,
    required this.onToggle,
    required this.onFinish,
  });

  final RunState run;
  final Color accent;
  final VoidCallback? onSkip;
  final VoidCallback? onToggle;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundButton(
            icon: Icons.skip_next_rounded,
            onPressed: onSkip,
            size: 54,
            semanticLabel: 'Skip to next block',
          ),
          _RoundButton(
            icon: run.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onPressed: onToggle,
            size: 76,
            filled: true,
            fill: run.isActive ? AppPalette.emberHigh : AppPalette.ink,
            iconColor: run.isActive ? AppPalette.ink : AppPalette.emberSurface,
            semanticLabel: run.isActive ? 'Pause' : 'Resume',
          ),
          _RoundButton(
            icon: Icons.stop_rounded,
            onPressed: onFinish,
            size: 54,
            semanticLabel: 'Finish run',
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.semanticLabel,
    this.filled = false,
    this.fill,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String semanticLabel;
  final bool filled;
  final Color? fill;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: 0.9,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: M3EMotion.medium2,
        curve: M3EMotion.emphasized,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled
              ? (fill ?? AppPalette.ink)
              : AppPalette.ink.withValues(alpha: onPressed == null ? 0.06 : 0.16),
          shape: BoxShape.circle,
          border: filled
              ? null
              : Border.all(
                  color: AppPalette.ink.withValues(alpha: onPressed == null ? 0.08 : 0.22),
                ),
        ),
        child: Icon(
          icon,
          size: size * 0.42,
          color: onPressed == null
              ? AppPalette.ink.withValues(alpha: 0.25)
              : (iconColor ?? AppPalette.ink),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirm,
    required this.cancel,
    this.destructive = false,
  });

  final String title;
  final String body;
  final String confirm;
  final String cancel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          color: AppPalette.emberHigh,
          borderRadius: M3EShape.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppType.eyebrow(size: 17)),
            const SizedBox(height: 8),
            Text(body, style: AppType.bodyText(size: 14.5, color: AppPalette.ink.withValues(alpha: 0.78))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppPalette.ink.withValues(alpha: 0.10),
                        borderRadius: M3EShape.full,
                      ),
                      child: Text(cancel.toUpperCase(),
                          style: AppType.buttonLabel(size: 14)
                              .copyWith(color: AppPalette.ink.withValues(alpha: 0.85))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppPalette.ink,
                        borderRadius: M3EShape.full,
                      ),
                      child: Text(
                        confirm.toUpperCase(),
                        style: AppType.buttonLabel(size: 14)
                            .copyWith(color: destructive ? AppPalette.emberSurface : AppPalette.emberSurface),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kept for the summary screen's hero math.
double progressEase(double t) => Curves.easeOutCubic.transform(math.min(1, math.max(0, t)));
