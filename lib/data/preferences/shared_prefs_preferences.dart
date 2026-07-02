import 'package:shared_preferences/shared_preferences.dart';

import '../../core/preferences.dart';

/// [AppPreferences] backed by shared_preferences. Construct via [load].
class SharedPrefsPreferences implements AppPreferences {
  SharedPrefsPreferences(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPrefsPreferences> load() async =>
      SharedPrefsPreferences(await SharedPreferences.getInstance());

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}
