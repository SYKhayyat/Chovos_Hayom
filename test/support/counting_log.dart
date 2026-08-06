import 'dart:collection';

import 'package:chovos_hayom/domain/entities/learning_event.dart';

/// The event log, counting every element read.
///
/// `ListBase` implements iteration, `toList`, `where`, `map` and `forEach` in
/// terms of `length` and `operator []`, so overriding the one subscript is
/// enough to see all of them — and a `.length` read, which is not a walk, does
/// not register.
///
/// Shared by the two suites that ask *how many times was the log walked*:
/// `log_pass_count_test.dart` asks it of a bare provider graph, where the
/// subscriptions are chosen by hand, and `log_pass_screen_test.dart` asks it of
/// real mounted screens, where they are not. The counter is itself asserted in
/// `log_pass_count_test.dart` — *the counter counts what it claims to* — because
/// a walk counter that has quietly stopped counting turns every assertion in
/// both files into a green test measuring nothing.
class CountingLog extends ListBase<LearningEvent> {
  CountingLog(this.inner);

  final List<LearningEvent> inner;
  int visits = 0;

  /// Element reads expressed in whole walks of the log.
  double get passes => inner.isEmpty ? 0 : visits / inner.length;

  void reset() => visits = 0;

  @override
  int get length => inner.length;

  @override
  set length(int value) => throw UnsupportedError('the log is append-only');

  @override
  LearningEvent operator [](int index) {
    visits++;
    return inner[index];
  }

  @override
  void operator []=(int index, LearningEvent value) =>
      throw UnsupportedError('the log is append-only');
}
