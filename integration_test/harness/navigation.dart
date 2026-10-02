import 'action.dart';

/// Getting around the app the way a person does.
///
/// **Through the drawer, every time.** The dashboard's drawer is the app's only
/// route to nine screens, so a journey that pushes routes by name would test the
/// router and skip the navigation — which is the part a person actually uses and
/// the part that was measured as broken on the device (a drawer whose only way
/// out is a hardware key nothing on screen mentions). So every journey that
/// needs to be somewhere else goes via the drawer, and the navigation is under
/// test for free.
///
/// The one exception is [StartAt], for the screens the drawer does not reach —
/// a sefer's grid and a category's subtree, which are reached by tapping a node.
class Nav {
  const Nav._();

  /// The menu button on the dashboard's app bar.
  static const openMenu = 'Open navigation menu';

  /// Goes to the learning tree, which is the app's first route.
  ///
  /// By tapping the drawer entry rather than by going "back", because "back" is
  /// not available from a screen that was *pushed onto* the dashboard by a deep
  /// link, and because the drawer entry is the affordance the app offers.
  static List<Act> home() => [
    const OpenDrawer(),
    const TapAny(['Learning tree']),
  ];

  /// Opens the drawer and goes to one of its destinations.
  static List<Act> to(String label) => [
    const OpenDrawer(),
    TapAny([label]),
  ];

  /// Cycles.
  static List<Act> get cycles => to('Learning cycles');

  /// Plans.
  static List<Act> get plans => to('Plans');

  /// Today's goals.
  static List<Act> get today => to("Today's goals");

  /// The planner calendar.
  static List<Act> get calendar => to('Planner calendar');

  /// Reports.
  static List<Act> get reports => to('Reports');

  /// The notes journal.
  static List<Act> get journal => to('Notes Journal');

  /// Profiles.
  static List<Act> get profiles => to('Profiles');

  /// Add a custom sefer.
  static List<Act> get addSefer => to('Add custom sefer');

  /// Settings.
  static List<Act> get settings => to('Settings');

  /// The report screen's other tabs, which are reached from inside Reports.
  static List<Act> reportTab(String label) => [
    ...reports,
    TapAny([label]),
  ];
}

/// The steps every journey starts with, unless it is deliberately about where it
/// starts.
///
/// A journey that begins from wherever the last one left the app is not
/// repeatable, and a journey that begins by pushing a route is not running as a
/// person does. So: home first, always.
List<Act> startAtHome() => Nav.home();

/// Closes anything open — a sheet, a dialog, the drawer — and gets back to the
/// tree.
///
/// Used between journeys rather than between steps, because "make sure the app
/// is in a known place" is a harness concern and not something a person does
/// mid-task.
///
/// **This used to press Escape twice, and that was the bug that failed 34 of 35
/// journeys on the first device run.** Escape is a desktop idiom: Android's
/// drawer does not listen for it, so the drawer stayed open, its scrim covered
/// the app bar, and the next journey could not press the menu button that sits
/// under it. The system back gesture is what a person actually uses on both of
/// these phones, and [GoHome] is that.
List<Act> backToHome() => [const GoHome()];
