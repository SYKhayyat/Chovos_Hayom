import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/session_timer.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The session timer used to be a `Stopwatch` inside a modal sheet: dismissing
/// the sheet threw the elapsed time away, which makes a timer meant to run
/// *while you learn* unusable for its stated purpose. These cover the properties
/// that fix requires.
void main() {
  late InMemoryPreferences prefs;
  late ProviderContainer container;

  ProviderContainer build() => ProviderContainer(
        overrides: [appPreferencesProvider.overrideWithValue(prefs)],
      );

  setUp(() {
    prefs = InMemoryPreferences();
    container = build();
  });

  tearDown(() => container.dispose());

  SessionTimerController timer() =>
      container.read(sessionTimerProvider.notifier);
  SessionTimerState state() => container.read(sessionTimerProvider);

  final t0 = DateTime(2026, 7, 23, 9);

  test('elapsed comes from wall-clock, not from ticks', () async {
    await timer().start(now: t0, label: 'Shabbos · daf 12');
    // No ticker ran; nothing was counting. The answer is still right.
    expect(state().elapsedAt(t0.add(const Duration(minutes: 42))),
        const Duration(minutes: 42));
  });

  test('pausing banks the time and stops accruing', () async {
    await timer().start(now: t0);
    await timer().pause(t0.add(const Duration(minutes: 10)));

    expect(state().isRunning, isFalse);
    expect(state().accumulated, const Duration(minutes: 10));
    // An hour later it still reads ten minutes.
    expect(state().elapsedAt(t0.add(const Duration(hours: 1))),
        const Duration(minutes: 10));
  });

  test('resuming adds to the banked time rather than restarting', () async {
    await timer().start(now: t0);
    await timer().pause(t0.add(const Duration(minutes: 10)));
    await timer().start(now: t0.add(const Duration(minutes: 30)));

    expect(state().elapsedAt(t0.add(const Duration(minutes: 35))),
        const Duration(minutes: 15));
  });

  test('a running session survives the app being killed', () async {
    await timer().start(now: t0, label: 'Shabbos · daf 12', nodeId: 'shabbos', unitIndex: 12);

    // A brand-new container over the same preferences is a fresh launch.
    container.dispose();
    container = build();

    final restored = container.read(sessionTimerProvider);
    expect(restored.isRunning, isTrue);
    expect(restored.label, 'Shabbos · daf 12');
    expect(restored.nodeId, 'shabbos');
    expect(restored.unitIndex, 12);
    expect(restored.elapsedAt(t0.add(const Duration(minutes: 20))),
        const Duration(minutes: 20),
        reason: 'time spent away still counts');
  });

  test('a paused session survives too, without accruing while gone', () async {
    await timer().start(now: t0);
    await timer().pause(t0.add(const Duration(minutes: 5)));

    container.dispose();
    container = build();

    final restored = container.read(sessionTimerProvider);
    expect(restored.isRunning, isFalse);
    expect(restored.elapsedAt(t0.add(const Duration(days: 1))),
        const Duration(minutes: 5));
  });

  test('reset clears the session and leaves nothing persisted', () async {
    await timer().start(now: t0);
    await timer().reset();

    expect(state().isActive, isFalse);
    expect(prefs.getString(PrefKeys.sessionTimer), isNull);
  });

  test('starting on a different unit replaces the session', () async {
    // Two sedarim are not one session.
    await timer().start(now: t0, nodeId: 'shabbos', unitIndex: 12);
    await timer().pause(t0.add(const Duration(minutes: 10)));
    await timer().start(
        now: t0.add(const Duration(hours: 2)), nodeId: 'eruvin', unitIndex: 2);

    expect(state().accumulated, Duration.zero);
    expect(state().nodeId, 'eruvin');
  });

  test('resuming the same unit keeps its banked time', () async {
    await timer().start(now: t0, nodeId: 'shabbos', unitIndex: 12);
    await timer().pause(t0.add(const Duration(minutes: 10)));
    await timer().start(
        now: t0.add(const Duration(hours: 2)), nodeId: 'shabbos', unitIndex: 12);

    expect(state().accumulated, const Duration(minutes: 10));
  });

  test('minutes round up, so a short seder still counts', () async {
    await timer().start(now: t0);
    expect(state().minutesAt(t0.add(const Duration(seconds: 30))), 1);
    expect(state().minutesAt(t0.add(const Duration(seconds: 61))), 2);
    expect(state().minutesAt(t0), 0, reason: 'nothing elapsed is nothing');
  });

  test('a corrupt stored session does not stop the app from opening', () async {
    prefs = InMemoryPreferences({PrefKeys.sessionTimer: 'not json at all'});
    container.dispose();
    container = build();

    expect(container.read(sessionTimerProvider).isActive, isFalse);
  });
}
