/// A local user profile. All data is scoped by [id] (see ARCHITECTURE.md §2.2).
///
/// Deliberately has no settings map. A profile's preferences live in
/// [AppPreferences] under profile-scoped keys, because the theme has to be
/// readable synchronously before the first frame — long before the database is
/// open. The schema carried a `settingsJson` column for this that nothing ever
/// read; it was removed in schema v10 rather than left as dead weight.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
}
