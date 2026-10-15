import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/run_engine.dart';
import '../share/share_preview_sheet.dart';
import '../widgets/controls.dart';
import '../widgets/run_map.dart';

/// The screen you land on when a run ends.
///
/// It answers three questions in order — did I do it, how far, and can I show
/// someone — so the share button sits directly under the number it belongs to.
class RunSummaryScreen extends ConsumerStatefulWidget {
  const RunSummaryScreen({required this.record, super.key});

  final RunRecord record;

  @override
  ConsumerState<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends ConsumerState<RunSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.record.workoutId;
      if (id != null) ref.read(completedProvider.notifier).toggle(id);
      ref.read(runEngineProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final palette = AppPalette.ember;
    final pace = Fmt.pace(r.paceSecPerKm);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: palette.surface,
        body: FieldBackground(
          palette: palette,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                    // No entrance animation on the page as a whole. The only
                    // thing that moves here is the distance, because that is
                    // the one value that just changed — and it is the reason
                    // the screen exists.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(record: r),
                        const SizedBox(height: 18),
                        _HeroNumber(record: r, pace: pace, entrance: _entrance),
                        const SizedBox(height: 20),
                        _RoutePreview(record: r),
                        const SizedBox(height: 18),
                        _StatGrid(record: r),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _GhostAction(
                          icon: Icons.close_rounded,
                          label: 'Done',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Pressable(
                          onTap: () => SharePreviewSheet.show(context, r),
                          semanticLabel: 'Share run',
                          child: Container(
                            height: 60,
                            decoration: const BoxDecoration(
                              color: AppPalette.ink,
                              borderRadius: M3EShape.full,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.ios_share_rounded,
                                    size: 21, color: AppPalette.emberSurface),
                                const SizedBox(width: 10),
                                Text(
                                  'SHARE RUN',
                                  style: AppType.buttonLabel(size: 16)
                                      .copyWith(color: AppPalette.emberSurface),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.record});

  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    final complete = record.completed;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.title.toUpperCase(), style: AppType.eyebrow(size: 15)),
              const SizedBox(height: 4),
              Text(
                Fmt.dateTime(record.startedAt),
                style: AppType.label(size: 12),
              ),
            ],
          ),
        ),
        _Pill(
          icon: complete ? Icons.check_rounded : Icons.flag_rounded,
          label: complete ? 'COMPLETED' : 'LOGGED',
          color: complete ? AppPalette.emberAccent : AppPalette.ink,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: M3EMotion.medium2,
      curve: M3EMotion.emphasized,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: M3EShape.full,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Text(label, style: AppType.eyebrow(size: 11)),
        ],
      ),
    );
  }
}

class _HeroNumber extends StatelessWidget {
  const _HeroNumber({required this.record, required this.pace, required this.entrance});

  final RunRecord record;
  final String? pace;
  final AnimationController entrance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(entrance.value.clamp(0.0, 1.0));
        return Transform.scale(scale: 0.86 + 0.14 * t, child: child);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SpringValue(
            target: record.distanceKm,
            builder: (context, v, _) =>
                Text(v.toStringAsFixed(2), style: AppType.hero(context, size: 92)),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('KM', style: AppType.heroUnit(size: 28)),
          ),
          const Spacer(),
          if (pace != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(pace!, style: AppType.stat(size: 22)),
                Text('/km avg', style: AppType.label(size: 11)),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.record});

  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    if (record.route.length < 2) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppPalette.ink.withValues(alpha: 0.08),
          borderRadius: M3EShape.card,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_off_rounded, size: 22, color: AppPalette.ink),
            const SizedBox(height: 8),
            Text('No GPS trace for this run', style: AppType.label(size: 12)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 178,
      child: RunMap(
        route: record.route,
        accent: AppPalette.emberAccent,
        follow: false,
        interactive: true,
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.record});

  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Fmt.clock(record.elapsed), 'Time'),
      (record.calories.toString(), 'Calories'),
      (record.topSpeedKmh.toStringAsFixed(1), 'Top km/h'),
      (record.route.length.toString(), 'GPS fixes'),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == tiles.length - 1 ? 0 : 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppPalette.ink.withValues(alpha: 0.09),
                  borderRadius: M3EShape.medium,
                ),
                child: Column(
                  children: [
                    Text(tiles[i].$1, style: AppType.stat(size: 19)),
                    const SizedBox(height: 3),
                    Text(
                      tiles[i].$2,
                      style: AppType.label(size: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppPalette.ink.withValues(alpha: 0.13),
          borderRadius: M3EShape.full,
          border: Border.all(color: AppPalette.ink.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: AppPalette.ink),
            const SizedBox(width: 8),
            Text(label.toUpperCase(), style: AppType.buttonLabel(size: 14)),
          ],
        ),
      ),
    );
  }
}
