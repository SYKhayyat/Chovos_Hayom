import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// `withDetails` is the only way to copy an event, and null means *clear*.
///
/// It shared the class with a `copyWith` whose null meant "keep existing"; these
/// tests pin down the surviving one, so a future re-addition of the other has to
/// argue with a failing test rather than a comment.
void main() {
  final original = LearningEvent(
    id: 'e1',
    profileId: 'p',
    nodeId: 'shabbos',
    unitIndex: 12,
    action: EventAction.done,
    occurredAt: DateTime(2026, 3, 1, 9),
    loggedAt: DateTime(2026, 3, 1, 21),
    durationMin: 40,
    note: 'a chiddush',
    layers: const [mainLayerId, 'rashi'],
    batchId: 'batch-7',
  );

  test('null clears the annotation rather than keeping it', () {
    final cleared = original.withDetails(
      occurredAt: original.occurredAt,
      durationMin: null,
      note: null,
    );

    expect(cleared.durationMin, isNull);
    expect(cleared.note, isNull);
  });

  test('everything that identifies the event survives the edit', () {
    final edited = original.withDetails(
      occurredAt: DateTime(2026, 3, 4, 7),
      durationMin: 15,
      note: 'revised',
    );

    expect(edited.id, original.id);
    expect(edited.profileId, original.profileId);
    expect(edited.nodeId, original.nodeId);
    expect(edited.unitIndex, original.unitIndex);
    expect(edited.action, original.action);
    // loggedAt defines the fold's append order — editing when you *learned* it
    // must not move the event in that order.
    expect(edited.loggedAt, original.loggedAt);
    // Which mefarshim the event covers is not an annotation; the details editor
    // has no field for it and must not silently drop it.
    expect(edited.layers, original.layers);
    // Losing this would strand the event outside its batch and break undo.
    expect(edited.batchId, original.batchId);

    expect(edited.occurredAt, DateTime(2026, 3, 4, 7));
    expect(edited.durationMin, 15);
    expect(edited.note, 'revised');
  });

  test('an edited event round-trips through JSON unchanged', () {
    final edited = original.withDetails(
      occurredAt: DateTime(2026, 3, 4, 7),
      durationMin: null,
      note: 'kept',
    );
    final restored = LearningEvent.fromJson(edited.toJson());

    expect(restored.id, edited.id);
    expect(restored.occurredAt, edited.occurredAt);
    expect(restored.durationMin, isNull);
    expect(restored.note, 'kept');
    expect(restored.layers, edited.layers);
    expect(restored.batchId, edited.batchId);
  });
}
