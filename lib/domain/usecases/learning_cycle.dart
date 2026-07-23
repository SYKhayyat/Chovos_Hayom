import '../entities/catalog.dart';
import '../entities/catalog_node.dart';

/// One unit a cycle calls for on a given day.
///
/// A built-in cycle names its sefer in words (that is all a Hebrew-calendar
/// calculation knows); a user-defined cycle names a catalog node directly. Both
/// end up here, and [CycleMapper] resolves the first kind to a node.
class CycleDay {
  const CycleDay({
    required this.sefer,
    required this.unit,
    this.seferHebrew,
    this.nodeId,
  });

  /// How the cycle names the sefer, e.g. "Berachos".
  final String sefer;
  final String? seferHebrew;

  /// The unit within it (a daf, perek, siman…).
  final int unit;

  /// Set when the cycle is defined over catalog nodes, so no matching is needed.
  final String? nodeId;
}

/// One segment of a user-defined cycle: a catalog node and how many of its units
/// the cycle covers. Stored by id so the cycle survives the node being renamed.
class CycleSegment {
  const CycleSegment({required this.nodeId, required this.unitCount, this.unitOffset = 0});

  final String nodeId;
  final int unitCount;
  final int unitOffset;

  Map<String, dynamic> toJson() =>
      {'nodeId': nodeId, 'unitCount': unitCount, 'unitOffset': unitOffset};

  factory CycleSegment.fromJson(Map<String, dynamic> json) => CycleSegment(
        nodeId: json['nodeId'] as String,
        unitCount: (json['unitCount'] as num).toInt(),
        unitOffset: (json['unitOffset'] as num?)?.toInt() ?? 0,
      );
}

/// A user-defined cycle: walk these sefarim, in this order, this many units a
/// day, starting on this date, and begin again at the end.
///
/// The point of this existing at all: "learning cycles" shipped as exactly one
/// hardcoded cycle. Anyone learning Mishna Yomi, Rambam Yomi, Amud Yomi, a
/// yeshiva's own seder, or their own chazara programme had nothing. Rather than
/// guess at start dates for cycles the app can't compute authoritatively, the
/// engine lets anyone define theirs exactly — which is also the rule that
/// nothing in this app is un-configurable.
class SequentialCycle {
  const SequentialCycle({
    required this.id,
    required this.name,
    required this.startDate,
    required this.segments,
    this.unitsPerDay = 1,
    this.repeats = true,
  });

  final String id;
  final String name;

  /// The day the cycle's first unit is learned.
  final DateTime startDate;

  final List<CycleSegment> segments;
  final int unitsPerDay;

  /// Whether the cycle starts over on finishing, as Daf Yomi does.
  final bool repeats;

  int get totalUnits {
    var n = 0;
    for (final s in segments) {
      n += s.unitCount;
    }
    return n;
  }

  /// What this cycle calls for on [date] — empty before it starts, or after it
  /// ends if it doesn't repeat.
  List<CycleDay> unitsOn(DateTime date) {
    final total = totalUnits;
    if (total <= 0 || unitsPerDay <= 0) return const [];
    final day = _dayNumber(date) - _dayNumber(startDate);
    if (day < 0) return const [];

    final out = <CycleDay>[];
    for (var i = 0; i < unitsPerDay; i++) {
      final position = day * unitsPerDay + i;
      if (position >= total && !repeats) break;
      out.add(_at(position % total));
    }
    return out;
  }

  /// The [position]-th unit of the cycle, counting from 0 across all segments.
  CycleDay _at(int position) {
    var remaining = position;
    for (final segment in segments) {
      if (remaining < segment.unitCount) {
        return CycleDay(
          sefer: segment.nodeId,
          unit: segment.unitOffset + remaining,
          nodeId: segment.nodeId,
        );
      }
      remaining -= segment.unitCount;
    }
    // Unreachable while position < totalUnits; the last unit is the safe answer.
    final last = segments.last;
    return CycleDay(
      sefer: last.nodeId,
      unit: last.unitOffset + last.unitCount - 1,
      nodeId: last.nodeId,
    );
  }

  /// Which pass through the cycle [date] falls in (1 = the first).
  int cycleNumberOn(DateTime date) {
    final total = totalUnits;
    if (total <= 0 || unitsPerDay <= 0) return 1;
    final day = _dayNumber(date) - _dayNumber(startDate);
    if (day < 0) return 0;
    return (day * unitsPerDay) ~/ total + 1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startDate': startDate.toIso8601String(),
        'unitsPerDay': unitsPerDay,
        'repeats': repeats,
        'segments': [for (final s in segments) s.toJson()],
      };

  factory SequentialCycle.fromJson(Map<String, dynamic> json) => SequentialCycle(
        id: json['id'] as String,
        name: json['name'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        unitsPerDay: (json['unitsPerDay'] as num?)?.toInt() ?? 1,
        repeats: json['repeats'] as bool? ?? true,
        segments: [
          for (final s in (json['segments'] as List? ?? []))
            CycleSegment.fromJson((s as Map).cast<String, dynamic>()),
        ],
      );

  /// DST-safe whole-day ordinal in UTC, matching the rest of the app's day math.
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}

/// Resolves a [CycleDay] to the catalog node it should be logged against.
///
/// A built-in cycle only knows a transliterated name, and transliterations
/// differ ("Beitza" / "Beitzah" / "Betzah"). The old code matched by
/// regex-normalized name with no fallback, so one spelling difference meant the
/// daf silently could not be logged and there was nothing the user could do
/// about it. Explicit user mappings are consulted first, and anything unmatched
/// is reported so the UI can offer to link it.
class CycleMapper {
  const CycleMapper({required this.catalog, this.overrides = const {}});

  final Catalog catalog;

  /// Cycle-sefer name -> node id, chosen by the user. Wins over name matching.
  final Map<String, String> overrides;

  CatalogNode? resolve(CycleDay day) {
    // A node-defined cycle carries its own answer.
    final direct = day.nodeId;
    if (direct != null) return catalog.byId(direct);

    final pinned = overrides[day.sefer];
    if (pinned != null) {
      final node = catalog.byId(pinned);
      if (node != null) return node;
    }

    final wantEn = normalize(day.sefer);
    final wantHe = day.seferHebrew == null ? null : normalize(day.seferHebrew!);
    for (final n in catalog.all) {
      if (!n.isLeaf) continue;
      if (normalize(n.name) == wantEn) return n;
      if (wantHe != null &&
          n.nameHebrew != null &&
          normalize(n.nameHebrew!) == wantHe) {
        return n;
      }
    }
    return null;
  }

  /// Strips everything but Latin/Hebrew letters and lowercases, so "Beitza" and
  /// "Beitzah" still differ but "Rosh Hashanah" and "Rosh HaShanah" do not.
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-zא-ת]'), '');
}
