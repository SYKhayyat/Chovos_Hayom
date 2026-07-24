import 'package:chovos_hayom/domain/entities/learning_event.dart';

import 'in_memory_progress_repository.dart';

/// An [InMemoryProgressRepository] whose event writes fail.
///
/// The write guard exists because a write *can* fail — a full disk, a locked
/// database, a schema the app can't open. There is no way to prove the app
/// reports that honestly without a repository that actually refuses, so this is
/// one. Everything else behaves normally, so a screen still loads and renders
/// before the failing write is attempted.
class FailingProgressRepository extends InMemoryProgressRepository {
  FailingProgressRepository({this.failWrites = true, this.failEventReads = false});

  /// Flip to false mid-test to check the success path on the same screen.
  bool failWrites;

  /// Makes `getEvents` refuse.
  ///
  /// Off by default, because a screen has to *load* before most tests can do
  /// anything. It exists for the operations that read the log rather than write
  /// it — an export, most of all: building a backup starts by reading every
  /// event, and that read failing is the realistic way an export dies. The
  /// stream (`watchEvents`) is deliberately left working, so the screen still
  /// renders and it is only the export that fails.
  bool failEventReads;

  /// What every refused call throws — matched in assertions so a test can be
  /// sure it saw *this* failure and not an incidental one.
  static const message = 'the database is not writable';

  @override
  Future<List<LearningEvent>> getEvents(String profileId) async {
    if (failEventReads) throw StateError(message);
    return super.getEvents(profileId);
  }

  @override
  Future<void> addEvent(LearningEvent event) async {
    if (failWrites) throw StateError(message);
    return super.addEvent(event);
  }

  @override
  Future<void> addEvents(List<LearningEvent> events) async {
    if (failWrites) throw StateError(message);
    return super.addEvents(events);
  }
}
