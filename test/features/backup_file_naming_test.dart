import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The import dialog filters for `.json`. A backup saved without that suffix is
/// one the user can see in Explorer and cannot select in the dialog that
/// restores it — reported as "Saved backup" all the same. An export you cannot
/// import is not a backup.
void main() {
  test('a path without the suffix gets one', () {
    expect(SettingsScreen.withJsonExtension(r'C:\Users\me\Documents\backup'),
        r'C:\Users\me\Documents\backup.json');
  });

  test('a path that already has it is left alone', () {
    expect(SettingsScreen.withJsonExtension(r'C:\Users\me\backup.json'),
        r'C:\Users\me\backup.json');
  });

  test('the check is case-insensitive, so .JSON is not doubled up', () {
    expect(SettingsScreen.withJsonExtension('/home/me/backup.JSON'),
        '/home/me/backup.JSON');
  });

  test('a name containing "json" earlier still gets the suffix', () {
    expect(SettingsScreen.withJsonExtension('/home/me/json-backup'),
        '/home/me/json-backup.json');
  });
}
