import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/run_engine.dart';
import '../widgets/aurora.dart';
import '../widgets/controls.dart';

/// The plan tab: four levels, each four weeks, each week three sessions.
///
/// A level card expands in place to reveal its weeks. Choosing a session hands
/// the whole screen over to the run home with that workout loaded — the card's
/// numeral flies across as a shared element so the connection is spatial, not
/// navigational.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  String? _expanded;
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.ember;
    final plans = ref.watch(plansProvider);
    final done = ref.watch(completedProvider);
    final progress = ref.watch(planProgressProvider);

    // Open the level you're actually on. The brief is "a list of plans that
    // expands into the current run" — arriving to a closed list makes the user
    // do a tap before anything is actionable.
    if (!_seeded) {
      _seeded = true;
      final active = plans.where((p) => p.level == progress.level).toList();
      _expanded = (active.isNotEmpty ? active.first : plans.first).id;
    }

    return AuroraBackground(
      palette: palette,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PLAN', style: AppType.eyebrow(size: 15)),
                              const SizedBox(height: 6),
                              // Fitted so the title can never clip against the
                              // level pill on a narrow phone.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Zero to 5K',
                                  style: AppType.hero(context, size: 50),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _LevelPill(level: progress.level, total: plans.length),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _OverallProgress(fraction: progress.fraction, label: '${progress.completed} / ${progress.total} workouts'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
              sliver: SliverList.separated(
                itemCount: plans.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x24FFFFFF),
                  ),
                ),
                itemBuilder: (context, i) {
                  final plan = plans[i];
                  return _LevelCard(
                    plan: plan,
                    completed: done,
                    locked: plan.level > progress.level,
                    expanded: _expanded == plan.id,
                    onToggle: () {
                      Haptics.selection();
                      setState(() => _expanded = _expanded == plan.id ? null : plan.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level, required this.total});

  final int level;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.ink.withValues(alpha: 0.14),
        borderRadius: M3EShape.full,
        border: Border.all(color: AppPalette.ink.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LEVEL', style: AppType.eyebrow(size: 10).copyWith(letterSpacing: 1.4)),
          const SizedBox(width: 8),
          Text('$level', style: AppType.stat(size: 22)),
          Text(' / $total', style: AppType.stat(size: 13).copyWith(color: AppPalette.ink.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({required this.fraction, required this.label});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SpringValue(
          target: fraction,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 8, color: AppPalette.ink.withValues(alpha: 0.16)),
                FractionallySizedBox(
                  widthFactor: v.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppPalette.ink,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(999)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppType.label(size: 12)),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.plan,
    required this.completed,
    required this.locked,
    required this.expanded,
    required this.onToggle,
  });

  final Plan plan;
  final Set<String> completed;
  final bool locked;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final total = plan.workouts.length;
    final done = plan.workouts.where((w) => completed.contains(w.id)).length;
    final fraction = total == 0 ? 0.0 : done / total;

    return AnimatedOpacity(
      duration: M3EMotion.medium2,
      opacity: locked ? 0.42 : 1,
      child: Pressable(
        onTap: locked ? null : onToggle,
        scale: 0.985,
        haptic: false,
        child: AnimatedContainer(
          duration: M3EMotion.medium4,
          curve: M3EMotion.emphasized,
          decoration: BoxDecoration(
            color: expanded ? AppPalette.ink.withValues(alpha: 0.11) : Colors.transparent,
            borderRadius: M3EShape.card,
          ),
          padding: EdgeInsets.fromLTRB(expanded ? 18 : 0, expanded ? 18 : 14, expanded ? 18 : 0, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _LevelBadge(plan: plan, fraction: fraction, locked: locked),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.title, style: AppType.bodyText(size: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          locked ? 'Finish level ${plan.level - 1} to unlock' : plan.subtitle,
                          style: AppType.label(size: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: M3EMotion.medium2,
                    curve: M3EMotion.emphasized,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppPalette.ink.withValues(alpha: 0.7),
                      size: 26,
                    ),
                  ),
                ],
              ),

              // AnimatedSize is layout-animating, which Apple-style motion
              // avoids — but for a single expanding container it's the honest
              // choice: the content genuinely has more room now.
              AnimatedSize(
                duration: M3EMotion.medium4,
                curve: M3EMotion.emphasized,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _LevelBody(plan: plan, completed: completed),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.plan, required this.fraction, required this.locked});

  final Plan plan;
  final double fraction;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: M3EMotion.long2,
              curve: M3EMotion.emphasizedDecelerate,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v.clamp(0.0, 1.0),
                strokeWidth: 3.4,
                strokeCap: StrokeCap.round,
                backgroundColor: AppPalette.ink.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation(
                  locked ? AppPalette.ink.withValues(alpha: 0.3) : AppPalette.ink,
                ),
              ),
            ),
          ),
          if (locked)
            const Icon(Icons.lock_rounded, size: 18, color: AppPalette.ink)
          else
            Text('${plan.level}', style: AppType.stat(size: 21)),
        ],
      ),
    );
  }
}

