import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'application/settings.dart';
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

class ChovosHayomApp extends ConsumerWidget {
  const ChovosHayomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
