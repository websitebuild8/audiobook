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
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final minimumSplashTime = Future<void>.delayed(
      const Duration(milliseconds: 1400),
    );
    final prefs = await SharedPreferences.getInstance();
    await minimumSplashTime;
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool(_themeKey) ?? false;
      _ready = true;
    });
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
      home: _ready
          ? LibraryScreen(
              darkMode: _darkMode,
              onToggleTheme: _toggleTheme,
            )
          : const _StartupSplash(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02271B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/branding/splash_background.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/splash_mark.png',
                    width: 230,
                    height: 230,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 44),
                  const SizedBox.square(
                    dimension: 34,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
