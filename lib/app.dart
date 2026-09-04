import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'theme/app_theme.dart';

class MaktabaApp extends StatelessWidget {
  const MaktabaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maktaba Athariyya',
      theme: AppTheme.light,
      home: const LibraryScreen(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}
