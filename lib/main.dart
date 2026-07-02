import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/dashboard/dashboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: ChovosHayomApp()));
}

class ChovosHayomApp extends StatelessWidget {
  const ChovosHayomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chovos Hayom',
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
