import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import '../../data/plan_library.dart';
import '../../state/providers.dart';
import '../../state/run_engine.dart';
import '../widgets/aurora.dart';
import '../widgets/controls.dart';
import '../widgets/glyphs.dart';

/// The stats screen — the cobalt field from the reference.
///
/// Same information architecture as the red home (eyebrow, huge numeral,
/// supporting detail, one pill) in a completely different colour world, so
/// moving between them feels like changing rooms rather than changing screens.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.cobalt;
    final totals = ref.watch(totalsProvider);
    final history = ref.watch(runHistoryProvider);
    final progress = ref.watch(planProgressProvider);
    final next = ref.watch(nextWorkoutProvider);
    final now = DateTime.now();

    final week = _currentWeek(history, now);
    final weekKm = week.fold<double>(0, (a, r) => a + r.distanceKm);
    final weekRuns = week.length;
    final weekTime = week.fold<Duration>(Duration.zero, (a, r) => a + r.elapsed);

    final best = totals.bestPaceSecPerKm;
    final programmeWeek = progress.completed ~/ 3 + 1;

    return AuroraBackground(
      palette: palette,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Fmt.date(now)}  ·  week $programmeWeek of 16',
                      style: AppType.bodyText(
                        size: 14,
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                  ),
                  CircleAction(
                    icon: Icons.insights_rounded,
                    onPressed: () => _showBreakdown(context, ref),
                    semanticLabel: 'All-time breakdown',
                  ),
                ],
              ),
              const Spacer(flex: 3),

              // ── Number + ruler ─────────────────────────────────────────
              // The ruler is sized to the numeral block rather than stretched —
              // it's a marginal index, not a full-height graphic.
              SizedBox(
                height: 132,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RulerAxis(
                      fraction: (progress.fraction).clamp(0.0, 1.0),
                      bracket: [
                        ((programmeWeek - 1) / 16).clamp(0.0, 1.0),
                        (programmeWeek / 16).clamp(0.0, 1.0),
                      ],
                      color: palette.onSurface,
                      bracketColor: palette.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('THIS WEEK', style: AppType.eyebrow(size: 14)),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              SpringValue(
                                target: weekKm,
                                builder: (context, v, _) => Text(
                                  // "0 km" reads as a fact; "0.0 km" reads as
                                  // a missing measurement.
                                  weekRuns == 0 ? '0' : Fmt.km(v),
                                  style: AppType.hero(context, size: 104),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Text('KM', style: AppType.heroUnit(size: 30)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),
              // ── Caption ─────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: M3EMotion.medium2,
                child: Column(
                  key: ValueKey(weekRuns),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weekRuns == 0
                          ? 'Nothing logged yet this week.'
                          : '$weekRuns ${weekRuns == 1 ? 'run' : 'runs'} · ${Fmt.clock(weekTime)} moving.',
                      style: AppType.bodyText(size: 15.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      best == null
                          ? 'Finish a run to see your pace.'
                          : 'Best pace so far, ${Fmt.pace(best)} /km.',
                      style: AppType.bodyText(
                        size: 15.5,
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Seven-day strip ─────────────────────────────────────────
              _WeekStrip(days: week, today: now, palette: palette),
              const SizedBox(height: 18),

              PrimaryPill(
                label: next == null ? 'Free run' : 'Start',
                palette: palette,
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  final workout = next ?? PlanLibrary.longRun;
                  Haptics.medium();
                  ref.read(runEngineProvider.notifier).start(workout);
                  Navigator.of(context).pushNamed('/run');
                },
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  /// Mon..Sun of the current week, oldest first, each paired with the runs
  /// logged on that date.
  List<RunRecord> _currentWeek(List<RunRecord> history, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    return history
        .where((r) => !r.startedAt.isBefore(monday) &&
            r.startedAt.isBefore(monday.add(const Duration(days: 7))))
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }

  void _showBreakdown(BuildContext context, WidgetRef ref) {
    Haptics.light();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _AllTimeSheet(),
    );
  }
}

/// The seven-day strip from the reference: a weekday letter, the distance run
/// that day, and a bar whose length encodes it. Today's column is lifted.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days, required this.today, required this.palette});

  final List<RunRecord> days;
  final DateTime today;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final todayDate = DateTime(today.year, today.month, today.day);
    final monday = todayDate.subtract(Duration(days: today.weekday - 1));

    final perDay = List<double>.filled(7, 0);
    for (final r in days) {
      final idx = r.startedAt.difference(monday).inDays;
      if (idx >= 0 && idx < 7) perDay[idx] += r.distanceKm;
    }

    final maxV = perDay.fold<double>(0, (a, b) => a > b ? a : b);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayCell(
              letter: letters[i],
              km: perDay[i],
              maxKm: maxV,
              isToday: i == today.weekday - 1,
              palette: palette,
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.letter,
    required this.km,
    required this.maxKm,
    required this.isToday,
    required this.palette,
  });

  final String letter;
  final double km;
  final double maxKm;
  final bool isToday;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final fraction = maxKm <= 0 ? 0.0 : (km / maxKm).clamp(0.0, 1.0);
    final has = km > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedDefaultTextStyle(
          duration: M3EMotion.medium2,
          style: AppType.label(
            size: 10.5,
            color: isToday ? palette.accent : palette.onSurfaceVariant,
          ),
          child: Text(letter.toUpperCase()),
        ),
        const SizedBox(height: 5),
        Text(
          has ? km.toStringAsFixed(1) : '·',
          style: AppType.stat(size: isToday ? 17 : 15).copyWith(
            color: has ? palette.onSurface : palette.onSurface.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: 6),
        // The bar. Springs in on load so the week reads as filling up.
        SizedBox(
          height: 5,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: has ? 1.0 : 0.0),
            duration: Duration(milliseconds: 620 + i(km) * 90),
            curve: M3EMotion.emphasizedDecelerate,
            builder: (context, t, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (fraction * t).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday ? palette.accent : palette.onSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static int i(double km) => (km * 8).round().clamp(0, 12);
}

class _AllTimeSheet extends ConsumerWidget {
  const _AllTimeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.cobalt;
    final totals = ref.watch(totalsProvider);
    final progress = ref.watch(planProgressProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.cobaltHigh,
        borderRadius: M3EShape.sheet,
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        22 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.ink.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('ALL TIME', style: AppType.eyebrow(size: 18)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _Big(totals.distanceKm.toStringAsFixed(1), 'KILOMETRES')),
              Expanded(child: _Big('${totals.runs}', 'RUNS')),
              Expanded(child: _Big(Fmt.clock(totals.duration), 'TIME')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Big(
                  totals.bestPaceSecPerKm == null ? '—' : Fmt.pace(totals.bestPaceSecPerKm)!,
                  'BEST PACE',
                ),
              ),
              Expanded(child: _Big('${totals.calories}', 'CALORIES')),
              Expanded(child: _Big('${progress.completed}', 'WORKOUTS')),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryPill(
            label: 'Close',
            palette: palette,
            height: 54,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppType.stat(size: 26)),
        const SizedBox(height: 3),
        Text(label, style: AppType.label(size: 10)),
      ],
    );
  }
}
