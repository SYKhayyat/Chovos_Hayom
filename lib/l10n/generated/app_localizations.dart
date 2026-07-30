import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// The application name. Shown in the dashboard app bar and the drawer header.
  ///
  /// In en, this message translates to:
  /// **'Chovos Hayom'**
  String get appTitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get actionFinish;

  /// No description provided for @actionMark.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get actionMark;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get actionRestore;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get actionReview;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// The button on a failure message that opens the crash log.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get actionDetails;

  /// No description provided for @labelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// No description provided for @labelRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get labelRequired;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get labelOptional;

  /// No description provided for @labelNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get labelNameEnglish;

  /// No description provided for @labelNameHebrew.
  ///
  /// In en, this message translates to:
  /// **'Name (Hebrew)'**
  String get labelNameHebrew;

  /// Under the paired English/Hebrew name fields on the custom-sefer and custom-meforish forms.
  ///
  /// In en, this message translates to:
  /// **'Either one is enough. The app shows whichever matches the language you are using, and falls back to the other.'**
  String get namePairHelp;

  /// The one failure sentence for every write. {what} is a phrase that completes '… failed', e.g. 'Marking Shabbos daf 2 learned'.
  ///
  /// In en, this message translates to:
  /// **'{what} failed.'**
  String writeFailed(String what);

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'There is nothing here.\n\n“{name}” is not a screen this version of the app has.'**
  String notFoundBody(String name);

  /// No description provided for @expandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get collapseAll;

  /// No description provided for @tooltipExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get tooltipExpand;

  /// No description provided for @tooltipCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get tooltipCollapse;

  /// No description provided for @tooltipSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get tooltipSort;

  /// No description provided for @tooltipSortActive.
  ///
  /// In en, this message translates to:
  /// **'Sort: {metric}'**
  String tooltipSortActive(String metric);

  /// No description provided for @tooltipSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tooltipSearch;

  /// No description provided for @tooltipStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get tooltipStatistics;

  /// No description provided for @tooltipSiyumCalculator.
  ///
  /// In en, this message translates to:
  /// **'Siyum calculator'**
  String get tooltipSiyumCalculator;

  /// No description provided for @tooltipAddCustomSefer.
  ///
  /// In en, this message translates to:
  /// **'Add custom sefer'**
  String get tooltipAddCustomSefer;

  /// No description provided for @nudgeHaventLearnedToday.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t learned yet today — pick something below!'**
  String get nudgeHaventLearnedToday;

  /// No description provided for @drawerProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}'**
  String drawerProfile(String name);

  /// No description provided for @navLearningCycles.
  ///
  /// In en, this message translates to:
  /// **'Learning cycles'**
  String get navLearningCycles;

  /// No description provided for @navGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get navGoals;

  /// No description provided for @navChazaraDue.
  ///
  /// In en, this message translates to:
  /// **'Chazara due'**
  String get navChazaraDue;

  /// No description provided for @navSiyumim.
  ///
  /// In en, this message translates to:
  /// **'Siyumim'**
  String get navSiyumim;

  /// No description provided for @navNotesJournal.
  ///
  /// In en, this message translates to:
  /// **'Notes Journal'**
  String get navNotesJournal;

  /// No description provided for @navMefarshimProgress.
  ///
  /// In en, this message translates to:
  /// **'Mefarshim progress'**
  String get navMefarshimProgress;

  /// No description provided for @navProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get navProfiles;

  /// No description provided for @navAddCustomSefer.
  ///
  /// In en, this message translates to:
  /// **'Add custom sefer'**
  String get navAddCustomSefer;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// The count under a node's progress bar. {percent} arrives pre-rounded to one decimal.
  ///
  /// In en, this message translates to:
  /// **'{learned} / {total}  ({percent}%)'**
  String progressCount(int learned, int total, String percent);

  /// The count beside one meforish's thin coverage line.
  ///
  /// In en, this message translates to:
  /// **'{learned}/{total}'**
  String meforishCoverage(int learned, int total);

  /// No description provided for @nodeMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mefarshim / edit / add / hide'**
  String get nodeMenuTooltip;

  /// No description provided for @menuMefarshim.
  ///
  /// In en, this message translates to:
  /// **'Mefarshim…'**
  String get menuMefarshim;

  /// No description provided for @menuBulkActions.
  ///
  /// In en, this message translates to:
  /// **'Finish all / clear all'**
  String get menuBulkActions;

  /// No description provided for @menuAddSubItem.
  ///
  /// In en, this message translates to:
  /// **'Add sub-item'**
  String get menuAddSubItem;

  /// No description provided for @menuCloneStructure.
  ///
  /// In en, this message translates to:
  /// **'Clone structure'**
  String get menuCloneStructure;

  /// No description provided for @menuHideDelete.
  ///
  /// In en, this message translates to:
  /// **'Hide / delete'**
  String get menuHideDelete;

  /// No description provided for @menuResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get menuResetToDefault;

  /// No description provided for @menuRemovePermanently.
  ///
  /// In en, this message translates to:
  /// **'Remove permanently'**
  String get menuRemovePermanently;

  /// No description provided for @hideNodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide “{name}”?'**
  String hideNodeTitle(String name);

  /// No description provided for @hideNodeBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from the tree. Your logged progress stays intact, and you can restore it with “Reset to default”.'**
  String get hideNodeBody;

  /// No description provided for @hideNodeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideNodeConfirm;

  /// No description provided for @whatCloning.
  ///
  /// In en, this message translates to:
  /// **'Cloning “{name}”'**
  String whatCloning(String name);

  /// No description provided for @clonedNode.
  ///
  /// In en, this message translates to:
  /// **'Cloned “{name}”'**
  String clonedNode(String name);

  /// No description provided for @whatHiding.
  ///
  /// In en, this message translates to:
  /// **'Hiding “{name}”'**
  String whatHiding(String name);

  /// No description provided for @whatResetting.
  ///
  /// In en, this message translates to:
  /// **'Resetting “{name}”'**
  String whatResetting(String name);

  /// No description provided for @unitLabelPerek.
  ///
  /// In en, this message translates to:
  /// **'perek'**
  String get unitLabelPerek;

  /// No description provided for @unitLabelDaf.
  ///
  /// In en, this message translates to:
  /// **'daf'**
  String get unitLabelDaf;

  /// No description provided for @unitLabelAmud.
  ///
  /// In en, this message translates to:
  /// **'amud'**
  String get unitLabelAmud;

  /// No description provided for @unitLabelSiman.
  ///
  /// In en, this message translates to:
  /// **'siman'**
  String get unitLabelSiman;

  /// No description provided for @unitLabelHalacha.
  ///
  /// In en, this message translates to:
  /// **'halacha'**
  String get unitLabelHalacha;

  /// No description provided for @unitLabelPage.
  ///
  /// In en, this message translates to:
  /// **'page'**
  String get unitLabelPage;

  /// No description provided for @unitLabelCustom.
  ///
  /// In en, this message translates to:
  /// **'unit'**
  String get unitLabelCustom;

  /// Fallback when a leaf has no unit type set.
  ///
  /// In en, this message translates to:
  /// **'unit'**
  String get unitLabelUnknown;

  /// A unit named by its type and number, e.g. 'daf 5'. Used wherever a unit has no name of its own.
  ///
  /// In en, this message translates to:
  /// **'{label} {number}'**
  String unitHeading(String label, int number);

  /// A leaf's size, e.g. '64 dapim'. {label} is already pluralised by unitLabelPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} {label}'**
  String unitCountWithLabel(int count, String label);

  /// No description provided for @unitLabelPluralPerek.
  ///
  /// In en, this message translates to:
  /// **'perakim'**
  String get unitLabelPluralPerek;

  /// No description provided for @unitLabelPluralDaf.
  ///
  /// In en, this message translates to:
  /// **'dapim'**
  String get unitLabelPluralDaf;

  /// No description provided for @unitLabelPluralAmud.
  ///
  /// In en, this message translates to:
  /// **'amudim'**
  String get unitLabelPluralAmud;

  /// No description provided for @unitLabelPluralSiman.
  ///
  /// In en, this message translates to:
  /// **'simanim'**
  String get unitLabelPluralSiman;

  /// No description provided for @unitLabelPluralHalacha.
  ///
  /// In en, this message translates to:
  /// **'halachos'**
  String get unitLabelPluralHalacha;

  /// No description provided for @unitLabelPluralPage.
  ///
  /// In en, this message translates to:
  /// **'pages'**
  String get unitLabelPluralPage;

  /// No description provided for @unitLabelPluralCustom.
  ///
  /// In en, this message translates to:
  /// **'units'**
  String get unitLabelPluralCustom;

  /// No description provided for @unitLabelPluralUnknown.
  ///
  /// In en, this message translates to:
  /// **'units'**
  String get unitLabelPluralUnknown;

  /// A unit qualified by its sefer, e.g. 'Shabbos · daf 12'.
  ///
  /// In en, this message translates to:
  /// **'{node} · {unit}'**
  String nodeAndUnit(String node, String unit);

  /// No description provided for @tooltipBulkActions.
  ///
  /// In en, this message translates to:
  /// **'Finish all / clear all'**
  String get tooltipBulkActions;

  /// No description provided for @tooltipMefarshim.
  ///
  /// In en, this message translates to:
  /// **'Mefarshim'**
  String get tooltipMefarshim;

  /// No description provided for @tooltipSetGoalDate.
  ///
  /// In en, this message translates to:
  /// **'Set goal date'**
  String get tooltipSetGoalDate;

  /// Screen-reader label for a completed unit cell. Completion is shown visually by colour alone, so it has to be said here.
  ///
  /// In en, this message translates to:
  /// **'{unit}, learned'**
  String gridCellSemanticDone(String unit);

  /// No description provided for @gridCellSemanticNotDone.
  ///
  /// In en, this message translates to:
  /// **'{unit}, not learned'**
  String gridCellSemanticNotDone(String unit);

  /// No description provided for @gridCellSemanticPartial.
  ///
  /// In en, this message translates to:
  /// **'{unit}, partly learned, {percent}%'**
  String gridCellSemanticPartial(String unit, int percent);

  /// No description provided for @gridCellSemanticReviews.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chazara} other{{count} chazaras}}'**
  String gridCellSemanticReviews(int count);

  /// No description provided for @gridCellSemanticHasDetails.
  ///
  /// In en, this message translates to:
  /// **'has recorded details'**
  String get gridCellSemanticHasDetails;

  /// No description provided for @whatMarkingLearned.
  ///
  /// In en, this message translates to:
  /// **'Marking {unit} learned'**
  String whatMarkingLearned(String unit);

  /// No description provided for @whatUnmarking.
  ///
  /// In en, this message translates to:
  /// **'Un-marking {unit}'**
  String whatUnmarking(String unit);

  /// No description provided for @whatLogging.
  ///
  /// In en, this message translates to:
  /// **'Logging {unit}'**
  String whatLogging(String unit);

  /// No description provided for @whatSettingGoal.
  ///
  /// In en, this message translates to:
  /// **'Setting a goal for {name}'**
  String whatSettingGoal(String name);

  /// No description provided for @cellMenuViewEditDetails.
  ///
  /// In en, this message translates to:
  /// **'View / edit details'**
  String get cellMenuViewEditDetails;

  /// No description provided for @cellMenuViewEditDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you finished, how long, your note'**
  String get cellMenuViewEditDetailsSubtitle;

  /// No description provided for @cellMenuRelog.
  ///
  /// In en, this message translates to:
  /// **'Re-log with date / duration / note'**
  String get cellMenuRelog;

  /// No description provided for @cellMenuLog.
  ///
  /// In en, this message translates to:
  /// **'Log with date / duration / note'**
  String get cellMenuLog;

  /// No description provided for @cellMenuAddChazara.
  ///
  /// In en, this message translates to:
  /// **'Add chazara (review)'**
  String get cellMenuAddChazara;

  /// No description provided for @cellMenuUnmark.
  ///
  /// In en, this message translates to:
  /// **'Un-mark'**
  String get cellMenuUnmark;

  /// No description provided for @cellMenuMarkLearned.
  ///
  /// In en, this message translates to:
  /// **'Mark learned'**
  String get cellMenuMarkLearned;

  /// No description provided for @seferMissing.
  ///
  /// In en, this message translates to:
  /// **'This sefer no longer exists.\nIt may have been hidden, deleted, or replaced.'**
  String get seferMissing;

  /// No description provided for @itemMissing.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists.\nIt may have been hidden or deleted.'**
  String get itemMissing;

  /// No description provided for @itemMissingRenamed.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists.\nIt may have been removed or renamed.'**
  String get itemMissingRenamed;

  /// No description provided for @cycleMissing.
  ///
  /// In en, this message translates to:
  /// **'This cycle no longer exists.\nIt may have been deleted, or it belongs to another profile.'**
  String get cycleMissing;

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached! 🎉'**
  String get goalReached;

  /// No description provided for @goalBanner.
  ///
  /// In en, this message translates to:
  /// **'Goal {date} · need {rate}/day · {status}'**
  String goalBanner(String date, String rate, String status);

  /// No description provided for @goalOnTrack.
  ///
  /// In en, this message translates to:
  /// **'on track'**
  String get goalOnTrack;

  /// No description provided for @goalBehind.
  ///
  /// In en, this message translates to:
  /// **'behind'**
  String get goalBehind;

  /// No description provided for @tooltipRemoveGoal.
  ///
  /// In en, this message translates to:
  /// **'Remove goal'**
  String get tooltipRemoveGoal;

  /// No description provided for @whatRemovingGoal.
  ///
  /// In en, this message translates to:
  /// **'Removing the goal for {name}'**
  String whatRemovingGoal(String name);

  /// No description provided for @goalRemoved.
  ///
  /// In en, this message translates to:
  /// **'Goal removed'**
  String get goalRemoved;

  /// No description provided for @whatRestoringGoal.
  ///
  /// In en, this message translates to:
  /// **'Restoring the goal for {name}'**
  String whatRestoringGoal(String name);

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsTitle;

  /// No description provided for @goalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No goals yet.\nOpen any sefer and tap the flag to set a target date.'**
  String get goalsEmpty;

  /// No description provided for @goalRowReached.
  ///
  /// In en, this message translates to:
  /// **'Reached!'**
  String get goalRowReached;

  /// No description provided for @goalRowStatus.
  ///
  /// In en, this message translates to:
  /// **'By {date} · need {rate}/day · {status}'**
  String goalRowStatus(String date, String rate, String status);

  /// No description provided for @goalRemovedFor.
  ///
  /// In en, this message translates to:
  /// **'Goal for “{name}” removed'**
  String goalRemovedFor(String name);

  /// No description provided for @layersComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete — all required mefarshim learned.'**
  String get layersComplete;

  /// No description provided for @layersRemaining.
  ///
  /// In en, this message translates to:
  /// **'{missing} of {total} required still to learn.'**
  String layersRemaining(int missing, int total);

  /// Stands in for a meforish id whose definition was deleted after a unit was marked with it.
  ///
  /// In en, this message translates to:
  /// **'Deleted meforish'**
  String get deletedMeforish;

  /// No description provided for @markAllRequiredLearned.
  ///
  /// In en, this message translates to:
  /// **'Mark all required learned'**
  String get markAllRequiredLearned;

  /// No description provided for @logWithDateDurationHaara.
  ///
  /// In en, this message translates to:
  /// **'Log with date / duration / haara…'**
  String get logWithDateDurationHaara;

  /// No description provided for @clearThisUnit.
  ///
  /// In en, this message translates to:
  /// **'Clear this unit'**
  String get clearThisUnit;

  /// No description provided for @whatMarkingLayer.
  ///
  /// In en, this message translates to:
  /// **'Marking {layer} on {unit}'**
  String whatMarkingLayer(String layer, String unit);

  /// No description provided for @whatUnmarkingLayer.
  ///
  /// In en, this message translates to:
  /// **'Un-marking {layer} on {unit}'**
  String whatUnmarkingLayer(String layer, String unit);

  /// No description provided for @whatMarkingEveryRequired.
  ///
  /// In en, this message translates to:
  /// **'Marking every required meforish on {unit}'**
  String whatMarkingEveryRequired(String unit);

  /// No description provided for @whatClearingUnit.
  ///
  /// In en, this message translates to:
  /// **'Clearing {unit}'**
  String whatClearingUnit(String unit);

  /// No description provided for @logSheetWhatYouLearned.
  ///
  /// In en, this message translates to:
  /// **'What you learned:'**
  String get logSheetWhatYouLearned;

  /// No description provided for @logSheetManualDateTime.
  ///
  /// In en, this message translates to:
  /// **'Set date & time manually'**
  String get logSheetManualDateTime;

  /// No description provided for @logSheetDefaultsToNow.
  ///
  /// In en, this message translates to:
  /// **'Defaults to now'**
  String get logSheetDefaultsToNow;

  /// No description provided for @logSheetPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get logSheetPickDate;

  /// No description provided for @logSheetPickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick time'**
  String get logSheetPickTime;

  /// {clock} is an elapsed MM:SS readout.
  ///
  /// In en, this message translates to:
  /// **'Timer  {clock}'**
  String logSheetTimer(String clock);

  /// No description provided for @logSheetStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get logSheetStart;

  /// No description provided for @logSheetStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get logSheetStop;

  /// No description provided for @logSheetKeepsRunning.
  ///
  /// In en, this message translates to:
  /// **'Keeps running if you close this — go learn.'**
  String get logSheetKeepsRunning;

  /// No description provided for @logSheetDuration.
  ///
  /// In en, this message translates to:
  /// **'How long it took (minutes, optional)'**
  String get logSheetDuration;

  /// No description provided for @logSheetHaara.
  ///
  /// In en, this message translates to:
  /// **'Haara (optional)'**
  String get logSheetHaara;

  /// No description provided for @logSheetHaaraHint.
  ///
  /// In en, this message translates to:
  /// **'A chiddush, a question, a maareh makom, how it went…'**
  String get logSheetHaaraHint;

  /// No description provided for @logSheetHaaraHelper.
  ///
  /// In en, this message translates to:
  /// **'Collected in your Notes Journal.'**
  String get logSheetHaaraHelper;

  /// No description provided for @logSheetMarkLearned.
  ///
  /// In en, this message translates to:
  /// **'Mark learned'**
  String get logSheetMarkLearned;

  /// No description provided for @logSheetSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get logSheetSaveChanges;

  /// No description provided for @whatStartingTimer.
  ///
  /// In en, this message translates to:
  /// **'Starting the session timer'**
  String get whatStartingTimer;

  /// No description provided for @whatPausingTimer.
  ///
  /// In en, this message translates to:
  /// **'Pausing the session timer'**
  String get whatPausingTimer;

  /// No description provided for @whatResettingTimer.
  ///
  /// In en, this message translates to:
  /// **'Resetting the session timer'**
  String get whatResettingTimer;

  /// No description provided for @whatEndingTimer.
  ///
  /// In en, this message translates to:
  /// **'Ending the session timer'**
  String get whatEndingTimer;

  /// No description provided for @dateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String dateTimeLabel(String date, String time);

  /// No description provided for @addChazaraTitle.
  ///
  /// In en, this message translates to:
  /// **'Add chazara'**
  String get addChazaraTitle;

  /// No description provided for @addChazaraReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed:'**
  String get addChazaraReviewed;

  /// No description provided for @addChazaraDuration.
  ///
  /// In en, this message translates to:
  /// **'How long (minutes, optional)'**
  String get addChazaraDuration;

  /// No description provided for @addChazaraSubmit.
  ///
  /// In en, this message translates to:
  /// **'Log chazara'**
  String get addChazaraSubmit;

  /// No description provided for @whatLoggingChazara.
  ///
  /// In en, this message translates to:
  /// **'Logging a chazara on {unit}'**
  String whatLoggingChazara(String unit);

  /// No description provided for @detailsNotLearnedYet.
  ///
  /// In en, this message translates to:
  /// **'Not learned yet.'**
  String get detailsNotLearnedYet;

  /// No description provided for @detailsFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get detailsFinished;

  /// No description provided for @detailsTimeToLearn.
  ///
  /// In en, this message translates to:
  /// **'Time to learn'**
  String get detailsTimeToLearn;

  /// No description provided for @detailsNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get detailsNotRecorded;

  /// No description provided for @detailsChazaraPasses.
  ///
  /// In en, this message translates to:
  /// **'Chazara passes'**
  String get detailsChazaraPasses;

  /// No description provided for @detailsNoneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get detailsNoneYet;

  /// No description provided for @detailsHaara.
  ///
  /// In en, this message translates to:
  /// **'Haara'**
  String get detailsHaara;

  /// No description provided for @detailsNoHaara.
  ///
  /// In en, this message translates to:
  /// **'No haara'**
  String get detailsNoHaara;

  /// No description provided for @detailsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get detailsEdit;

  /// No description provided for @detailsAddChazara.
  ///
  /// In en, this message translates to:
  /// **'Add chazara'**
  String get detailsAddChazara;

  /// No description provided for @detailsUnmark.
  ///
  /// In en, this message translates to:
  /// **'Un-mark'**
  String get detailsUnmark;

  /// No description provided for @detailsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit · {unit}'**
  String detailsEditTitle(String unit);

  /// No description provided for @chazaraPass.
  ///
  /// In en, this message translates to:
  /// **'Pass {n}'**
  String chazaraPass(int n);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String minutesShort(int minutes);

  /// No description provided for @whatSavingDetails.
  ///
  /// In en, this message translates to:
  /// **'Saving the details for {unit}'**
  String whatSavingDetails(String unit);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @bulkTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk actions'**
  String get bulkTitle;

  /// No description provided for @bulkAllUnitsUnderneath.
  ///
  /// In en, this message translates to:
  /// **'{name} · all units underneath'**
  String bulkAllUnitsUnderneath(String name);

  /// No description provided for @bulkFinishAll.
  ///
  /// In en, this message translates to:
  /// **'Finish all'**
  String get bulkFinishAll;

  /// No description provided for @bulkFinishAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark every unit’s required mefarshim done'**
  String get bulkFinishAllSubtitle;

  /// No description provided for @bulkMarkAllLayer.
  ///
  /// In en, this message translates to:
  /// **'Mark all — {layer}'**
  String bulkMarkAllLayer(String layer);

  /// No description provided for @bulkMainTextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The primary text on every unit'**
  String get bulkMainTextSubtitle;

  /// No description provided for @bulkFinishRange.
  ///
  /// In en, this message translates to:
  /// **'Finish a range…'**
  String get bulkFinishRange;

  /// No description provided for @bulkFinishRangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a start and end unit'**
  String get bulkFinishRangeSubtitle;

  /// No description provided for @bulkClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get bulkClearAll;

  /// No description provided for @bulkClearAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Un-mark every unit (and its mefarshim)'**
  String get bulkClearAllSubtitle;

  /// No description provided for @bulkNothingToChange.
  ///
  /// In en, this message translates to:
  /// **'Nothing to change'**
  String get bulkNothingToChange;

  /// The count is the whole point of the confirmation — finishing one mesechta and finishing Shas look identical until you see 64 versus 12,092.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This changes 1 unit.} other{This changes {count} units.}}'**
  String bulkConfirmUnits(int count);

  /// No description provided for @bulkUndoNote.
  ///
  /// In en, this message translates to:
  /// **'You can undo it from Settings → Bulk action history for as long as you like.'**
  String get bulkUndoNote;

  /// No description provided for @bulkFinishAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish all of “{name}”?'**
  String bulkFinishAllTitle(String name);

  /// No description provided for @bulkWhatFinishingAll.
  ///
  /// In en, this message translates to:
  /// **'Finishing all of “{name}”'**
  String bulkWhatFinishingAll(String name);

  /// No description provided for @bulkMarkLayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark {layer} on all of “{name}”?'**
  String bulkMarkLayerTitle(String layer, String name);

  /// No description provided for @bulkWhatMarkingLayer.
  ///
  /// In en, this message translates to:
  /// **'Marking {layer} on all of “{name}”'**
  String bulkWhatMarkingLayer(String layer, String name);

  /// No description provided for @bulkClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all of “{name}”?'**
  String bulkClearAllTitle(String name);

  /// No description provided for @bulkWhatClearingAll.
  ///
  /// In en, this message translates to:
  /// **'Clearing all of “{name}”'**
  String bulkWhatClearingAll(String name);

  /// No description provided for @bulkClearWarningLeaf.
  ///
  /// In en, this message translates to:
  /// **'Un-marks every unit here, including any mefarshim you checked off.'**
  String get bulkClearWarningLeaf;

  /// No description provided for @bulkClearWarningCategory.
  ///
  /// In en, this message translates to:
  /// **'Un-marks every unit under this — including all its mefarshim.'**
  String get bulkClearWarningCategory;

  /// No description provided for @bulkRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish units {start}–{end} of “{name}”?'**
  String bulkRangeTitle(int start, int end, String name);

  /// No description provided for @bulkWhatFinishingRange.
  ///
  /// In en, this message translates to:
  /// **'Finishing units {start}–{end} of “{name}”'**
  String bulkWhatFinishingRange(int start, int end, String name);

  /// No description provided for @bulkReportFinished.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Finished 1 unit} other{Finished {count} units}}'**
  String bulkReportFinished(int count);

  /// No description provided for @bulkReportCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Cleared 1 unit} other{Cleared {count} units}}'**
  String bulkReportCleared(int count);

  /// No description provided for @bulkReportMarkedLayer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Marked {layer} on 1 unit} other{Marked {layer} on {count} units}}'**
  String bulkReportMarkedLayer(int count, String layer);

  /// No description provided for @bulkReportFinishedRange.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Finished 1 unit in {start}–{end}} other{Finished {count} units in {start}–{end}}}'**
  String bulkReportFinishedRange(int count, int start, int end);

  /// No description provided for @whatUndoingBulk.
  ///
  /// In en, this message translates to:
  /// **'Undoing that bulk action'**
  String get whatUndoingBulk;

  /// No description provided for @rangeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish a range'**
  String get rangeDialogTitle;

  /// No description provided for @rangeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Units {first}–{last}. Both ends included.'**
  String rangeDialogBody(int first, int last);

  /// No description provided for @rangeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get rangeFrom;

  /// No description provided for @rangeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get rangeTo;

  /// No description provided for @rangeErrorTwoNumbers.
  ///
  /// In en, this message translates to:
  /// **'Enter two numbers.'**
  String get rangeErrorTwoNumbers;

  /// No description provided for @rangeErrorBounds.
  ///
  /// In en, this message translates to:
  /// **'Units run from {first} to {last}.'**
  String rangeErrorBounds(int first, int last);

  /// No description provided for @bulkHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk action history'**
  String get bulkHistoryTitle;

  /// No description provided for @bulkHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bulk actions yet.\n\nAnything you finish or clear in bulk shows up here, and stays undoable until you undo it.'**
  String get bulkHistoryEmpty;

  /// No description provided for @bulkHistoryFinishedEntry.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Finished 1 unit} other{Finished {count} units}} · {where}'**
  String bulkHistoryFinishedEntry(int count, String where);

  /// No description provided for @bulkHistoryClearedEntry.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Cleared 1 unit} other{Cleared {count} units}} · {where}'**
  String bulkHistoryClearedEntry(int count, String where);

  /// No description provided for @bulkHistorySefarimCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sefer} other{{count} sefarim}}'**
  String bulkHistorySefarimCount(int count);

  /// No description provided for @bulkHistoryWhereWithCount.
  ///
  /// In en, this message translates to:
  /// **'{name} ({count, plural, =1{1 sefer} other{{count} sefarim}})'**
  String bulkHistoryWhereWithCount(String name, int count);

  /// No description provided for @bulkHistoryUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo this bulk action?'**
  String get bulkHistoryUndoTitle;

  /// No description provided for @bulkHistoryUndoFinishBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removes the 1 mark this action made.} other{Removes the {count} marks this action made.}} Anything you had learned before it is untouched.'**
  String bulkHistoryUndoFinishBody(int count);

  /// No description provided for @bulkHistoryUndoClearBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restores the 1 unit this action cleared.} other{Restores the {count} units this action cleared.}}'**
  String bulkHistoryUndoClearBody(int count);

  /// No description provided for @whatUndoingThisBulk.
  ///
  /// In en, this message translates to:
  /// **'Undoing this bulk action'**
  String get whatUndoingThisBulk;

  /// No description provided for @bulkHistoryUndone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Undone — 1 event removed} other{Undone — {count} events removed}}'**
  String bulkHistoryUndone(int count);

  /// No description provided for @mefarshimTitle.
  ///
  /// In en, this message translates to:
  /// **'Mefarshim'**
  String get mefarshimTitle;

  /// No description provided for @mefarshimExplainer.
  ///
  /// In en, this message translates to:
  /// **'“Available” = you can check it off here. “Required” = a unit is done only once it’s learned. Applies to everything under this item unless overridden.'**
  String get mefarshimExplainer;

  /// No description provided for @mefarshimSetHere.
  ///
  /// In en, this message translates to:
  /// **'Set on this item.'**
  String get mefarshimSetHere;

  /// No description provided for @mefarshimInheritedFrom.
  ///
  /// In en, this message translates to:
  /// **'Inherited from {name}. Saving pins them here.'**
  String mefarshimInheritedFrom(String name);

  /// No description provided for @mefarshimDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (text only). Saving pins a set here.'**
  String get mefarshimDefault;

  /// No description provided for @mefarshimAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get mefarshimAvailable;

  /// No description provided for @mefarshimAddMeforish.
  ///
  /// In en, this message translates to:
  /// **'Add a meforish'**
  String get mefarshimAddMeforish;

  /// No description provided for @mefarshimResetToInherited.
  ///
  /// In en, this message translates to:
  /// **'Reset to inherited'**
  String get mefarshimResetToInherited;

  /// No description provided for @mefarshimNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New meforish'**
  String get mefarshimNewTitle;

  /// No description provided for @mefarshimEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit “{name}”'**
  String mefarshimEditTitle(String name);

  /// No description provided for @mefarshimNeedName.
  ///
  /// In en, this message translates to:
  /// **'Give the meforish a name, in either language.'**
  String get mefarshimNeedName;

  /// No description provided for @tooltipEditMeforish.
  ///
  /// In en, this message translates to:
  /// **'Edit meforish'**
  String get tooltipEditMeforish;

  /// No description provided for @whatSavingMeforish.
  ///
  /// In en, this message translates to:
  /// **'Saving the meforish “{name}”'**
  String whatSavingMeforish(String name);

  /// No description provided for @mefarshimHebrewOptional.
  ///
  /// In en, this message translates to:
  /// **'Hebrew (optional)'**
  String get mefarshimHebrewOptional;

  /// No description provided for @tooltipDeleteMeforish.
  ///
  /// In en, this message translates to:
  /// **'Delete meforish'**
  String get tooltipDeleteMeforish;

  /// No description provided for @mefarshimDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String mefarshimDeleteTitle(String name);

  /// No description provided for @mefarshimDeleteRequiredWarning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It is currently required in 1 place.} other{It is currently required in {count} places.}} Those units will go back to not needing it, so anything they were waiting on it for becomes complete.'**
  String mefarshimDeleteRequiredWarning(int count);

  /// No description provided for @mefarshimDeleteLogNote.
  ///
  /// In en, this message translates to:
  /// **'Chazaras and learning you already recorded against it stay in your log.'**
  String get mefarshimDeleteLogNote;

  /// No description provided for @whatSavingMefarshim.
  ///
  /// In en, this message translates to:
  /// **'Saving the mefarshim for {name}'**
  String whatSavingMefarshim(String name);

  /// No description provided for @whatResettingMefarshim.
  ///
  /// In en, this message translates to:
  /// **'Resetting the mefarshim for {name}'**
  String whatResettingMefarshim(String name);

  /// No description provided for @whatDeletingMeforish.
  ///
  /// In en, this message translates to:
  /// **'Deleting “{name}”'**
  String whatDeletingMeforish(String name);

  /// No description provided for @whatAddingMeforish.
  ///
  /// In en, this message translates to:
  /// **'Adding the meforish “{name}”'**
  String whatAddingMeforish(String name);

  /// No description provided for @mefarshimProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Mefarshim progress'**
  String get mefarshimProgressTitle;

  /// No description provided for @mefarshimProgressEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing learned yet.\nAs you check off mefarshim, their totals appear here.'**
  String get mefarshimProgressEmpty;

  /// No description provided for @chazaraTitle.
  ///
  /// In en, this message translates to:
  /// **'Chazara due'**
  String get chazaraTitle;

  /// No description provided for @chazaraEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing due for review right now.\nLearned units come back here on a spaced schedule.'**
  String get chazaraEmpty;

  /// No description provided for @chazaraDueToday.
  ///
  /// In en, this message translates to:
  /// **'due today'**
  String get chazaraDueToday;

  /// No description provided for @chazaraOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day overdue} other{{count} days overdue}}'**
  String chazaraOverdue(int count);

  /// No description provided for @chazaraRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{overdue} · {count, plural, =0{no reviews so far} =1{1 review so far} other{{count} reviews so far}}'**
  String chazaraRowSubtitle(String overdue, int count);

  /// No description provided for @chazaraLogWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Log with details'**
  String get chazaraLogWithDetails;

  /// No description provided for @chazaraReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed {unit}'**
  String chazaraReviewed(String unit);

  /// No description provided for @siyumTitle.
  ///
  /// In en, this message translates to:
  /// **'Siyumim'**
  String get siyumTitle;

  /// No description provided for @siyumEmpty.
  ///
  /// In en, this message translates to:
  /// **'No siyumim yet.\nFinish every unit of a sefer — or of a whole seder — and it will appear here. חזק!'**
  String get siyumEmpty;

  /// No description provided for @siyumCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 siyum} other{{count} siyumim}} — יישר כח!'**
  String siyumCount(int count);

  /// No description provided for @siyumCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed {date} · {units}'**
  String siyumCompleted(String date, String units);

  /// No description provided for @siyumEverythingUnderneath.
  ///
  /// In en, this message translates to:
  /// **' · everything underneath'**
  String get siyumEverythingUnderneath;

  /// No description provided for @journalTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes Journal'**
  String get journalTitle;

  /// No description provided for @journalSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search haaros…'**
  String get journalSearchHint;

  /// No description provided for @journalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No haaros yet.\nAdd one when you log or edit a daf — the “Haara” field lands here.'**
  String get journalEmpty;

  /// No description provided for @journalNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No haaros match “{query}”.'**
  String journalNoMatches(String query);

  /// No description provided for @journalUnknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown item'**
  String get journalUnknownItem;

  /// No description provided for @journalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{location} · {date}'**
  String journalSubtitle(String location, String date);

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search sefarim, mesechtos, dafim…'**
  String get searchPrompt;

  /// No description provided for @searchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches.'**
  String get searchNoMatches;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get statsOverall;

  /// No description provided for @statsLearned.
  ///
  /// In en, this message translates to:
  /// **'Learned'**
  String get statsLearned;

  /// No description provided for @statsStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statsStreak;

  /// No description provided for @statsStreakValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String statsStreakValue(int count);

  /// No description provided for @statsAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg / day (30d)'**
  String get statsAvgPerDay;

  /// No description provided for @statsTimeLearned.
  ///
  /// In en, this message translates to:
  /// **'Time learned'**
  String get statsTimeLearned;

  /// No description provided for @statsTimeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Time this month'**
  String get statsTimeThisMonth;

  /// No description provided for @statsProjectedSiyum.
  ///
  /// In en, this message translates to:
  /// **'Projected siyum'**
  String get statsProjectedSiyum;

  /// No description provided for @statsLearnedValue.
  ///
  /// In en, this message translates to:
  /// **'{learned} / {total}'**
  String statsLearnedValue(int learned, int total);

  /// No description provided for @statsPercentValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String statsPercentValue(String percent);

  /// No description provided for @statsNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get statsNone;

  /// No description provided for @statsProgressOverTime.
  ///
  /// In en, this message translates to:
  /// **'Progress over time'**
  String get statsProgressOverTime;

  /// No description provided for @statsActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity (last 12 weeks)'**
  String get statsActivity;

  /// No description provided for @statsNeedMoreData.
  ///
  /// In en, this message translates to:
  /// **'Learn a few units to see your trend.'**
  String get statsNeedMoreData;

  /// No description provided for @calculatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Siyum Calculator'**
  String get calculatorTitle;

  /// No description provided for @calculatorWhatFinishing.
  ///
  /// In en, this message translates to:
  /// **'What are you finishing?'**
  String get calculatorWhatFinishing;

  /// No description provided for @calculatorRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {total} left'**
  String calculatorRemaining(int remaining, int total);

  /// No description provided for @calculatorModeRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get calculatorModeRate;

  /// No description provided for @calculatorModeCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get calculatorModeCycle;

  /// No description provided for @calculatorModeByDate.
  ///
  /// In en, this message translates to:
  /// **'By date'**
  String get calculatorModeByDate;

  /// No description provided for @calculatorAmountPerDay.
  ///
  /// In en, this message translates to:
  /// **'Amount per day'**
  String get calculatorAmountPerDay;

  /// No description provided for @calculatorAmountShabbos.
  ///
  /// In en, this message translates to:
  /// **'Amount on Shabbos (optional)'**
  String get calculatorAmountShabbos;

  /// No description provided for @calculatorCycleAmounts.
  ///
  /// In en, this message translates to:
  /// **'Cycle amounts (comma-separated, one per day)'**
  String get calculatorCycleAmounts;

  /// No description provided for @calculatorCycleAmountsHelper.
  ///
  /// In en, this message translates to:
  /// **'e.g. “5, 5, 5, 5, 5, 0, 10” is a 7-day cycle'**
  String get calculatorCycleAmountsHelper;

  /// No description provided for @calculatorCycleDay.
  ///
  /// In en, this message translates to:
  /// **'Which cycle-day is today?'**
  String get calculatorCycleDay;

  /// No description provided for @calculatorCycleDayHelper.
  ///
  /// In en, this message translates to:
  /// **'1 = first amount above; 4 = you are on day 4'**
  String get calculatorCycleDayHelper;

  /// No description provided for @calculatorTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {date}'**
  String calculatorTarget(String date);

  /// No description provided for @calculatorPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get calculatorPickDate;

  /// No description provided for @calculatorAlreadyFinished.
  ///
  /// In en, this message translates to:
  /// **'Already finished! 🎉'**
  String get calculatorAlreadyFinished;

  /// No description provided for @calculatorEnterDailyAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a daily amount above 0.'**
  String get calculatorEnterDailyAmount;

  /// No description provided for @calculatorEnterAmounts.
  ///
  /// In en, this message translates to:
  /// **'Enter amounts, e.g. “5, 5, 0, 10”.'**
  String get calculatorEnterAmounts;

  /// No description provided for @calculatorCycleNeverFinishes.
  ///
  /// In en, this message translates to:
  /// **'That cycle never finishes (all zeros).'**
  String get calculatorCycleNeverFinishes;

  /// No description provided for @calculatorPickFutureDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date in the future.'**
  String get calculatorPickFutureDate;

  /// No description provided for @calculatorNeverFinish.
  ///
  /// In en, this message translates to:
  /// **'At that rate you never finish.'**
  String get calculatorNeverFinish;

  /// No description provided for @calculatorFinishOn.
  ///
  /// In en, this message translates to:
  /// **'You will finish on {date}\n(about {days, plural, =1{1 day} other{{days} days}} from today).'**
  String calculatorFinishOn(String date, int days);

  /// No description provided for @calculatorCycleLength.
  ///
  /// In en, this message translates to:
  /// **'\nCycle length: {days, plural, =1{1 day} other{{days} days}}.'**
  String calculatorCycleLength(int days);

  /// No description provided for @calculatorRequiredRate.
  ///
  /// In en, this message translates to:
  /// **'Learn {rate} per day to finish by\n{date}.'**
  String calculatorRequiredRate(String rate, String date);

  /// No description provided for @cyclesTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning cycles'**
  String get cyclesTitle;

  /// No description provided for @cyclesWhichToShow.
  ///
  /// In en, this message translates to:
  /// **'Which cycles to show'**
  String get cyclesWhichToShow;

  /// No description provided for @cyclesNew.
  ///
  /// In en, this message translates to:
  /// **'New cycle'**
  String get cyclesNew;

  /// No description provided for @cyclesToday.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String cyclesToday(String date);

  /// No description provided for @cyclesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cycles yet. Turn on a built-in one, or define your own — any sefarim, in any order, at any pace.'**
  String get cyclesEmpty;

  /// No description provided for @cyclesBuiltInExplainer.
  ///
  /// In en, this message translates to:
  /// **'Built-in cycles are the ones the Hebrew calendar can work out exactly. For anything else, define your own.'**
  String get cyclesBuiltInExplainer;

  /// No description provided for @cycleBavliName.
  ///
  /// In en, this message translates to:
  /// **'Daf Yomi (Bavli)'**
  String get cycleBavliName;

  /// No description provided for @cycleBavliDescription.
  ///
  /// In en, this message translates to:
  /// **'One daf of Talmud Bavli a day'**
  String get cycleBavliDescription;

  /// No description provided for @cycleYerushalmiName.
  ///
  /// In en, this message translates to:
  /// **'Daf Yomi (Yerushalmi)'**
  String get cycleYerushalmiName;

  /// No description provided for @cycleYerushalmiDescription.
  ///
  /// In en, this message translates to:
  /// **'One daf of Talmud Yerushalmi a day'**
  String get cycleYerushalmiDescription;

  /// No description provided for @whatShowingCycle.
  ///
  /// In en, this message translates to:
  /// **'Showing {name}'**
  String whatShowingCycle(String name);

  /// No description provided for @whatHidingCycle.
  ///
  /// In en, this message translates to:
  /// **'Hiding {name}'**
  String whatHidingCycle(String name);

  /// No description provided for @cycleNumber.
  ///
  /// In en, this message translates to:
  /// **'{description} · cycle {number}'**
  String cycleNumber(String description, int number);

  /// No description provided for @tooltipEditCycle.
  ///
  /// In en, this message translates to:
  /// **'Edit cycle'**
  String get tooltipEditCycle;

  /// No description provided for @cycleNothingToday.
  ///
  /// In en, this message translates to:
  /// **'This cycle has nothing scheduled for today.'**
  String get cycleNothingToday;

  /// No description provided for @cycleDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String cycleDeleteTitle(String name);

  /// No description provided for @cycleDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Only the cycle is removed. Everything you learned through it stays in your log.'**
  String get cycleDeleteBody;

  /// No description provided for @whatDeletingCycle.
  ///
  /// In en, this message translates to:
  /// **'Deleting the cycle “{name}”'**
  String whatDeletingCycle(String name);

  /// No description provided for @cycleUnitOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'“{name}” doesn’t have a unit {unit}, so this can’t be logged. Check the sefer’s unit count, or link this cycle to a different one.'**
  String cycleUnitOutOfRange(String name, int unit);

  /// No description provided for @cycleAlreadyLearned.
  ///
  /// In en, this message translates to:
  /// **'Already learned ✓'**
  String get cycleAlreadyLearned;

  /// No description provided for @cycleLearnedOn.
  ///
  /// In en, this message translates to:
  /// **'Learned {date} ✓'**
  String cycleLearnedOn(String date);

  /// No description provided for @cycleLogButton.
  ///
  /// In en, this message translates to:
  /// **'Log {unit}'**
  String cycleLogButton(String unit);

  /// No description provided for @cycleLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged {unit}'**
  String cycleLogged(String unit);

  /// No description provided for @cycleSeferNotInCatalog.
  ///
  /// In en, this message translates to:
  /// **'“{name}” isn’t in your catalog under that name.'**
  String cycleSeferNotInCatalog(String name);

  /// No description provided for @cycleLinkToSefer.
  ///
  /// In en, this message translates to:
  /// **'Link it to a sefer'**
  String get cycleLinkToSefer;

  /// No description provided for @cycleLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Link “{name}” to…'**
  String cycleLinkTitle(String name);

  /// No description provided for @whatLinkingSefer.
  ///
  /// In en, this message translates to:
  /// **'Linking “{from}” to {to}'**
  String whatLinkingSefer(String from, String to);

  /// No description provided for @cycleLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked “{from}” to {to}'**
  String cycleLinked(String from, String to);

  /// The Hebrew-script line under a Daf Yomi heading. Kept Hebrew in every locale — it is the daf's own name.
  ///
  /// In en, this message translates to:
  /// **'{sefer} · דף {unit}'**
  String cycleDafHebrew(String sefer, int unit);

  /// No description provided for @editCycleTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit cycle'**
  String get editCycleTitle;

  /// No description provided for @newCycleTitle.
  ///
  /// In en, this message translates to:
  /// **'New cycle'**
  String get newCycleTitle;

  /// No description provided for @editCycleNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mishna Yomi, Rambam Yomi, my chazara seder'**
  String get editCycleNameHint;

  /// No description provided for @editCycleUnitsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Units per day'**
  String get editCycleUnitsPerDay;

  /// No description provided for @editCycleUnitsPerDayHelper.
  ///
  /// In en, this message translates to:
  /// **'Mishna Yomi is 2; a daf a day is 1.'**
  String get editCycleUnitsPerDayHelper;

  /// No description provided for @editCycleStartedOn.
  ///
  /// In en, this message translates to:
  /// **'Started on'**
  String get editCycleStartedOn;

  /// No description provided for @editCycleRepeats.
  ///
  /// In en, this message translates to:
  /// **'Starts over when it finishes'**
  String get editCycleRepeats;

  /// No description provided for @editCycleRepeatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off = a one-time programme'**
  String get editCycleRepeatsSubtitle;

  /// No description provided for @editCycleSefarimInOrder.
  ///
  /// In en, this message translates to:
  /// **'Sefarim, in order'**
  String get editCycleSefarimInOrder;

  /// No description provided for @editCycleTotalUnits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit} other{{count} units}}'**
  String editCycleTotalUnits(int count);

  /// No description provided for @editCycleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add the sefarim this cycle walks through.'**
  String get editCycleEmpty;

  /// No description provided for @editCycleAddSefer.
  ///
  /// In en, this message translates to:
  /// **'Add a sefer'**
  String get editCycleAddSefer;

  /// No description provided for @editCycleSaveExisting.
  ///
  /// In en, this message translates to:
  /// **'Save cycle'**
  String get editCycleSaveExisting;

  /// No description provided for @editCycleCreate.
  ///
  /// In en, this message translates to:
  /// **'Create cycle'**
  String get editCycleCreate;

  /// No description provided for @editCycleSegmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} units from {offset}'**
  String editCycleSegmentSubtitle(int count, int offset);

  /// No description provided for @tooltipMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get tooltipMoveUp;

  /// No description provided for @tooltipMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get tooltipMoveDown;

  /// No description provided for @tooltipRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tooltipRemove;

  /// No description provided for @editCycleAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a sefer or category'**
  String get editCycleAddDialogTitle;

  /// No description provided for @editCycleEverythingUnderneath.
  ///
  /// In en, this message translates to:
  /// **'everything underneath'**
  String get editCycleEverythingUnderneath;

  /// No description provided for @editCycleNeedName.
  ///
  /// In en, this message translates to:
  /// **'Give the cycle a name.'**
  String get editCycleNeedName;

  /// No description provided for @editCycleNeedPerDay.
  ///
  /// In en, this message translates to:
  /// **'Units per day must be at least 1.'**
  String get editCycleNeedPerDay;

  /// No description provided for @editCycleNeedSegment.
  ///
  /// In en, this message translates to:
  /// **'Add at least one sefer for the cycle to walk.'**
  String get editCycleNeedSegment;

  /// No description provided for @whatSavingCycle.
  ///
  /// In en, this message translates to:
  /// **'Saving the cycle “{name}”'**
  String whatSavingCycle(String name);

  /// No description provided for @addNodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addNodeTitle;

  /// No description provided for @editNodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit “{name}”'**
  String editNodeTitle(String name);

  /// No description provided for @addNodeHebrewName.
  ///
  /// In en, this message translates to:
  /// **'Hebrew name (optional)'**
  String get addNodeHebrewName;

  /// No description provided for @addNodeParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get addNodeParent;

  /// No description provided for @addNodeTopLevel.
  ///
  /// In en, this message translates to:
  /// **'— Top level —'**
  String get addNodeTopLevel;

  /// No description provided for @addNodeIsLeaf.
  ///
  /// In en, this message translates to:
  /// **'Trackable sefer (has units)'**
  String get addNodeIsLeaf;

  /// No description provided for @addNodeIsLeafSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off = a folder/category'**
  String get addNodeIsLeafSubtitle;

  /// No description provided for @addNodeUnitType.
  ///
  /// In en, this message translates to:
  /// **'Unit type'**
  String get addNodeUnitType;

  /// No description provided for @addNodeUnitCount.
  ///
  /// In en, this message translates to:
  /// **'Number of units'**
  String get addNodeUnitCount;

  /// No description provided for @addNodeFirstUnit.
  ///
  /// In en, this message translates to:
  /// **'First unit number'**
  String get addNodeFirstUnit;

  /// No description provided for @addNodeUnitNames.
  ///
  /// In en, this message translates to:
  /// **'Unit names (optional, one per line)'**
  String get addNodeUnitNames;

  /// No description provided for @addNodeUnitNamesHelper.
  ///
  /// In en, this message translates to:
  /// **'e.g. parsha or siman titles — shown instead of numbers, in order from the first unit.'**
  String get addNodeUnitNamesHelper;

  /// No description provided for @addNodeLoweringCount.
  ///
  /// In en, this message translates to:
  /// **'Lowering the count keeps any progress on the removed units hidden but intact — raise it again to restore them.'**
  String get addNodeLoweringCount;

  /// No description provided for @addNodeNeedName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name.'**
  String get addNodeNeedName;

  /// No description provided for @addNodeNeedNameEither.
  ///
  /// In en, this message translates to:
  /// **'Give it a name, in either language.'**
  String get addNodeNeedNameEither;

  /// No description provided for @addNodeNeedUnits.
  ///
  /// In en, this message translates to:
  /// **'Number of units must be greater than 0.'**
  String get addNodeNeedUnits;

  /// No description provided for @addNodeTooManyUnits.
  ///
  /// In en, this message translates to:
  /// **'That is more units than any sefer has.'**
  String get addNodeTooManyUnits;

  /// No description provided for @addNodeNegativeOffset.
  ///
  /// In en, this message translates to:
  /// **'The first unit number cannot be negative.'**
  String get addNodeNegativeOffset;

  /// No description provided for @addNodeTooManyNames.
  ///
  /// In en, this message translates to:
  /// **'You listed {names} unit names but only have {units} units.'**
  String addNodeTooManyNames(int names, int units);

  /// No description provided for @whatSavingNode.
  ///
  /// In en, this message translates to:
  /// **'Saving “{name}”'**
  String whatSavingNode(String name);

  /// No description provided for @whatAddingNode.
  ///
  /// In en, this message translates to:
  /// **'Adding “{name}”'**
  String whatAddingNode(String name);

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesTitle;

  /// No description provided for @profilesNew.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profilesNew;

  /// No description provided for @profilesActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profilesActive;

  /// No description provided for @profilesRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename profile'**
  String get profilesRenameTitle;

  /// No description provided for @profilesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String profilesDeleteTitle(String name);

  /// No description provided for @profilesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the profile and all of its learning history, custom sefarim, and goals. This cannot be undone.'**
  String get profilesDeleteBody;

  /// No description provided for @whatSwitchingProfile.
  ///
  /// In en, this message translates to:
  /// **'Switching to “{name}”'**
  String whatSwitchingProfile(String name);

  /// No description provided for @whatRenamingProfile.
  ///
  /// In en, this message translates to:
  /// **'Renaming “{from}” to “{to}”'**
  String whatRenamingProfile(String from, String to);

  /// No description provided for @whatDeletingProfile.
  ///
  /// In en, this message translates to:
  /// **'Deleting “{name}”'**
  String whatDeletingProfile(String name);

  /// No description provided for @profileDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted “{name}”.'**
  String profileDeleted(String name);

  /// No description provided for @profileLastOneKept.
  ///
  /// In en, this message translates to:
  /// **'There has to be at least one profile, so “{name}” was kept.'**
  String profileLastOneKept(String name);

  /// No description provided for @profileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Deleting “{name}” failed.'**
  String profileDeleteFailed(String name);

  /// No description provided for @whatCreatingProfile.
  ///
  /// In en, this message translates to:
  /// **'Creating the profile “{name}”'**
  String whatCreatingProfile(String name);

  /// No description provided for @sortSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort the tree'**
  String get sortSheetTitle;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @sortDescendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Highest / latest first'**
  String get sortDescendingSubtitle;

  /// No description provided for @sortApplyTo.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get sortApplyTo;

  /// No description provided for @sortAllLevels.
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get sortAllLevels;

  /// No description provided for @sortChildren.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get sortChildren;

  /// No description provided for @sortLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String sortLevel(int n);

  /// No description provided for @whatSavingSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Saving the sort order'**
  String get whatSavingSortOrder;

  /// No description provided for @sortMetricCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog order'**
  String get sortMetricCatalog;

  /// No description provided for @sortMetricName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortMetricName;

  /// No description provided for @sortMetricPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent complete'**
  String get sortMetricPercent;

  /// No description provided for @sortMetricLearned.
  ///
  /// In en, this message translates to:
  /// **'Amount done'**
  String get sortMetricLearned;

  /// No description provided for @sortMetricRemaining.
  ///
  /// In en, this message translates to:
  /// **'Amount remaining'**
  String get sortMetricRemaining;

  /// No description provided for @sortMetricLastLearned.
  ///
  /// In en, this message translates to:
  /// **'Last learned'**
  String get sortMetricLastLearned;

  /// No description provided for @sessionLearning.
  ///
  /// In en, this message translates to:
  /// **'{clock}  ·  learning'**
  String sessionLearning(String clock);

  /// No description provided for @sessionPaused.
  ///
  /// In en, this message translates to:
  /// **'{clock}  ·  paused'**
  String sessionPaused(String clock);

  /// No description provided for @sessionLabelled.
  ///
  /// In en, this message translates to:
  /// **'{clock}  ·  {label}'**
  String sessionLabelled(String clock, String label);

  /// No description provided for @tooltipPauseSession.
  ///
  /// In en, this message translates to:
  /// **'Pause session'**
  String get tooltipPauseSession;

  /// No description provided for @tooltipResumeSession.
  ///
  /// In en, this message translates to:
  /// **'Resume session'**
  String get tooltipResumeSession;

  /// No description provided for @tooltipDiscardSession.
  ///
  /// In en, this message translates to:
  /// **'Discard session'**
  String get tooltipDiscardSession;

  /// No description provided for @whatPausingSession.
  ///
  /// In en, this message translates to:
  /// **'Pausing the session'**
  String get whatPausingSession;

  /// No description provided for @whatResumingSession.
  ///
  /// In en, this message translates to:
  /// **'Resuming the session'**
  String get whatResumingSession;

  /// No description provided for @whatDiscardingSession.
  ///
  /// In en, this message translates to:
  /// **'Discarding the session'**
  String get whatDiscardingSession;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get settingsSectionCalendar;

  /// No description provided for @settingsCalendarGregorian.
  ///
  /// In en, this message translates to:
  /// **'Secular (Gregorian)'**
  String get settingsCalendarGregorian;

  /// No description provided for @settingsCalendarHebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get settingsCalendarHebrew;

  /// No description provided for @whatChangingCalendar.
  ///
  /// In en, this message translates to:
  /// **'Changing the calendar'**
  String get whatChangingCalendar;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @whatChangingTheme.
  ///
  /// In en, this message translates to:
  /// **'Changing the theme'**
  String get whatChangingTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Hebrew (עברית)'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the app in Hebrew, right-to-left'**
  String get settingsLanguageSubtitle;

  /// No description provided for @whatChangingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Changing the language'**
  String get whatChangingLanguage;

  /// No description provided for @settingsSectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsSectionReminders;

  /// No description provided for @settingsDailyNudge.
  ///
  /// In en, this message translates to:
  /// **'Daily learning nudge'**
  String get settingsDailyNudge;

  /// No description provided for @settingsDailyNudgeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a reminder in the app if you have not learned today'**
  String get settingsDailyNudgeSubtitle;

  /// No description provided for @whatChangingNudge.
  ///
  /// In en, this message translates to:
  /// **'Changing the daily nudge'**
  String get whatChangingNudge;

  /// No description provided for @settingsSectionChazara.
  ///
  /// In en, this message translates to:
  /// **'Chazara'**
  String get settingsSectionChazara;

  /// No description provided for @settingsReviewIntervals.
  ///
  /// In en, this message translates to:
  /// **'Review intervals'**
  String get settingsReviewIntervals;

  /// No description provided for @settingsReviewIntervalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{intervals} days after each pass'**
  String settingsReviewIntervalsSubtitle(String intervals);

  /// No description provided for @settingsIntervalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chazara review intervals'**
  String get settingsIntervalsTitle;

  /// No description provided for @settingsIntervalsBody.
  ///
  /// In en, this message translates to:
  /// **'Days after each pass before the next review is due, e.g. “1, 3, 7, 16, 35, 70”. The last value repeats after that.'**
  String get settingsIntervalsBody;

  /// No description provided for @settingsIntervalsHint.
  ///
  /// In en, this message translates to:
  /// **'1, 3, 7, 16, 35, 70'**
  String get settingsIntervalsHint;

  /// No description provided for @whatSavingIntervals.
  ///
  /// In en, this message translates to:
  /// **'Saving your chazara intervals'**
  String get whatSavingIntervals;

  /// No description provided for @settingsSectionMeforishBars.
  ///
  /// In en, this message translates to:
  /// **'Mefarshim bars'**
  String get settingsSectionMeforishBars;

  /// No description provided for @settingsMeforishBarsExplainer.
  ///
  /// In en, this message translates to:
  /// **'Show or hide each meforish’s coverage line under the tree’s progress bars.'**
  String get settingsMeforishBarsExplainer;

  /// No description provided for @whatShowingBar.
  ///
  /// In en, this message translates to:
  /// **'Showing the {name} bar'**
  String whatShowingBar(String name);

  /// No description provided for @whatHidingBar.
  ///
  /// In en, this message translates to:
  /// **'Hiding the {name} bar'**
  String whatHidingBar(String name);

  /// No description provided for @settingsSectionProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get settingsSectionProfiles;

  /// No description provided for @settingsManageProfiles.
  ///
  /// In en, this message translates to:
  /// **'Manage profiles'**
  String get settingsManageProfiles;

  /// No description provided for @settingsSectionHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get settingsSectionHistory;

  /// No description provided for @settingsBulkHistory.
  ///
  /// In en, this message translates to:
  /// **'Bulk action history'**
  String get settingsBulkHistory;

  /// No description provided for @settingsBulkHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Undo a finish-all or clear-all, any time'**
  String get settingsBulkHistoryEmpty;

  /// No description provided for @settingsBulkHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 undoable action} other{{count} undoable actions}}'**
  String settingsBulkHistoryCount(int count);

  /// No description provided for @settingsSectionBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsSectionBackup;

  /// No description provided for @settingsExportFile.
  ///
  /// In en, this message translates to:
  /// **'Export to file'**
  String get settingsExportFile;

  /// No description provided for @settingsExportFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save all progress as a JSON file'**
  String get settingsExportFileSubtitle;

  /// No description provided for @settingsImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get settingsImportFile;

  /// No description provided for @settingsImportFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Merge a saved JSON file in — adds anything missing, keeps everything you already have'**
  String get settingsImportFileSubtitle;

  /// No description provided for @settingsRestoreFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get settingsRestoreFile;

  /// No description provided for @settingsRestoreFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make this profile exactly match a backup, undoing anything recorded since it'**
  String get settingsRestoreFileSubtitle;

  /// No description provided for @settingsExportClipboard.
  ///
  /// In en, this message translates to:
  /// **'Export to clipboard'**
  String get settingsExportClipboard;

  /// No description provided for @settingsExportClipboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy all progress as JSON'**
  String get settingsExportClipboardSubtitle;

  /// No description provided for @settingsImportClipboard.
  ///
  /// In en, this message translates to:
  /// **'Import from clipboard'**
  String get settingsImportClipboard;

  /// No description provided for @settingsImportClipboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a previous export to restore/merge'**
  String get settingsImportClipboardSubtitle;

  /// No description provided for @settingsCrashLog.
  ///
  /// In en, this message translates to:
  /// **'Crash log'**
  String get settingsCrashLog;

  /// No description provided for @settingsCrashLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device only — copy it into a bug report'**
  String get settingsCrashLogSubtitle;

  /// No description provided for @settingsSectionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsSectionReset;

  /// No description provided for @settingsClearSettings.
  ///
  /// In en, this message translates to:
  /// **'Clear settings'**
  String get settingsClearSettings;

  /// No description provided for @settingsClearSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset preferences, goals, learning cycles, custom sefarim, mefarshim, and required-set settings. Your learning log is kept.'**
  String get settingsClearSettingsSubtitle;

  /// No description provided for @settingsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all settings?'**
  String get settingsClearTitle;

  /// No description provided for @settingsClearBody.
  ///
  /// In en, this message translates to:
  /// **'This resets preferences and removes your goals, learning cycles, custom sefarim, custom mefarshim, and required-mefarshim settings. Your learning log (everything you marked done) is not touched.'**
  String get settingsClearBody;

  /// No description provided for @whatClearingSettings.
  ///
  /// In en, this message translates to:
  /// **'Clearing your settings'**
  String get whatClearingSettings;

  /// No description provided for @settingsCleared.
  ///
  /// In en, this message translates to:
  /// **'Settings cleared'**
  String get settingsCleared;

  /// No description provided for @settingsBackupReminder.
  ///
  /// In en, this message translates to:
  /// **'Remind me to back up'**
  String get settingsBackupReminder;

  /// No description provided for @settingsBackupReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Say so when there is learning no export contains. Your data never leaves this device on its own — this export is the only copy that survives losing it.'**
  String get settingsBackupReminderSubtitle;

  /// No description provided for @whatChangingBackupReminder.
  ///
  /// In en, this message translates to:
  /// **'Changing the backup reminder'**
  String get whatChangingBackupReminder;

  /// No description provided for @settingsBackupInterval.
  ///
  /// In en, this message translates to:
  /// **'Remind me after'**
  String get settingsBackupInterval;

  /// No description provided for @settingsBackupIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day of unsaved learning} other{{days} days of unsaved learning}}'**
  String settingsBackupIntervalSubtitle(int days);

  /// No description provided for @settingsBackupIntervalBody.
  ///
  /// In en, this message translates to:
  /// **'How many days of learning you are willing to have only on this device before the app mentions it.'**
  String get settingsBackupIntervalBody;

  /// No description provided for @settingsBackupIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get settingsBackupIntervalLabel;

  /// No description provided for @settingsBackupIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of days above 0.'**
  String get settingsBackupIntervalInvalid;

  /// No description provided for @whatSavingBackupInterval.
  ///
  /// In en, this message translates to:
  /// **'Saving the backup reminder interval'**
  String get whatSavingBackupInterval;

  /// No description provided for @backupNeverExported.
  ///
  /// In en, this message translates to:
  /// **'Never exported'**
  String get backupNeverExported;

  /// No description provided for @backupLastExported.
  ///
  /// In en, this message translates to:
  /// **'Last exported {date}'**
  String backupLastExported(String date);

  /// No description provided for @backupNothingUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Everything you have learned is in that backup'**
  String get backupNothingUnsaved;

  /// Never exported *and* nothing learned: a new profile. Distinct from backupNothingUnsaved, which promises a backup that in this state does not exist.
  ///
  /// In en, this message translates to:
  /// **'Nothing to back up yet — export as soon as you have learned something'**
  String get backupNothingToSaveYet;

  /// No description provided for @backupUnsavedUnits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit learned since — it exists only on this device} other{{count} units learned since — they exist only on this device}}'**
  String backupUnsavedUnits(int count);

  /// No description provided for @backupBannerNever.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit of your learning has never been backed up.} other{{count} units of your learning have never been backed up.}}'**
  String backupBannerNever(int count);

  /// No description provided for @backupBannerStale.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit learned since your last backup} other{{count} units learned since your last backup}} {days, plural, =1{1 day ago} other{{days} days ago}}.'**
  String backupBannerStale(int count, int days);

  /// No description provided for @backupBannerWhy.
  ///
  /// In en, this message translates to:
  /// **'It lives only on this device — nothing is copied anywhere automatically.'**
  String get backupBannerWhy;

  /// No description provided for @backupBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Back up'**
  String get backupBannerAction;

  /// No description provided for @backupBannerDismiss.
  ///
  /// In en, this message translates to:
  /// **'Turn off this reminder'**
  String get backupBannerDismiss;

  /// No description provided for @backupBannerDismissed.
  ///
  /// In en, this message translates to:
  /// **'Backup reminder off — turn it back on in Settings → Backup'**
  String get backupBannerDismissed;

  /// No description provided for @backupSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get backupSaveDialogTitle;

  /// No description provided for @backupChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup file'**
  String get backupChooseFile;

  /// No description provided for @backupChooseRestoreFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup to restore'**
  String get backupChooseRestoreFile;

  /// No description provided for @whatExportingBackup.
  ///
  /// In en, this message translates to:
  /// **'Exporting your backup'**
  String get whatExportingBackup;

  /// No description provided for @whatExportingClipboard.
  ///
  /// In en, this message translates to:
  /// **'Exporting to the clipboard'**
  String get whatExportingClipboard;

  /// No description provided for @whatImportingBackup.
  ///
  /// In en, this message translates to:
  /// **'Importing your backup'**
  String get whatImportingBackup;

  /// No description provided for @whatRestoringBackup.
  ///
  /// In en, this message translates to:
  /// **'Restoring from your backup'**
  String get whatRestoringBackup;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved backup'**
  String get backupSaved;

  /// No description provided for @backupExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get backupExportCancelled;

  /// No description provided for @backupImportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import cancelled'**
  String get backupImportCancelled;

  /// No description provided for @backupRestoreCancelled.
  ///
  /// In en, this message translates to:
  /// **'Restore cancelled'**
  String get backupRestoreCancelled;

  /// No description provided for @backupExportedClipboard.
  ///
  /// In en, this message translates to:
  /// **'Exported to clipboard'**
  String get backupExportedClipboard;

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get backupImportTitle;

  /// No description provided for @backupImportHint.
  ///
  /// In en, this message translates to:
  /// **'Paste export JSON here'**
  String get backupImportHint;

  /// {reason} is the validator's own sentence, which names the bad field.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {reason}'**
  String backupImportFailed(String reason);

  /// No description provided for @backupImportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Import failed: the file could not be read — it is not text.'**
  String get backupImportUnreadable;

  /// For a failure that is the app's own. It must not suggest the backup is at fault: the export is the user's only copy, and 'the file could not be read' invites them to delete it and make another, which fails identically.
  ///
  /// In en, this message translates to:
  /// **'Import failed inside the app, not in your file. Keep the file — it is fine. Details says what went wrong.'**
  String get backupImportAppFailure;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 new event} other{Imported {count} new events}}'**
  String backupImported(int count);

  /// No description provided for @backupNoEvents.
  ///
  /// In en, this message translates to:
  /// **'That backup has no learning events in it'**
  String get backupNoEvents;

  /// No description provided for @backupAlreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date — all {count} events were already here. Import merges, so it cannot undo anything you did since. Use “Restore from file” for that.'**
  String backupAlreadyUpToDate(int count);

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from this backup?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmNoChange.
  ///
  /// In en, this message translates to:
  /// **'This profile already matches the backup — nothing will change.'**
  String get restoreConfirmNoChange;

  /// No description provided for @restoreConfirmIntro.
  ///
  /// In en, this message translates to:
  /// **'This makes the profile exactly match the backup, undoing everything recorded since it.'**
  String get restoreConfirmIntro;

  /// No description provided for @restoreConfirmLosing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit you have marked since the backup will no longer be marked.} other{{count} units you have marked since the backup will no longer be marked.}}'**
  String restoreConfirmLosing(int count);

  /// No description provided for @restoreConfirmGaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit will be marked again.} other{{count} units will be marked again.}}'**
  String restoreConfirmGaining(int count);

  /// No description provided for @restoreConfirmBackupFirst.
  ///
  /// In en, this message translates to:
  /// **'Export a fresh backup first if you want to keep the newer progress.'**
  String get restoreConfirmBackupFirst;

  /// No description provided for @restoreAlreadyMatched.
  ///
  /// In en, this message translates to:
  /// **'Restored — this profile already matched that backup'**
  String get restoreAlreadyMatched;

  /// No description provided for @restoreNoUnitChange.
  ///
  /// In en, this message translates to:
  /// **'Restored to the backup — no change to which units are marked'**
  String get restoreNoUnitChange;

  /// {changes} is one or both of restoreSummaryRestored / restoreSummaryRemoved, joined by '; '.
  ///
  /// In en, this message translates to:
  /// **'Restored to the backup: {changes}'**
  String restoreSummary(String changes);

  /// No description provided for @restoreSummaryRestored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit is marked again} other{{count} units are marked again}}'**
  String restoreSummaryRestored(int count);

  /// No description provided for @restoreSummaryRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit is no longer marked} other{{count} units are no longer marked}}'**
  String restoreSummaryRemoved(int count);

  /// No description provided for @crashLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash log'**
  String get crashLogTitle;

  /// No description provided for @crashLogCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get crashLogCopy;

  /// No description provided for @crashLogClear.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get crashLogClear;

  /// No description provided for @crashLogCopied.
  ///
  /// In en, this message translates to:
  /// **'Crash log copied'**
  String get crashLogCopied;

  /// No description provided for @whatCopyingCrashLog.
  ///
  /// In en, this message translates to:
  /// **'Copying the crash log'**
  String get whatCopyingCrashLog;

  /// No description provided for @crashLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has crashed.\n\nIf something ever does, the details land here — on this device only — so you can copy them into a bug report.'**
  String get crashLogEmpty;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'The catalog could not be loaded'**
  String get errorCatalogTitle;

  /// No description provided for @errorCatalogBody.
  ///
  /// In en, this message translates to:
  /// **'The bundled list of sefarim failed to load, so the tree cannot be shown. Your learning log is untouched.'**
  String get errorCatalogBody;

  /// No description provided for @errorLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Your learning log could not be read'**
  String get errorLogTitle;

  /// No description provided for @errorLogBody.
  ///
  /// In en, this message translates to:
  /// **'The database did not open. Nothing has been changed or lost — this is a read that failed.'**
  String get errorLogBody;

  /// No description provided for @errorProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profiles could not be read'**
  String get errorProfilesTitle;

  /// No description provided for @errorProfilesBody.
  ///
  /// In en, this message translates to:
  /// **'The database did not open. Nothing has been changed or lost.'**
  String get errorProfilesBody;

  /// No description provided for @errorRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get errorRetry;

  /// No description provided for @errorShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get errorShowDetails;

  /// No description provided for @errorHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get errorHideDetails;

  /// No description provided for @errorOpenCrashLog.
  ///
  /// In en, this message translates to:
  /// **'Open crash log'**
  String get errorOpenCrashLog;

  /// No description provided for @errorDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'The full error is below, and is already in the crash log.'**
  String get errorDetailsHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
