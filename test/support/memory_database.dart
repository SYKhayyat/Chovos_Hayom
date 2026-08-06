import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/data/drift/database.dart';
import 'package:chovos_hayom/data/repositories/drift_progress_repository.dart';

/// The real database, in memory — what every test overrides
/// `progressRepositoryProvider` with.
///
/// This replaces a 344-line hand-written `InMemoryProgressRepository`. That
/// class made two claims in its docstring, and the second one was the problem.
///
/// The first claim — *"no native dependencies"* — was already false in practice:
/// `drift_progress_repository_test.dart`, `event_id_collision_test.dart` and
/// `restore_scope_test.dart` all ran `AppDatabase(NativeDatabase.memory())`
/// under plain `flutter_test`, in CI, in milliseconds. `sqlite3` is a dev
/// dependency; nothing had to be added to delete the double.
///
/// The second claim — *"a faithful implementation rather than a stub"* — is the
/// one no test double can keep, because faithfulness is not a property you
/// write once. It had drifted on four axes, each of which is now covered by a
/// test in `drift_progress_repository_test.dart` that the double passed and the
/// real repository has to earn:
///
/// 1. `updateEvent` replaced the whole stored object. The real one writes three
///    columns and documents identity and action as immutable, so every test
///    that "edited an event" was proving something the app cannot do.
/// 2. `addProfile` was `_profiles.add`. The real one inserts against a primary
///    key and throws `SqliteException(1555)` on a repeat.
/// 3. It had no `_encodeLayers`, so `backup_service_test`'s *round-trips
///    layers* never touched the column that stores them — the null-means-`main`
///    encoding was untested in the one place it is read.
/// 4. Its `transaction` claimed to match SQLite's nesting by running a nested
///    call inline. Drift nests with `SAVEPOINT`: an inner failure that the
///    outer catches rolls back to the savepoint and the outer transaction
///    survives, where the double kept the inner writes.
///
/// The docstring was honest that exactly this class of drift is why the
/// cross-profile import collision could not fail in any test that used it. It
/// then re-earned the same risk on four new axes, which is the argument for not
/// having a second implementation of the interface at all.
///
/// `test/support/support_guard_test.dart` fails the build if one comes back.
AppDatabase memoryDatabase() {
  // Drift warns — with a full captured stack trace, printed — whenever a second
  // `AppDatabase` is constructed in one process, because in an app that means a
  // second connection to the same file. Here it means the next test, and the
  // warning is the single most expensive thing in the suite: it turned a
  // one-second file into a forty-second one. Silenced deliberately rather than
  // by ignoring the output, so the reason is written down where it is set.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // `closeStreamsSynchronously` is the difference between this working in a
  // `testWidgets` body and not. By default drift keeps a cancelled query stream
  // alive for one event-loop turn — a `Timer.run` — so a `StreamBuilder` that
  // reconnects on the next rebuild does not re-run the statement. Every
  // provider that watches the log is now `autoDispose`, so a widget test
  // cancels those streams constantly, and each cancellation left a timer that
  // outlived the test: `flutter_test`'s fake clock then failed the test with
  // *A Timer is still pending*, and the run hung. Drift's own docs name this
  // option for exactly this situation. The cache it disables is a
  // production-latency optimisation with nothing to say about correctness.
  final db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(),
          closeStreamsSynchronously: true));
  // Registered here rather than left to each caller: the majority of call sites
  // build the repository inline inside an `overrideWithValue`, where there is
  // no variable to close in a `tearDown`. `addTearDown` works from a test body
  // and from `setUp` alike, so one helper covers both shapes.
  addTearDown(db.close);
  return db;
}

/// A [DriftProgressRepository] over a fresh in-memory database.
///
/// Returns the concrete type rather than the interface so a test can still
/// reach `AppDatabase` through the seams it needs — nothing depends on it being
/// abstract, and a test that wants the interface can annotate for it.
DriftProgressRepository memoryRepository() =>
    DriftProgressRepository(memoryDatabase());
