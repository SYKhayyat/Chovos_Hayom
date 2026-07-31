import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/routes.dart';
import 'application/crash_log.dart';
import 'core/keypad.dart';
import 'application/providers.dart';
import 'application/settings.dart';
import 'application/stats.dart';
import 'data/preferences/shared_prefs_preferences.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  // One crash log for the whole app. It has to exist before the ProviderScope
  // (the startup guard needs it), so it is built here and then handed to
  // `crashLogProvider` as an override — otherwise `main` would guard one
  // instance while the write guard and Settings screen read a second, and the
  // "the failure is already in the log under what you were doing" promise would
  // land on the wrong file.
  final crashLog = CrashLog();
  // Everything runs inside the crash guard, so a failure during startup — the
  // hardest kind to diagnose from a user's description — is recorded too.
  await crashLog.guard(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPrefsPreferences.load();
    runApp(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          crashLogProvider.overrideWithValue(crashLog),
        ],
        child: const ChovosHayomApp(),
      ),
    );
  });
}

/// The one theme, in both brightnesses.
///
/// The focus colour is raised well above Material's default wash. That default
/// is tuned for a desktop pointer beside a keyboard, where focus is a hint;
/// on a phone with no touchscreen it is the *only* thing telling you which
/// control you are about to press, and at 240dp wide the default could not be
/// seen on the device at all.
ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3B5BA5),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    focusColor: scheme.primary.withValues(alpha: 0.22),
  );
}

class ChovosHayomApp extends ConsumerStatefulWidget {
  const ChovosHayomApp({super.key});

  @override
  ConsumerState<ChovosHayomApp> createState() => _ChovosHayomAppState();
}

class _ChovosHayomAppState extends ConsumerState<ChovosHayomApp>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;

  /// Needed only so a link arriving from outside has a navigator to push onto —
  /// see [didPushRouteInformation].
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // A suspended process gets no timers, so the midnight tick can be missed
    // entirely — on a phone that is the normal case. Re-deriving on resume is
    // what makes "today" mean today after the app has been away.
    _lifecycle = AppLifecycleListener(onResume: () => invalidateClock(ref));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  /// A deep link that arrives while the app is **already running**.
  ///
  /// Found on a phone: `chovoshayom://sefer/shabbosShas` opens the grid from
  /// cold and lands on "Not found" when the app is open — the same link, two
  /// answers. Android delivers the second one through `onNewIntent` (the
  /// activity is `singleTop`), which reaches the framework as
  /// `pushRouteInformation`, and the framework's default handler rebuilds the
  /// route name from **path + query + fragment only**. This app puts the screen
  /// *type* in the URI's authority — `sefer` in `chovoshayom://sefer/<id>` — so
  /// the default drops it and `/shabbosShas` matches nothing in the table.
  ///
  /// Passing the whole URI through is all that is needed: `AppRouter` already
  /// folds an authority in as a leading segment precisely so one table serves
  /// both shapes, and a bare `/sefer/<id>` still parses as it always did.
  ///
  /// Returning true claims the notification, which is what stops `WidgetsApp`'s
  /// own lossy handler from running afterwards.
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final navigator = _navigator.currentState;
    if (navigator == null) return false;
    // `unawaited` on purpose, and not the fire-and-forget the analyzer is
    // usually right to flag: a push's future completes when the route is
    // *popped*, so awaiting it would leave this handler open for as long as the
    // user stays on the screen.
    unawaited(navigator.pushNamed(routeInformation.uri.toString()));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final hebrewLayout =
        ref.watch(settingsProvider.select((s) => s.hebrewLayout));
    return MaterialApp(
      // `onGenerateTitle`, not `title`: the task-switcher label is a localized
      // string, and a plain `title` is resolved before any Localizations exist.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      themeMode: themeMode,
      // Named routes, not `home:` — see lib/app/routes.dart. The restoration
      // scope is what lets Android rebuild this stack after killing the process
      // in the background, which it can only do because every route's arguments
      // live in its name.
      restorationScopeId: 'chovos_hayom',
      navigatorKey: _navigator,
      initialRoute: Routes.dashboard,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      onUnknownRoute: AppRouter.onUnknownRoute,
      // The Hebrew toggle is a real language switch: a 'he' locale now selects
      // the Hebrew string table as well as flipping direction and localizing the
      // Material date pickers. Until the app's own text was translated this
      // setting produced right-to-left *English*, which is the half-measure it
      // was built to avoid. Null = follow the system, falling back to English.
      locale: hebrewLayout ? const Locale('he') : null,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Every route gets the focus ring, which is why it is installed here
      // rather than per screen: a screen added later takes part without
      // knowing it exists. `builder` wraps the navigator, so the ring is drawn
      // above the page and below nothing — dialogs and sheets included.
      builder: (context, child) => compactTheme(
        context,
        FocusRingOverlay(child: child ?? const SizedBox.shrink()),
      ),
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
    );
  }
}