class _LevelBody extends ConsumerWidget {
  const _LevelBody({required this.plan, required this.completed});

  final Plan plan;
  final Set<String> completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = <int, List<Workout>>{};
    for (final w in plan.workouts) {
      weeks.putIfAbsent(w.week, () => []).add(w);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in weeks.entries) ...[
          _WeekRow(week: entry.key, workouts: entry.value, completed: completed),
          if (entry.key != weeks.keys.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.week,
    required this.workouts,
    required this.completed,
  });

  final int week;
  final List<Workout> workouts;
  final Set<String> completed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('WEEK $week', style: AppType.eyebrow(size: 11).copyWith(
          color: AppPalette.ink.withValues(alpha: 0.6),
          letterSpacing: 1.8,
        )),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final w in workouts)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: w == workouts.last ? 0 : 8),
                  child: _SessionChip(
                    workout: w,
                    done: completed.contains(w.id),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SessionChip extends ConsumerWidget {
  const _SessionChip({required this.workout, required this.done});

  final Workout workout;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = _weekday(workout.dayIndex);

    return Pressable(
      scale: 0.93,
      onTap: () {
        Haptics.medium();
        ref.read(runEngineProvider.notifier).start(workout);
        Navigator.of(context).pushNamed('/run');
      },
      semanticLabel: '${workout.title}, ${workout.goalLabel}',
      child: AnimatedContainer(
        duration: M3EMotion.medium2,
        curve: M3EMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: done ? AppPalette.ink : AppPalette.ink.withValues(alpha: 0.10),
          borderRadius: M3EShape.small,
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: M3EMotion.medium2,
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: done
                  ? const Icon(Icons.check_rounded, key: ValueKey('done'), size: 18, color: AppPalette.emberSurface)
                  : Text(day, key: const ValueKey('day'), style: AppType.eyebrow(size: 11)),
            ),
            const SizedBox(height: 4),
            Text(
              _patternShort(workout),
              style: AppType.stat(size: 12).copyWith(
                color: done ? AppPalette.emberSurface : AppPalette.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static String _weekday(int i) => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i];

  /// `1:00/1:30` — the run/walk pattern, which is the only thing that actually
  /// changes from week to week. The total time is the same idea three times.
  static String _patternShort(Workout w) {
    final run = w.pattern.firstWhere((i) => i.phase == Phase.run);
    final walk = w.pattern.where((i) => i.phase == Phase.walk).firstOrNull;
    String f(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return s == 0 ? '$m' : '$m:${s.toString().padLeft(2, '0')}';
    }

    return walk == null
        ? '${f(run.duration)} min'
        : '${f(run.duration)}/${f(walk.duration)} ×${w.repeats}';
  }
}
