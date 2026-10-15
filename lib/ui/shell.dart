import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/haptics.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_type.dart';
import 'home/run_home_screen.dart';
import 'plan/plan_screen.dart';
import 'runs/runs_screen.dart';
import 'stats/stats_screen.dart';

/// Which colour world the shell is in. The home and plan tabs live on the red
/// field; stats and runs are the cool side. Runs shares the red field because
/// it's the same "what you did" story as the home screen.
enum TabKind { home, plan, stats, runs }

@immutable
class NavTab {
  const NavTab(this.kind, this.label, this.icon, this.activeIcon);

  final TabKind kind;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  static const all = [
    NavTab(TabKind.home, 'Run', Icons.play_arrow_outlined, Icons.play_arrow_rounded),
    NavTab(TabKind.plan, 'Plan', Icons.calendar_today_outlined, Icons.calendar_today_rounded),
    NavTab(TabKind.stats, 'Stats', Icons.bolt_outlined, Icons.bolt_rounded),
    NavTab(TabKind.runs, 'Runs', Icons.route_outlined, Icons.route_rounded),
  ];
}

extension TabKindX on TabKind {
  AppPalette get palette =>
      this == TabKind.stats ? AppPalette.cobalt : AppPalette.ember;
}

/// The tab shell.
///
/// The nav is a single pill with one indicator that *slides* between segments
/// rather than four independent highlights appearing. The slide is a spring, so
/// tapping a distant tab throws the indicator across and lets it settle — the
/// gesture reads as one object moving, which is what makes the bar feel
/// physical rather than a set of buttons.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  void _select(int i) {
    if (i == _index) return;
    Haptics.selection();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final tab = NavTab.all[_index];
    final palette = tab.kind.palette;

    return Scaffold(
      backgroundColor: palette.surface,
      body: AnimatedSwitcher(
        duration: M3EMotion.medium4,
        switchInCurve: M3EMotion.emphasized,
        switchOutCurve: M3EMotion.emphasizedAccelerate,
        // Cross-fade the field colour as the palette changes, so the whole
        // screen morphs rather than cutting.
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(
          key: ValueKey(tab.kind),
          child: switch (tab.kind) {
            TabKind.home => const RunHomeScreen(),
            TabKind.plan => const PlanScreen(),
            TabKind.stats => const StatsScreen(),
            TabKind.runs => const RunsScreen(),
          },
        ),
      ),
      bottomNavigationBar: _NavBar(
        tabs: NavTab.all,
        index: _index,
        palette: palette,
        onSelect: _select,
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.tabs,
    required this.index,
    required this.palette,
    required this.onSelect,
  });

  final List<NavTab> tabs;
  final int index;
  final AppPalette palette;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + bottom),
      child: Container(
        height: 66,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: palette.kind == PaletteKind.cobalt
              ? AppPalette.cobaltContainer
              : Colors.black.withValues(alpha: 0.26),
          borderRadius: M3EShape.full,
          border: Border.all(color: AppPalette.ink.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final seg = constraints.maxWidth / tabs.length;
            return Stack(
              children: [
                // The travelling indicator.
                AnimatedPositioned(
                  duration: M3EMotion.medium4,
                  curve: M3EMotion.emphasized,
                  left: seg * index,
                  top: 0,
                  bottom: 0,
                  width: seg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppPalette.ink.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      SizedBox(
                        width: seg,
                        child: _NavItem(
                          tab: tabs[i],
                          selected: i == index,
                          palette: palette,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final NavTab tab;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: M3EMotion.medium2,
            style: AppType.label(
              size: 10.5,
              color: selected
                  ? AppPalette.ink
                  : AppPalette.ink.withValues(alpha: 0.55),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon swaps with a small scale bounce so the change is felt,
                // not just seen.
                AnimatedSwitcher(
                  duration: M3EMotion.medium2,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    selected ? tab.activeIcon : tab.icon,
                    key: ValueKey(selected),
                    size: 21,
                    color: selected
                        ? AppPalette.ink
                        : AppPalette.ink.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 3),
                Text(tab.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
