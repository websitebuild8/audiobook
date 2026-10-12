import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/library_screen.dart';
import 'services/download_service.dart';
import 'services/push_notification_service.dart';
import 'services/audiobook_audio_handler.dart';
import 'theme/app_theme.dart';

class MaktabaApp extends StatefulWidget {
  const MaktabaApp({super.key});

  @override
  State<MaktabaApp> createState() => _MaktabaAppState();
}

class _MaktabaAppState extends State<MaktabaApp> with WidgetsBindingObserver {
  static const _themeKey = 'dark_mode';
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _darkMode = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    PushNotificationService.instance.notice.addListener(_showPush);
  }

  @override
  void dispose() {
    PushNotificationService.instance.notice.removeListener(_showPush);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(AudiobookAudioHandler.current?.saveProgress());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(PushNotificationService.instance.restore());
      DownloadService.instance.resumeUpdates().catchError((Object error) {
        debugPrint('Download update unavailable: $error');
      });
    }
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool(_themeKey) ?? false;
      _ready = true;
    });
    unawaited(PushNotificationService.instance.restore());
  }

  void _showPush() {
    final notice = PushNotificationService.instance.notice.value;
    if (notice == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (notice.opened) {
        _navigator.currentState?.popUntil((route) => route.isFirst);
      }
      _messenger.currentState?.showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text('${notice.title}\n${notice.body}'),
      ));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
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

class _StartupSplash extends StatefulWidget {
  const _StartupSplash();

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
                  FadeTransition(
                    opacity: Tween<double>(begin: .58, end: 1).animate(_pulse),
                    child: ScaleTransition(
                      scale:
                          Tween<double>(begin: .96, end: 1.04).animate(_pulse),
                      child: const Text(
                        'މަރުޙަބާ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Maumoon',
                          fontSize: 58,
                          height: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
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
