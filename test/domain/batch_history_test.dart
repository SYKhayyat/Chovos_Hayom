import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/batch_history.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(
  String id, {
  String? batchId,
  String nodeId = 'shas.moed.shabbos',
  EventAction action = EventAction.done,
  DateTime? loggedAt,
}) =>
    LearningEvent(
      id: id,
      profileId: 'a',
      nodeId: nodeId,
      unitIndex: 2,
      action: action,
      occurredAt: loggedAt ?? DateTime(2026, 1, 1),
      loggedAt: loggedAt ?? DateTime(2026, 1, 1),
      batchId: batchId,
    );

void main() {
  test('groups events by batch and counts the units each touched', () {
    final batches = BatchHistory.of([
      ev('1', batchId: 'b1'),
      ev('2', batchId: 'b1'),
      ev('3', batchId: 'b1'),
      ev('4', batchId: 'b2', loggedAt: DateTime(2026, 2, 1)),
    ]);
    expect(batches, hasLength(2));
    expect(batches.first.id, 'b2', reason: 'most recent first');
    expect(batches.last.unitsAffected, 3);
  });

  test('single marks (no batch id) are not listed', () {
    expect(BatchHistory.of([ev('1'), ev('2')]), isEmpty);
  });

  test('records every leaf a category cascade touched, in first-seen order', () {
    final batch = BatchHistory.of([
      ev('1', batchId: 'b1', nodeId: 'shabbos'),
      ev('2', batchId: 'b1', nodeId: 'eruvin'),
      ev('3', batchId: 'b1', nodeId: 'shabbos'),
    ]).single;
    expect(batch.nodeIds, ['shabbos', 'eruvin']);
    expect(batch.unitsAffected, 3);
  });

  test('a clear batch reads as a clear, not a finish', () {
    final batch = BatchHistory.of(
        [ev('1', batchId: 'b1', action: EventAction.undone)]).single;
    expect(batch.isFinish, isFalse);
    expect(batch.action, EventAction.undone);
  });

  test('limit keeps the most recent batches', () {
    final batches = BatchHistory.of([
      ev('1', batchId: 'old', loggedAt: DateTime(2026, 1, 1)),
      ev('2', batchId: 'mid', loggedAt: DateTime(2026, 2, 1)),
      ev('3', batchId: 'new', loggedAt: DateTime(2026, 3, 1)),
    ], limit: 2);
    expect(batches.map((b) => b.id), ['new', 'mid']);
  });

  test('an undone batch disappears from the history', () {
    // Undo removes the batch's events; the history is derived, so it follows.
    final remaining = [ev('1', batchId: 'b1'), ev('2', batchId: 'b2')]
        .where((e) => e.batchId != 'b1');
    expect(BatchHistory.of(remaining).map((b) => b.id), ['b2']);
  });
}
