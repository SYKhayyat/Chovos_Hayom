/// Element-wise equality for the collections the app's value types hold.
///
/// **Why this exists.** Riverpod re-notifies its listeners whenever
/// `previous != next`, and Dart's `List`, `Map` and `Set` compare by *identity*.
/// So a derived provider that rebuilds a collection notifies everything
/// downstream even when it rebuilt an identical one — which is how a single
/// marked daf came to re-run the whole provider graph and rebuild screens the
/// user was not looking at. The types those providers hand out therefore need
/// real `==`, and real `==` on them needs this.
///
/// One file rather than a private `_listEquals` per value type: there are five
/// of those types, three collection shapes between them, and "the same
/// transformation written twice is how two answers come to disagree" is the
/// rule the rest of this codebase already states — see `layer_requirements.dart`.
///
/// **Pure Dart on purpose.** `domain/` imports no packages at all, deliberately.
/// `package:flutter/foundation.dart` has `listEquals` but would pull Flutter
/// into the domain layer; `package:collection`'s `ListEquality` is generic over
/// `Object?` and is only a transitive dependency here, undeclared. Thirty lines
/// of monomorphic loop cost less than either.
library;

/// True if [a] and [b] have the same elements in the same order.
///
/// Identity is checked first, which is the case that actually fires: a
/// `copyWith` that does not touch a field passes the *same* list through, so
/// the common comparison costs one pointer check rather than a walk.
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// True if [a] and [b] have the same keys mapped to equal values.
bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    // A key present with a null value and a key that is absent are different
    // maps; `b[k] == null` alone cannot tell them apart.
    if (other == null && !b.containsKey(entry.key)) return false;
    if (other != entry.value) return false;
  }
  return true;
}

/// True if [a] and [b] contain the same elements, in any order.
bool setEquals<T>(Set<T>? a, Set<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}
