/// Reading a number a person typed.
///
/// "Is this a positive integer" was answered in **three layers for each of the
/// two interval settings** — the dialog that takes it, the setter that stores
/// it, and the loader that reads it back — six hand-written answers to one
/// question, plus four more in the cycle editor and the node editor.
///
/// Six of one and half a dozen of the other would be harmless. They were not
/// the same answer, and the difference was visible: typing `2, 5, x` into the
/// chazara intervals silently kept `[2, 5]` and threw the rest away, while
/// typing `x` into the backup interval closed the dialog and complained on a
/// snackbar. Two settings, two rows apart, disagreeing about what happens to
/// input neither of them can use — and *"do not clamp a wrong value, find out
/// why it is wrong"* is the first rule in `CONTRIBUTING.md`.
///
/// So: **one definition of the parse, and the layers differ only in what they
/// do about a failure.** The dialog says so and stays open. The store refuses
/// to hold a value it could not have been given. The loader falls back, because
/// a preference file edited by hand or written by an older build has to read as
/// *something*, and there is nobody to ask.
library;

/// The positive integer [raw] names, or null if it does not name one.
///
/// Null covers all three failures the call sites used to distinguish by hand and
/// then treat identically: absent, not a number, and not positive. Zero is a
/// failure — every quantity this parses is a count of days or units, and none of
/// them means anything at zero.
int? positiveInt(String? raw) {
  final n = int.tryParse(raw?.trim() ?? '');
  return (n == null || n <= 0) ? null : n;
}

/// The non-negative integer [raw] names, or null. For the one quantity where
/// zero is a real answer — a leaf's first unit index, which is `0` for a sefer
/// numbered from zero and `2` for a gemara starting on daf ב.
int? nonNegativeInt(String? raw) {
  final n = int.tryParse(raw?.trim() ?? '');
  return (n == null || n < 0) ? null : n;
}

/// What a comma-separated list of positive integers parsed to, and what in it
/// did not.
///
/// Both halves, because the two callers want different ones and used to answer
/// by *discarding* the second: a list is only worth taking if the user can be
/// told which part of it was not understood.
class IntList {
  const IntList(this.values, this.rejected);

  final List<int> values;

  /// The parts that are not positive integers, in the order they were typed —
  /// empty parts excluded, so a trailing comma is not an error.
  final List<String> rejected;

  bool get isValid => rejected.isEmpty;
}

/// Parses `"2, 5, 9"`.
IntList positiveIntList(String? raw) {
  final values = <int>[];
  final rejected = <String>[];
  for (final part in (raw ?? '').split(',')) {
    final trimmed = part.trim();
    // A trailing comma, or a doubled one, is a typing artefact rather than a
    // value somebody meant.
    if (trimmed.isEmpty) continue;
    final n = positiveInt(trimmed);
    if (n == null) {
      rejected.add(trimmed);
    } else {
      values.add(n);
    }
  }
  return IntList(values, rejected);
}
