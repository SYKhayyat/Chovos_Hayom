import '../entities/layer.dart';
import 'fold_log.dart';
import 'layer_roles.dart';

/// One meforish, as it stands on one unit.
class UnitMeforish {
  const UnitMeforish({
    required this.layerId,
    required this.role,
    required this.isDone,
  });

  final String layerId;

  /// What this meforish is on this unit, or **null** when it is not configured
  /// here at all.
  ///
  /// Null is not "off and therefore irrelevant" — a layer with no role that
  /// still appears in this list is one the user *has already learned* and has
  /// since turned off, or one whose meforish has been deleted outright. The log
  /// is append-only and those units really were learned with it, so the answer
  /// has to be representable.
  final LayerRole? role;

  final bool isDone;

  bool get isRequired => role == LayerRole.required;

  /// Whether this unit currently offers it to be ticked. False for the
  /// learned-but-no-longer-configured case above.
  bool get isCheckableHere => role != null;
}

/// Which mefarshim apply to one unit, and in what state — asked once.
///
/// This was written out by hand at three call sites and each got a different
/// answer to the same question, which is the whole shape of the defect:
///
/// * The per-unit checklist showed `checkable ∪ completed`, and then appended
///   anything in either set that the mefarshim list did not contain — which is
///   how a meforish deleted after a unit was marked still gets a row.
/// * *Log with details* showed `checkable` and seeded the outstanding required
///   ones.
/// * *Log a chazara* showed `required ∪ completed` filtered through the
///   mefarshim list — **without** that last step. So a meforish you had
///   learned and since deleted was silently dropped from the options while
///   still being *seeded as selected*, because the seed came from `completed`
///   and the options did not. The sheet then submitted a layer with no checkbox
///   in it: a chazara recorded against something the user could neither see nor
///   untick.
///
/// One question, one answer, and the third case is now the same list the other
/// two are filtered out of.
class UnitMefarshim {
  const UnitMefarshim(this.all);

  /// Every meforish worth showing for this unit, in the order the mefarshim
  /// list holds them, with anything learned-but-unconfigured after them.
  final List<UnitMeforish> all;

  /// [layerOrder] is the app's mefarshim list, by id — the order every screen
  /// shows them in. Ids in the log or the config that are not in it come last,
  /// in the order they were found, so a deleted meforish is stable rather than
  /// jumping about between builds.
  factory UnitMefarshim.of({
    required LayerRoles roles,
    required LogFold? fold,
    required Iterable<String> layerOrder,
    required String nodeId,
    required int unitIndex,
  }) {
    final rolesHere = roles.forUnit(nodeId, unitIndex);
    final done = fold?.completedLayers(nodeId, unitIndex) ?? const <String>{};

    final out = <UnitMeforish>[];
    final seen = <String>{};
    void take(String id) {
      if (!seen.add(id)) return;
      if (!rolesHere.containsKey(id) && !done.contains(id)) return;
      out.add(UnitMeforish(
        layerId: id,
        role: rolesHere[id],
        isDone: done.contains(id),
      ));
    }

    for (final id in layerOrder) {
      take(id);
    }
    // The two sources, in a fixed order so the tail is deterministic: what the
    // unit asks for, then what was learned on it.
    for (final id in rolesHere.keys) {
      take(id);
    }
    for (final id in done) {
      take(id);
    }
    return UnitMefarshim(out);
  }

  /// The ones this unit currently offers to be ticked.
  List<UnitMeforish> get checkable =>
      [for (final m in all) if (m.isCheckableHere) m];

  /// The ones a chazara can be recorded against: what the unit asks for, plus
  /// whatever was learned on it — including a meforish that has since been
  /// turned off or deleted, because reviewing it is still a thing that happened.
  List<UnitMeforish> get reviewable =>
      [for (final m in all) if (m.isRequired || m.isDone) m];

  Set<String> get required =>
      {for (final m in all) if (m.isRequired) m.layerId};

  Set<String> get done => {for (final m in all) if (m.isDone) m.layerId};

  /// Required and not yet learned — what *log this unit* should arrive with
  /// already ticked.
  Set<String> get outstanding =>
      {for (final m in all) if (m.isRequired && !m.isDone) m.layerId};

  /// Whether this unit wants a checklist rather than a one-tap toggle — i.e. it
  /// offers more than just the text.
  ///
  /// Off the roles rather than off [all], deliberately: a plain text-only unit
  /// that happens to carry a stale learned layer is still a one-tap unit, and
  /// turning it into a checklist because of a meforish nobody can tick would be
  /// a worse answer than the one it replaces.
  static bool isLayered(LayerRoles roles, String nodeId, int unitIndex) =>
      roles.isLayered(nodeId, unitIndex);

  /// [mainLayerId] alone, for the unlayered case — the shape every caller ends
  /// up wanting when there is nothing to choose between.
  static const Set<String> justTheText = {mainLayerId};
}
