import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../share/share_preview_sheet.dart';
import '../widgets/aurora.dart';
import '../widgets/controls.dart';
import '../widgets/signature_path.dart';

/// Every run you've logged, newest first. Each row is a miniature of the share
/// card: route shape on the left, the number that matters on the right.
class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.ember;
    final runs = ref.watch(runHistoryProvider);

    return AuroraBackground(
      palette: palette,
      child: SafeArea(
        bottom: false,
        child: runs.isEmpty
            ? _Empty(palette: palette)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('RUNS', style: AppType.eyebrow(size: 15)),
                                    const SizedBox(height: 6),
                                    Text('${runs.length} logged',
                                        style: AppType.hero(context, size: 46)),
                                  ],
                                ),
                              ),
                              _TotalChip(runs: runs),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    sliver: SliverList.separated(
                      itemCount: runs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _RunRow(
                        record: runs[i],
                        index: i,
                        palette: palette,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({required this.runs});

  final List<RunRecord> runs;

  @override
  Widget build(BuildContext context) {
    final km = runs.fold<double>(0, (a, r) => a + r.distanceKm);
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
          Text('TOTAL', style: AppType.eyebrow(size: 11).copyWith(letterSpacing: 1.4)),
          const SizedBox(width: 8),
          Text(km.toStringAsFixed(1), style: AppType.stat(size: 22)),
          const SizedBox(width: 3),
          Text('KM', style: AppType.stat(size: 11).copyWith(color: AppPalette.ink.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({
    required this.record,
    required this.index,
    required this.palette,
  });

  final RunRecord record;
  final int index;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final pace = Fmt.pace(record.paceSecPerKm);

    return Pressable(
      scale: 0.975,
      onTap: () {
        Haptics.light();
        showRunDetail(context, record);
      },
      semanticLabel: '${record.title}, ${record.distanceKm.toStringAsFixed(1)} kilometres',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppPalette.ink.withValues(alpha: 0.08),
          borderRadius: M3EShape.medium,
        ),
        child: Row(
          children: [
            // Route thumbnail.
            SizedBox(
              width: 52,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.ink.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CustomPaint(
                  painter: _RouteThumbPainter(route: record.route),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title.toUpperCase(),
                    style: AppType.eyebrow(size: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Fmt.dateTime(record.startedAt),
                    style: AppType.label(size: 11.5),
                  ),
                  if (pace != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${Fmt.clock(record.elapsed)} · $pace /km · ${record.calories} kcal',
                      style: AppType.label(size: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(record.distanceKm.toStringAsFixed(2), style: AppType.stat(size: 21)),
                const SizedBox(height: 1),
                Text('KM', style: AppType.stat(size: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny, honest silhouette of the route inside each list row.
class _RouteThumbPainter extends CustomPainter {
  _RouteThumbPainter({required this.route});

  final List<GeoPoint> route;

  @override
  void paint(Canvas canvas, Size size) {
    final color = AppPalette.ink;
    if (route.length < 2) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        3,
        Paint()..color = color.withValues(alpha: 0.3),
      );
      return;
    }

    var minLat = route.first.lat, maxLat = route.first.lat;
    var minLon = route.first.lon, maxLon = route.first.lon;
    for (final g in route) {
      minLat = g.lat < minLat ? g.lat : minLat;
      maxLat = g.lat > maxLat ? g.lat : maxLat;
      minLon = g.lon < minLon ? g.lon : minLon;
      maxLon = g.lon > maxLon ? g.lon : maxLon;
    }
    final midLat = (minLat + maxLat) / 2;
    final kx = 111320 * (midLat * 3.14159 / 180);

    final spanX = (maxLon - minLon) * kx;
    final spanY = (maxLat - minLat) * 111132;
    final span = spanX > spanY ? spanX : spanY;
    final scale = span <= 0 ? 1.0 : (size.shortestSide * 0.66) / span;

    final midLon = (minLon + maxLon) / 2;
    final path = Path();
    for (var i = 0; i < route.length; i++) {
      final o = Offset(
        size.width / 2 + ((route[i].lon - midLon) * kx) * scale,
        size.height / 2 - ((route[i].lat - midLat) * 111132) * scale,
      );
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_RouteThumbPainter old) => old.route != route;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RUNS', style: AppType.eyebrow(size: 15)),
          const Spacer(),
          SizedBox(
            height: 190,
            child: PlaceholderRoute(color: palette.onSurface),
          ),
          const Spacer(),
          Text(
            'Your history starts\nwith the first one.',
            textAlign: TextAlign.center,
            style: AppType.bodyText(size: 20, height: 1.25),
          ),
          const SizedBox(height: 10),
          Text(
            'Finish a run and the route you covered will be drawn here.',
            textAlign: TextAlign.center,
            style: AppType.bodyText(size: 14.5, color: palette.onSurfaceVariant),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// Full detail for a single logged run, presented as a sheet.
Future<void> showRunDetail(BuildContext context, RunRecord record) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    builder: (_) => _RunDetailSheet(record: record),
  );
}

class _RunDetailSheet extends ConsumerWidget {
  const _RunDetailSheet({required this.record});

  final RunRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.ember;
    final pace = Fmt.pace(record.paceSecPerKm);

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppPalette.emberHigh,
          borderRadius: M3EShape.sheet,
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(22, 12, 22, 22 + MediaQuery.of(context).viewPadding.bottom),
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
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.title.toUpperCase(), style: AppType.eyebrow(size: 14)),
                      const SizedBox(height: 6),
                      Text(Fmt.dateTime(record.startedAt), style: AppType.label(size: 12)),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(record.distanceKm.toStringAsFixed(2),
                        style: AppType.hero(context, size: 52)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('KM', style: AppType.heroUnit(size: 18)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _cell(Fmt.clock(record.elapsed), 'TIME')),
                Expanded(child: _cell(pace ?? '—', 'PACE /KM')),
                Expanded(child: _cell('${record.calories}', 'CAL')),
              ],
            ),
            const SizedBox(height: 18),
            PrimaryPill(
              label: 'Share image',
              icon: Icons.ios_share_rounded,
              palette: palette,
              height: 56,
              onPressed: () => SharePreviewSheet.show(context, record),
            ),
            const SizedBox(height: 10),
            Pressable(
              onTap: () async {
                final ok = await _confirmDelete(context);
                if (!ok || !context.mounted) return;
                await ref.read(runHistoryProvider.notifier).remove(record.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.ink.withValues(alpha: 0.09),
                  borderRadius: M3EShape.full,
                ),
                child: Text(
                  'DELETE RUN',
                  style: AppType.buttonLabel(size: 14)
                      .copyWith(color: AppPalette.emberAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppType.stat(size: 22)),
          const SizedBox(height: 3),
          Text(label, style: AppType.label(size: 10)),
        ],
      );

  Future<bool> _confirmDelete(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.emberHigh,
        title: Text('Delete this run?', style: AppType.eyebrow(size: 16)),
        content: Text(
          'It will be removed from your history and your stats.',
          style: AppType.bodyText(size: 14.5, color: AppPalette.ink.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep', style: AppType.buttonLabel(size: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppType.buttonLabel(size: 14).copyWith(color: AppPalette.emberAccent)),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}
