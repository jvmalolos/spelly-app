import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/challenge_page.dart';
import 'pages/home_page.dart';
import 'pages/scoreboard_page.dart';
import 'pages/settings_page.dart';
import 'pages/spelling_set_page.dart';

void main() {
  runApp(const SpellyApp());
}

class SpellyApp extends StatefulWidget {
  const SpellyApp({super.key});

  @override
  State<SpellyApp> createState() => _SpellyAppState();
}

class _SpellyAppState extends State<SpellyApp> with WidgetsBindingObserver {
  static const String _profileNameKey = 'profile_name';
  static const String _themeKey = 'seasonal_theme';

  bool _isLoading = true;
  String _profileName = '';
  String _seasonalTheme = 'spring';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPreferences();
    }
  }

  Future<void> refreshAppSettings() async {
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _profileName = prefs.getString(_profileNameKey) ?? '';
      _seasonalTheme = prefs.getString(_themeKey) ?? 'spring';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: _seasonColor(_seasonalTheme),
            ),
          ),
        ),
      );
    }

    return AppSession(
      profileName: _profileName,
      seasonalTheme: _seasonalTheme,
      refreshAppSettings: refreshAppSettings,
      child: MaterialApp(
        title: 'Spelling Helper',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _buildTheme(
          season: _seasonalTheme,
          brightness: Brightness.light,
        ),
        darkTheme: _buildTheme(
          season: _seasonalTheme,
          brightness: Brightness.dark,
        ),
        routes: {
          '/': (context) => const HomePage(),
          '/spelling-set': (context) => const SpellingSetPage(),
          '/challenge': (context) => const ChallengePage(),
          '/scoreboard': (context) => const ScoreboardPage(),
          '/settings': (context) => const SettingsPage(),
        },
        initialRoute: '/',
      ),
    );
  }

  ThemeData _buildTheme({
    required String season,
    required Brightness brightness,
  }) {
    final seed = _seasonColor(season);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF161A17)
          : _lightBackground(season),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF202521) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E2A23),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF222824) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : const Color(0xFFD5DBD2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: seed,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Color _seasonColor(String season) {
    switch (season) {
      case 'summer':
        return const Color(0xFFE1A73B);
      case 'autumn':
        return const Color(0xFFB5633C);
      case 'winter':
        return const Color(0xFF6B8AA6);
      case 'spring':
      default:
        return const Color(0xFF5D8C63);
    }
  }

  Color _lightBackground(String season) {
    switch (season) {
      case 'summer':
        return const Color(0xFFFFF7E6);
      case 'autumn':
        return const Color(0xFFF9EFE6);
      case 'winter':
        return const Color(0xFFF1F6FB);
      case 'spring':
      default:
        return const Color(0xFFF4F7EF);
    }
  }
}

class AppSession extends InheritedWidget {
  const AppSession({
    super.key,
    required this.profileName,
    required this.seasonalTheme,
    required this.refreshAppSettings,
    required super.child,
  });

  final String profileName;
  final String seasonalTheme;
  final Future<void> Function() refreshAppSettings;

  static AppSession? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppSession>();
  }

  @override
  bool updateShouldNotify(AppSession oldWidget) {
    return profileName != oldWidget.profileName ||
        seasonalTheme != oldWidget.seasonalTheme;
  }
}
