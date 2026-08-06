import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences.dart';
import '../domain/entities/learning_event.dart';
import '../domain/usecases/backup_reminder.dart';
import 'providers.dart';
import 'settings.dart';
import 'stats.dart';

/// When the active profile was last exported.
///
/// Written only after an export has actually succeeded — it goes through the
/// same rule as everything else the app records: a backup that failed, or a save
/// dialog the user cancelled, must not mark the profile safe. That is the whole
/// value of this timestamp; a "last backed up: today" that isn't true is worse
/// than no timestamp at all, because it silences the one warning that would have
/// told them.
class LastBackupController extends Notifier<DateTime?> {
  late String _profileId;

  String get _key => PrefKeys.scoped(_profileId, PrefKeys.lastBackupAt);

  @override
  DateTime? build() {
    _profileId = ref.watch(activeProfileProvider);
    final raw = ref.watch(appPreferencesProvider).getString(_key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Record that an export of this profile succeeded at [at].
  Future<void> record(DateTime at) async {
    await ref
        .read(appPreferencesProvider)
        .setString(_key, at.toIso8601String());
    state = at;
  }
}

final lastBackupProvider =
    NotifierProvider<LastBackupController, DateTime?>(LastBackupController.new);

/// What the active profile stands to lose right now.
///
/// Derived, like everything else: the log says what has been recorded, the
/// timestamp says what the last export covered, and the difference is the
/// answer. Nothing about "how much is unsaved" is stored, so it cannot drift.
///
/// **Two dependencies move this number and three more only re-ask for it.** The
/// count is the third axis over the raw log — distinct units recorded since an
/// *instant*, keyed on `loggedAt`, which neither `foldProvider` nor
/// `logActivityProvider` can answer — so one walk per log change is its honest
/// price, and the clock, the reminder toggle and the interval cannot change the
/// answer by a single unit. They used to pay for it anyway: this was a plain
/// `Provider` that walked the log inline, so every midnight tick, every return
/// to the foreground and every theme toggle re-derived it end to end. Nothing
/// caught that. `provider_notify_test.dart` asserts a tick over unchanged data
/// notifies nobody — true, and never the question, because the cost was the work
/// done *before* deciding not to notify — and `log_pass_count_test.dart`'s own
/// midnight-tick assertion held only because this provider was excluded from the
/// count. It is in the count now.
///
/// **A [Notifier] holding the memo, and not a second provider, for a reason
/// worth knowing.** The obvious shape is to lift the count into its own
/// `Provider` and let Riverpod do the memoising — that is what a provider *is*.
/// It also breaks the app. A `Consumer` that stays mounted under a pushed route
/// has its subscriptions paused and resumed when the route pops; resuming one
/// flushes its ancestors, and a *derived* ancestor that went dirty while it
/// slept notifies **another provider** mid-build, which schedules a
/// `markNeedsBuild` on the `ProviderScope` inside the build phase. Flutter
/// asserts. Nothing else in the graph is exposed to this, because everything
/// else deep is kept warm by a screen that never paused; the backup standing is
/// watched by the dashboard alone, so the dashboard's own resume is the first
/// thing that ever touches it. `derived_flush_test.dart` — written when one
/// added provider between the nudge banner and the log did the same thing —
/// catches it on both paths a mark is made from.
///
/// So the memo lives where it costs no hop: a `Notifier` instance outlives its
/// own `build()`, and the log is handed out as a fresh list per emission, so
/// identity is a sound key for "the same log I already counted".
///
/// Two `.select`s rather than the whole settings object: this needs two scalars
/// out of nine, and re-deriving it on a sort change or a hidden meforish bar is
/// a rebuild of the dashboard banner, the drawer and the Settings tile for
/// nothing.
class BackupStatusNotifier extends Notifier<BackupStatus> {
  /// The exact log and boundary the cached count was taken over. Compared by
  /// identity for the log — a value comparison would be the pass again.
  List<LearningEvent>? _countedLog; // log-pass: ok — held to compare by identity, never walked
  DateTime? _countedSince;
  int _unsavedUnits = 0;

  @override
  BackupStatus build() {
    final events = ref.watch(eventsProvider).asData?.value ?? const [];
    final since = ref.watch(lastBackupProvider);
    // `identical`, then the boundary: a new list means new events, and a moved
    // boundary means an export just landed. Nothing else can move the count.
    if (!identical(events, _countedLog) || since != _countedSince) {
      _countedLog = events;
      _countedSince = since;
      _unsavedUnits = BackupReminder.unsavedUnitsSince(events, since);
    }

    return BackupReminder.evaluate(
      enabled:
          ref.watch(settingsProvider.select((s) => s.backupReminderEnabled)),
      lastBackupAt: since,
      intervalDays:
          ref.watch(settingsProvider.select((s) => s.backupIntervalDays)),
      unsavedUnits: _unsavedUnits,
      now: ref.watch(clockProvider)(),
    );
  }
}

final backupStatusProvider =
    NotifierProvider<BackupStatusNotifier, BackupStatus>(
        BackupStatusNotifier.new);
