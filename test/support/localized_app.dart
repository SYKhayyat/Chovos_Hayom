import 'package:chovos_hayom/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// A [MaterialApp] with the app's localizations installed.
///
/// Every screen resolves its text through `AppLocalizations.of(context)`, which
/// is non-nullable — so a bare `MaterialApp(home: ...)` in a test now throws the
/// moment the widget builds. Rather than have six test files each remember to
/// pass the delegate list, they call this.
///
/// [locale] defaults to English so existing expectations keep reading as they
/// were written; passing `Locale('he')` is what lets a test assert that a screen
/// is actually translated rather than merely mirrored.
/// One tab of the report, pumped on its own.
///
/// The five sections are bodies, not screens: the `Scaffold`, the app bar and
/// the tab controller belong to [ReportScreen] and there is deliberately only
/// one of each. A test that wants to look at a single section still has to
/// supply both, because a `ListTile` needs a `Material` ancestor and
/// `GoalsSection` reaches for the controller to move to the Calculator tab.
Widget reportSection(Widget section, {int length = 5}) => DefaultTabController(
      length: length,
      child: Scaffold(body: section),
    );

MaterialApp localizedApp({
  Widget? home,
  Locale locale = const Locale('en'),
  RouteFactory? onGenerateRoute,
  RouteFactory? onUnknownRoute,
}) =>
    MaterialApp(
      home: home,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateRoute: onGenerateRoute,
      onUnknownRoute: onUnknownRoute,
    );
