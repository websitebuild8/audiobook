import 'dart:async';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'services/download_service.dart';
import 'services/audiobook_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudiobookAudioHandler.initialize();
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
