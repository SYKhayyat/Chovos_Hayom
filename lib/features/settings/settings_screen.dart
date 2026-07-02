import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings.dart';
import '../../core/calendar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Calendar'),
          RadioGroup<CalendarMode>(
            groupValue: settings.calendar,
            onChanged: (v) => notifier.setCalendar(v ?? CalendarMode.gregorian),
            child: const Column(
              children: [
                RadioListTile(
                  value: CalendarMode.gregorian,
                  title: Text('Secular (Gregorian)'),
                ),
                RadioListTile(
                  value: CalendarMode.hebrew,
                  title: Text('Hebrew'),
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (v) => notifier.setThemeMode(v ?? ThemeMode.system),
            child: const Column(
              children: [
                RadioListTile(value: ThemeMode.system, title: Text('Follow system')),
                RadioListTile(value: ThemeMode.light, title: Text('Light')),
                RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
