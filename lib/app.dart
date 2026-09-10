import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/library_screen.dart';
import 'theme/app_theme.dart';

class MaktabaApp extends StatefulWidget {
  const MaktabaApp({super.key});

  @override
  State<MaktabaApp> createState() => _MaktabaAppState();
}

class _MaktabaAppState extends State<MaktabaApp> {
  static const _themeKey = 'dark_mode';
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _darkMode = prefs.getBool(_themeKey) ?? false);
  }

  Future<void> _toggleTheme() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maktaba Athariyya',
      // Flutter does not currently provide a Dhivehi Material localization.
      // Arabic supplies an RTL localization for framework-owned controls such
      // as the PDF text-selection toolbar, while app content remains Dhivehi.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: LibraryScreen(
        darkMode: _darkMode,
        onToggleTheme: _toggleTheme,
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}
