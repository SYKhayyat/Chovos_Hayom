/// Simple synchronous key-value store for app-level preferences (active profile,
/// calendar mode, theme). Abstracted so tests use an in-memory implementation.
abstract interface class AppPreferences {
  String? getString(String key);
  Future<void> setString(String key, String value);
}

class InMemoryPreferences implements AppPreferences {
  InMemoryPreferences([Map<String, String>? seed]) : _m = {...?seed};
  final Map<String, String> _m;

  @override
  String? getString(String key) => _m[key];

  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
}

/// Well-known preference keys.
class PrefKeys {
  static const activeProfileId = 'activeProfileId';
  static const calendarMode = 'calendarMode';
  static const themeMode = 'themeMode';
  static const reminderEnabled = 'reminderEnabled';
  static const hebrewLayout = 'hebrewLayout';
  static const sortMetric = 'sortMetric';
  static const sortDescending = 'sortDescending';
  static const sortLevel = 'sortLevel';
  static const chazaraIntervals = 'chazaraIntervals';

  /// Comma-separated layer ids whose per-meforish coverage line is hidden in the
  /// tree. Absent/empty means every enabled meforish shows its bar.
  static const hiddenMeforishBars = 'hiddenMeforishBars';
}
