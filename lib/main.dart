import 'dart:async';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'services/download_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(
      enablePerformanceMonitor: false, warmUpMode: GlassWarmUpMode.never);
  unawaited(DownloadService.instance.initialize().catchError((Object error) {
    debugPrint('Download restoration unavailable: $error');
  }));
  runApp(LiquidGlassWidgets.wrap(
    adaptiveQuality: true,
    brightnessResolver: Theme.maybeBrightnessOf,
    child: const MaktabaApp(),
  ));
}
