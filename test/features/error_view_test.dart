import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/failing_catalog_repository.dart';
import '../support/memory_database.dart';
import '../support/localized_app.dart';
import '../support/recording_crash_log.dart';

/// What a user meets when a *read* fails.
///
/// Every write in the app goes through one guard that names what failed, records
/// it, and offers a way forward. The three screens that load data had none of
/// that: they rendered `Center(child: Text('Error: $e'))` — a raw exception, in
/// English, with no retry and nothing in the crash log, because an
/// `AsyncValue.error` never reaches `FlutterError.onError`. A transient database
/// open failure looked exactly like a permanently broken install.
void main() {
  late RecordingCrashLog crashLog;
  late FailingCatalogRepository catalog;

  setUp(() {
    crashLog = RecordingCrashLog();
    catalog = FailingCatalogRepository();
  });

  Widget dashboard() => ProviderScope(
        overrides: [
          crashLogProvider.overrideWithValue(crashLog),
          catalogRepositoryProvider.overrideWithValue(catalog),
          progressRepositoryProvider
              .overrideWithValue(memoryRepository()),
        ],
        child: localizedApp(
          home: const DashboardScreen(),
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
        ),
      );

  testWidgets('a failed load explains itself instead of printing the exception',
      (tester) async {
    await tester.pumpWidget(dashboard());
    await tester.pumpAndSettle();

    expect(find.text('The catalog could not be loaded'), findsOneWidget);
    // The first thing worth knowing: this was a read, so nothing was lost.
    expect(find.textContaining('Your learning log is untouched'), findsOneWidget);
    // The raw exception is available, but not shoved in the user's face.
    expect(find.textContaining(FailingCatalogRepository.message), findsNothing);
  });

  testWidgets('the raw error is one tap away for whoever wants it',
      (tester) async {
    await tester.pumpWidget(dashboard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show details'));
    await tester.pumpAndSettle();

    expect(find.textContaining(FailingCatalogRepository.message), findsOneWidget);
  });

  testWidgets('the failure is in the crash log, so offering it is not a lie',
      (tester) async {
    await tester.pumpWidget(dashboard());
    await tester.pumpAndSettle();

    expect(crashLog.entries, hasLength(1));
    expect(crashLog.entries.single,
        contains(FailingCatalogRepository.message));
    // Filed under what failed, the same way the write guard files a write.
    expect(crashLog.entries.single, contains('The catalog could not be loaded'));
    expect(find.text('Open crash log'), findsOneWidget);
  });

  testWidgets('a rebuild while the error is showing does not re-log it',
      (tester) async {
    await tester.pumpWidget(dashboard());
    await tester.pumpAndSettle();
    expect(crashLog.entries, hasLength(1));

    // Toggling the details panel rebuilds the view. Recording on every build
    // would flood a capped log and push the useful history out of it.
    await tester.tap(find.text('Show details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide details'));
    await tester.pumpAndSettle();

    expect(crashLog.entries, hasLength(1));
  });

  testWidgets('retry actually re-runs the load, and recovers', (tester) async {
    await tester.pumpWidget(dashboard());
    await tester.pumpAndSettle();
    expect(catalog.loads, 1);
    expect(find.text('The catalog could not be loaded'), findsOneWidget);

    // The kind of failure this is for: it worked the second time.
    catalog.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(catalog.loads, 2);
    expect(find.text('The catalog could not be loaded'), findsNothing);
    // The tree is there — the screen recovered rather than needing a restart.
    expect(find.text('Kol HaTorah Kula'), findsOneWidget);
  });

  testWidgets('the error view is localized like everything else',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        crashLogProvider.overrideWithValue(crashLog),
        catalogRepositoryProvider.overrideWithValue(catalog),
        progressRepositoryProvider
            .overrideWithValue(memoryRepository()),
      ],
      child: localizedApp(
        home: const DashboardScreen(),
        locale: const Locale('he'),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('לא ניתן היה לטעון את הקטלוג'), findsOneWidget);
    expect(find.text('נסה שוב'), findsOneWidget);
    expect(find.text('The catalog could not be loaded'), findsNothing);
  });
}
