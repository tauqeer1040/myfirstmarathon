import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/haptics.dart';
import 'data/app_store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only: the layouts are composed around a single vertical column of
  // decisions, and the map has no meaningful landscape presentation here.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await AppStore.open();

  // Probe haptics before the first frame so the very first press is already
  // correctly silent on a device with no vibrator.
  await Haptics.init();
  Haptics.setEnabled(store.hapticsEnabled);

  runApp(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store)],
      child: buildApp(),
    ),
  );
}
