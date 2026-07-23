import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'application/settings.dart';
import 'application/stats.dart';
import 'data/preferences/shared_prefs_preferences.dart';
import 'features/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPrefsPreferences.load();
  runApp(
    ProviderScope(
      overrides: [appPreferencesProvider.overrideWithValue(prefs)],
      child: const ChovosHayomApp(),
    ),
  );
}

class ChovosHayomApp extends ConsumerStatefulWidget {
  const ChovosHayomApp({super.key});

  @override
  ConsumerState<ChovosHayomApp> createState() => _ChovosHayomAppState();
}

class _ChovosHayomAppState extends ConsumerState<ChovosHayomApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // A suspended process gets no timers, so the midnight tick can be missed
    // entirely — on a phone that is the normal case. Re-deriving on resume is
    // what makes "today" mean today after the app has been away.
    _lifecycle = AppLifecycleListener(onResume: () => invalidateClock(ref));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final hebrewLayout =
        ref.watch(settingsProvider.select((s) => s.hebrewLayout));
    return MaterialApp(
      title: 'Chovos Hayom',
      themeMode: themeMode,
      // Optional Hebrew (RTL) layout: a 'he' locale flips direction app-wide and
      // localizes the Material date pickers/dialogs. Null = system default (LTR).
      locale: hebrewLayout ? const Locale('he') : null,
      supportedLocales: const [Locale('en'), Locale('he')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B5BA5),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B5BA5),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
