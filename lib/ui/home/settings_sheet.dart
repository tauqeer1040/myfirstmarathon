import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_type.dart';
import '../../state/providers.dart';
import '../widgets/controls.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final totals = ref.watch(totalsProvider);
    final progress = ref.watch(planProgressProvider);
    final store = ref.read(storeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.emberHigh,
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
          Text('Settings', style: AppType.eyebrow(size: 18)),
          const SizedBox(height: 18),

          _ToggleRow(
            title: 'Haptics',
            subtitle: 'Vibration on every block change and tap',
            value: prefs.haptics,
            onChanged: (v) {
              Haptics.setEnabled(v);
              ref.read(preferencesProvider.notifier).setHaptics(v);
            },
          ),
          _ToggleRow(
            title: 'Miles',
            subtitle: prefs.imperial ? 'Showing distances in miles' : 'Showing distances in kilometres',
            value: prefs.imperial,
            onChanged: (v) => ref.read(preferencesProvider.notifier).setImperial(v),
          ),

          const SizedBox(height: 8),
          _InfoRow(
            title: 'Programme',
            value: '${progress.completed} of ${progress.total} workouts',
          ),
          _InfoRow(title: 'Started', value: Fmt.date(store.startDate)),
          _InfoRow(
            title: 'Distance',
            value: '${totals.distanceKm.toStringAsFixed(1)} km',
          ),

          const SizedBox(height: 18),
          PrimaryPill(
            label: 'Done',
            palette: AppPalette.ember,
            height: 54,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.bodyText(size: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppType.label(size: 12, color: AppPalette.ink.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          // Custom switch: the Material one is a fixed-size pill that fights
          // the expressive geometry used everywhere else.
          Pressable(
            onTap: () {
              Haptics.selection();
              onChanged(!value);
            },
            haptic: false,
            scale: 0.9,
            semanticLabel: title,
            child: AnimatedContainer(
              duration: M3EMotion.medium2,
              curve: M3EMotion.emphasized,
              width: 58,
              height: 34,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: value ? AppPalette.emberAccent : AppPalette.ink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: M3EMotion.medium2,
                curve: M3EMotion.springy,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppPalette.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            title,
            style: AppType.bodyText(size: 14, color: AppPalette.ink.withValues(alpha: 0.66)),
          ),
          const Spacer(),
          Text(value, style: AppType.stat(size: 15)),
        ],
      ),
    );
  }
}
