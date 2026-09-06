import 'package:flutter/material.dart';
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
