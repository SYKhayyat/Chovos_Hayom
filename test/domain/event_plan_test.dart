import 'dart:convert';
import 'dart:io';

import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// #42's foundation: a tick says **which plan asked for it, and on which day**.
///
/// Two rules from the owner, and they are the same asymmetry #42 states for the
/// day sheet:
///
/// * A tick or un-tick in the **unit grid** does not add to, or remove from, a
///   plan. The grid is a claim about the learner; the plan is a claim about what
///   was asked.
/// * A tick or un-tick in the **plan** does what the user means, which needs the
///   plan and the day to be recoverable from the event afterwards.
///
/// So `planId` is **nullable**, and null means exactly one thing: an off-plan
/// tick made in the grid. Everything else carries one — including a `+` that
/// created a standalone plan, because that creates a real (if tiny) one.
void main() {
  LearningEvent ev({
    String? planId,
    DateTime? occurredAt,
    EventAction action = EventAction.done,
  }) => LearningEvent(
    id: 'e1',
    profileId: 'p',
    nodeId: 'shabbos',
    unitIndex: 2,
    action: action,
    occurredAt: occurredAt ?? DateTime.utc(2026, 3, 1),
    loggedAt: DateTime.utc(2026, 3, 1),
    planId: planId,
  );

  group('a tick knows which plan asked for it', () {
    test('an off-plan tick — from the unit grid — carries no plan', () {
      // The grid's tick is a fact about the learner and nothing else, so null
      // is a real and common value rather than "not filled in yet".
      expect(ev().planId, isNull);
    });

    test('a plan tick carries the plan that asked for it', () {
      expect(ev(planId: 'daf-yomi').planId, 'daf-yomi');
    });

    test('the two are distinguishable, which is the whole point', () {
      // Without this the app cannot answer "what did I do today?" without
      // mixing a grid tick in with what the plan asked for.
      expect(
        ev().toJson().containsKey('planId'),
        isFalse,
        reason:
            'absent when null, so an off-plan tick stays the same bytes '
            'an old backup has',
      );
      expect(ev(planId: 'p1').toJson()['planId'], 'p1');
    });

    test('a tick for a day carries that day, not the day it was recorded', () {
      // Marking already accepts an earlier date; a plan tick for Thursday made
      // on Friday must land on Thursday or the day's ledger is wrong.
      final e = ev(planId: 'daf-yomi', occurredAt: DateTime.utc(2026, 2, 26));
      expect(e.occurredAt, DateTime.utc(2026, 2, 26));
      expect(e.loggedAt, DateTime.utc(2026, 3, 1));
      expect(
        LearningEvent.fromJson(e.toJson()).occurredAt,
        DateTime.utc(2026, 2, 26),
      );
    });
  });

  group('it survives every boundary', () {
    test('JSON round-trips, with and without a plan', () {
      expect(LearningEvent.fromJson(ev(planId: 'p1').toJson()).planId, 'p1');
      expect(LearningEvent.fromJson(ev().toJson()).planId, isNull);
    });

    test('a backup written before plans existed still imports', () {
      // An old file has no `planId` key at all, and must read as an off-plan
      // tick rather than failing — the user did do that work, just without a
      // plan attached.
      final legacy =
          jsonDecode(jsonEncode(ev(planId: 'p1').toJson()))
              as Map<String, dynamic>;
      legacy.remove('planId');
      expect(LearningEvent.fromJson(legacy).planId, isNull);
    });

    test('rescoping to another profile keeps the plan', () {
      // A plan is scoped by profile, so an event moved between profiles must
      // keep the one it belonged to or it silently becomes off-plan.
      expect(ev(planId: 'p1').rescopedTo('other').planId, 'p1');
    });

    test('editing details keeps the plan', () {
      // Re-dating a tick is the "wrong date, not wrong fact" case; it must not
      // also turn the tick into an off-plan one.
      final edited = ev(planId: 'p1').withDetails(
        occurredAt: DateTime.utc(2026, 4, 1),
        durationMin: 10,
        note: null,
      );
      expect(edited.planId, 'p1');
      expect(edited.occurredAt, DateTime.utc(2026, 4, 1));
    });
  });

  group('the field guard', () {
    test('LearningEvent gained exactly one field, and it is planId', () {
      // The guard reads the constructor out of the source rather than assuming
      // it, so this is a change in the *number* that needs a reason.
      final source = File(
        'lib/domain/entities/learning_event.dart',
      ).readAsStringSync();
      final ctor = RegExp(
        r'const LearningEvent\(\{([\s\S]*?)\}\);',
      ).firstMatch(source)!.group(1)!;
      final fields = [
        for (final m in RegExp(r'this\.(\w+)').allMatches(ctor)) m.group(1)!,
      ];
      expect(
        fields,
        hasLength(12),
        reason: 'was 11; a twelfth field needs a reason in the same commit',
      );
      expect(fields, contains('planId'));
    });
  });
}
