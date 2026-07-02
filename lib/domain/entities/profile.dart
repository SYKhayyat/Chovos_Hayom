/// A local user profile. All data is scoped by [id] (see ARCHITECTURE.md §2.2).
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.settings = const {},
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final Map<String, dynamic> settings;
}
