import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import 'core/theme/app_theme.dart';
import 'core/theme/app_type.dart';
import 'data/models.dart';
import 'ui/run/run_screen.dart';
import 'ui/run/run_summary_screen.dart';
import 'ui/shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => const HomeShell(),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      ],
    ),
    // The run takes over the whole screen — chrome and all.
    GoRoute(
      path: '/run',
      pageBuilder: (context, state) => _fadePage(const RunScreen(), state),
      parentNavigatorKey: _rootKey,
    ),
    GoRoute(
      path: '/summary',
      pageBuilder: (context, state) {
        final record = state.extra as RunRecord;
        return _fadePage(RunSummaryScreen(record: record), state, fullscreenDialog: true);
      },
      parentNavigatorKey: _rootKey,
    ),
  ],
);

/// The tab shell lives under [HomeShell]; a shared transition keeps the
/// hand-off from a plan card to the run screen continuous.
Page<void> _fadePage(
  Widget child,
  GoRouterState state, {
  bool fullscreenDialog = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: M3EMotion.medium4,
    reverseTransitionDuration: M3EMotion.medium2,
    transitionsBuilder: (context, animation, secondary, child) {
      final enter = CurvedAnimation(
        parent: animation,
        curve: M3EMotion.emphasizedDecelerate,
        reverseCurve: M3EMotion.emphasizedAccelerate,
      );
      return FadeTransition(
        opacity: enter,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.06, end: 1.0).animate(enter),
          child: child,
        ),
      );
    },
  );
}

class ZeroTo5kApp extends StatelessWidget {
  const ZeroTo5kApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zero to 5K',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: buildThemeFor(AppPalette.ember),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: MediaQuery.withNoTextScaling(child: _EdgeGuard(child: child ?? const SizedBox())),
        );
      },
    );
  }
}

/// Keeps layout safe on devices with unusual insets (landscape phones, fold
/// hinges) by capping the text scale — a runner mid-workout is not reading
/// fine print, and the big numerals are already at their size limit.
class _EdgeGuard extends StatelessWidget {
  const _EdgeGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width > 600) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      );
    }
    return child;
  }
}

/// Convenience entry point used by `main()` and by tests.
Widget buildApp() => const ProviderScope(child: ZeroTo5kApp());
