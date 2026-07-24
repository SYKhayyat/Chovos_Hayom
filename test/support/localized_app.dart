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
