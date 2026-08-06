// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chovos Hayom';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionFinish => 'Finish';

  @override
  String get actionMark => 'Mark';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionImport => 'Import';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionRename => 'Rename';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionReview => 'Review';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionDetails => 'Details';

  @override
  String get labelName => 'Name';

  @override
  String get labelRequired => 'Required';

  @override
  String get labelOptional => 'Optional';

  @override
  String get labelNameEnglish => 'Name (English)';

  @override
  String get labelNameHebrew => 'Name (Hebrew)';

  @override
  String get namePairHelp =>
      'Either one is enough. The app shows whichever matches the language you are using, and falls back to the other.';

  @override
  String writeFailed(String what) {
    return '$what failed.';
  }

  @override
  String get notFoundTitle => 'Not found';

  @override
  String notFoundBody(String name) {
    return 'There is nothing here.\n\n“$name” is not a screen this version of the app has.';
  }

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String get tooltipExpand => 'Expand';

  @override
  String get tooltipCollapse => 'Collapse';

  @override
  String get tooltipSort => 'Sort';

  @override
  String tooltipSortActive(String metric) {
    return 'Sort: $metric';
  }

  @override
  String get tooltipSearch => 'Search';

  @override
  String get tooltipMore => 'More actions';

  @override
  String get tooltipAddCustomSefer => 'Add custom sefer';

  @override
  String get nudgeHaventLearnedToday =>
      'You haven\'t learned yet today — pick something below!';

  @override
  String drawerProfile(String name) {
    return 'Profile: $name';
  }

  @override
  String get navLearningTree => 'Learning tree';

  @override
  String get navLearningCycles => 'Learning cycles';

  @override
  String get navReports => 'Reports';

  @override
  String get navChazaraDue => 'Chazara due';

  @override
  String get navNotesJournal => 'Notes Journal';

  @override
  String get navProfiles => 'Profiles';

  @override
  String get navAddCustomSefer => 'Add custom sefer';

  @override
  String get navSettings => 'Settings';

  @override
  String progressCount(int learned, int total, String percent) {
    final intl.NumberFormat learnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String learnedString = learnedNumberFormat.format(learned);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$learnedString / $totalString  ($percent%)';
  }

  @override
  String meforishCoverage(int learned, int total) {
    final intl.NumberFormat learnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String learnedString = learnedNumberFormat.format(learned);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$learnedString/$totalString';
  }

  @override
  String get nodeMenuTooltip => 'Mefarshim / edit / add / hide';

  @override
  String get menuMefarshim => 'Mefarshim…';

  @override
  String get menuBulkActions => 'Finish all / clear all';

  @override
  String get menuAddSubItem => 'Add sub-item';

  @override
  String get menuCloneStructure => 'Clone structure';

  @override
  String get menuHideDelete => 'Hide / delete';

  @override
  String get menuResetToDefault => 'Reset to default';

  @override
  String get menuRemovePermanently => 'Remove permanently';

  @override
  String hideNodeTitle(String name) {
    return 'Hide “$name”?';
  }

  @override
  String get hideNodeBody =>
      'It is removed from the tree. Your logged progress stays intact, and you can restore it with “Reset to default”.';

  @override
  String get hideNodeConfirm => 'Hide';

  @override
  String whatCloning(String name) {
    return 'Cloning “$name”';
  }

  @override
  String clonedNode(String name) {
    return 'Cloned “$name”';
  }

  @override
  String whatHiding(String name) {
    return 'Hiding “$name”';
  }

  @override
  String whatResetting(String name) {
    return 'Resetting “$name”';
  }

  @override
  String get unitLabelPerek => 'perek';

  @override
  String get unitLabelDaf => 'daf';

  @override
  String get unitLabelAmud => 'amud';

  @override
  String get unitLabelSiman => 'siman';

  @override
  String get unitLabelHalacha => 'halacha';

  @override
  String get unitLabelPage => 'page';

  @override
  String get unitLabelCustom => 'unit';

  @override
  String get unitLabelUnknown => 'unit';

  @override
  String unitHeading(String label, int number) {
    return '$label $number';
  }

  @override
  String unitCountWithLabel(int count, String label) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString $label';
  }

  @override
  String get unitLabelPluralPerek => 'perakim';

  @override
  String get unitLabelPluralDaf => 'dapim';

  @override
  String get unitLabelPluralAmud => 'amudim';

  @override
  String get unitLabelPluralSiman => 'simanim';

  @override
  String get unitLabelPluralHalacha => 'halachos';

  @override
  String get unitLabelPluralPage => 'pages';

  @override
  String get unitLabelPluralCustom => 'units';

  @override
  String get unitLabelPluralUnknown => 'units';

  @override
  String nodeAndUnit(String node, String unit) {
    return '$node · $unit';
  }

  @override
  String nodeWithPath(String name, String path) {
    return '$name — $path';
  }

  @override
  String get tooltipBulkActions => 'Finish all / clear all';

  @override
  String get tooltipMefarshim => 'Mefarshim';

  @override
  String get tooltipSetGoalDate => 'Set goal date';

  @override
  String gridCellSemanticDone(String unit) {
    return '$unit, learned';
  }

  @override
  String gridCellSemanticNotDone(String unit) {
    return '$unit, not learned';
  }

  @override
  String gridCellSemanticPartial(String unit, int percent) {
    return '$unit, partly learned, $percent%';
  }

  @override
  String gridCellSemanticReviews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chazaras',
      one: '1 chazara',
    );
    return '$_temp0';
  }

  @override
  String get gridCellSemanticHasDetails => 'has recorded details';

  @override
  String whatMarkingLearned(String unit) {
    return 'Marking $unit learned';
  }

  @override
  String whatUnmarking(String unit) {
    return 'Un-marking $unit';
  }

  @override
  String whatLogging(String unit) {
    return 'Logging $unit';
  }

  @override
  String whatSettingGoal(String name) {
    return 'Setting a goal for $name';
  }

  @override
  String get cellMenuViewEditDetails => 'View / edit details';

  @override
  String get cellMenuViewEditDetailsSubtitle =>
      'When you finished, how long, your note';

  @override
  String get cellMenuRelog => 'Re-log with date / duration / note';

  @override
  String get cellMenuLog => 'Log with date / duration / note';

  @override
  String get cellMenuAddChazara => 'Add chazara (review)';

  @override
  String get cellMenuUnmark => 'Un-mark';

  @override
  String get cellMenuMarkLearned => 'Mark learned';

  @override
  String get seferMissing =>
      'This sefer no longer exists.\nIt may have been hidden, deleted, or replaced.';

  @override
  String get itemMissing =>
      'This item no longer exists.\nIt may have been hidden or deleted.';

  @override
  String get itemMissingRenamed =>
      'This item no longer exists.\nIt may have been removed or renamed.';

  @override
  String get cycleMissing =>
      'This cycle no longer exists.\nIt may have been deleted, or it belongs to another profile.';

  @override
  String get goalReached => 'Goal reached! 🎉';

  @override
  String goalStatus(Object date, Object rate, Object status) {
    return 'By $date · need $rate/day · $status';
  }

  @override
  String get goalOnTrack => 'on track';

  @override
  String get goalBehind => 'behind';

  @override
  String get tooltipRemoveGoal => 'Remove goal';

  @override
  String whatRemovingGoal(String name) {
    return 'Removing the goal for $name';
  }

  @override
  String whatRestoringGoal(String name) {
    return 'Restoring the goal for $name';
  }

  @override
  String get goalsEmpty =>
      'No goals yet.\nSet a target date on the Calculator, or open any sefer and tap the flag.';

  @override
  String get goalsSetOne => 'Set a goal';

  @override
  String goalRemovedFor(String name) {
    return 'Goal for “$name” removed';
  }

  @override
  String get layersComplete => 'Complete — all required mefarshim learned.';

  @override
  String layersRemaining(int missing, int total) {
    return '$missing of $total required still to learn.';
  }

  @override
  String get deletedMeforish => 'Deleted meforish';

  @override
  String get markAllRequiredLearned => 'Mark all required learned';

  @override
  String get logWithDateDurationHaara => 'Log with date / duration / haara…';

  @override
  String get clearThisUnit => 'Clear this unit';

  @override
  String whatMarkingLayer(String layer, String unit) {
    return 'Marking $layer on $unit';
  }

  @override
  String whatUnmarkingLayer(String layer, String unit) {
    return 'Un-marking $layer on $unit';
  }

  @override
  String whatMarkingEveryRequired(String unit) {
    return 'Marking every required meforish on $unit';
  }

  @override
  String whatClearingUnit(String unit) {
    return 'Clearing $unit';
  }

  @override
  String get logSheetWhatYouLearned => 'What you learned:';

  @override
  String get logSheetManualDateTime => 'Set date & time manually';

  @override
  String get logSheetDefaultsToNow => 'Defaults to now';

  @override
  String get logSheetPickDate => 'Pick date';

  @override
  String get logSheetPickTime => 'Pick time';

  @override
  String logSheetTimer(String clock) {
    return 'Timer  $clock';
  }

  @override
  String get logSheetStart => 'Start';

  @override
  String get logSheetStop => 'Stop';

  @override
  String get logSheetKeepsRunning =>
      'Keeps running if you close this — go learn.';

  @override
  String get logSheetDuration => 'How long it took (minutes, optional)';

  @override
  String get logSheetHaara => 'Haara (optional)';

  @override
  String get logSheetHaaraHint =>
      'A chiddush, a question, a maareh makom, how it went…';

  @override
  String get logSheetHaaraHelper => 'Collected in your Notes Journal.';

  @override
  String get logSheetMarkLearned => 'Mark learned';

  @override
  String get logSheetSaveChanges => 'Save changes';

  @override
  String get whatStartingTimer => 'Starting the session timer';

  @override
  String get whatPausingTimer => 'Pausing the session timer';

  @override
  String get whatResettingTimer => 'Resetting the session timer';

  @override
  String get whatEndingTimer => 'Ending the session timer';

  @override
  String dateTimeLabel(String date, String time) {
    return '$date · $time';
  }

  @override
  String get addChazaraTitle => 'Add chazara';

  @override
  String get addChazaraReviewed => 'Reviewed:';

  @override
  String get addChazaraSubmit => 'Log chazara';

  @override
  String whatLoggingChazara(String unit) {
    return 'Logging a chazara on $unit';
  }

  @override
  String get detailsNotLearnedYet => 'Not learned yet.';

  @override
  String get detailsFinished => 'Finished';

  @override
  String get detailsTimeToLearn => 'Time to learn';

  @override
  String get detailsNotRecorded => 'Not recorded';

  @override
  String get detailsChazaraPasses => 'Chazara passes';

  @override
  String get detailsNoneYet => 'None yet';

  @override
  String get detailsHaara => 'Haara';

  @override
  String get detailsNoHaara => 'No haara';

  @override
  String get detailsEdit => 'Edit details';

  @override
  String get detailsAddChazara => 'Add chazara';

  @override
  String get detailsUnmark => 'Un-mark';

  @override
  String detailsEditTitle(String unit) {
    return 'Edit · $unit';
  }

  @override
  String chazaraPass(int n) {
    return 'Pass $n';
  }

  @override
  String minutesShort(int minutes) {
    return '${minutes}m';
  }

  @override
  String whatSavingDetails(String unit) {
    return 'Saving the details for $unit';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '${hours}h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get bulkTitle => 'Bulk actions';

  @override
  String bulkAllUnitsUnderneath(String name) {
    return '$name · all units underneath';
  }

  @override
  String get bulkFinishAll => 'Finish all';

  @override
  String get bulkFinishAllSubtitle =>
      'Mark every unit’s required mefarshim done';

  @override
  String bulkMarkAllLayer(String layer) {
    return 'Mark all — $layer';
  }

  @override
  String get bulkMainTextSubtitle => 'The primary text on every unit';

  @override
  String get bulkFinishRange => 'Finish a range…';

  @override
  String get bulkFinishRangeSubtitle => 'Choose a start and end unit';

  @override
  String get bulkClearAll => 'Clear all';

  @override
  String get bulkClearAllSubtitle => 'Un-mark every unit (and its mefarshim)';

  @override
  String get bulkNothingToChange => 'Nothing to change';

  @override
  String bulkConfirmUnits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This changes $countString units.',
      one: 'This changes 1 unit.',
    );
    return '$_temp0';
  }

  @override
  String get bulkUndoNote =>
      'You can undo it from Settings → Bulk action history for as long as you like.';

  @override
  String bulkFinishAllTitle(String name) {
    return 'Finish all of “$name”?';
  }

  @override
  String bulkWhatFinishingAll(String name) {
    return 'Finishing all of “$name”';
  }

  @override
  String bulkMarkLayerTitle(String layer, String name) {
    return 'Mark $layer on all of “$name”?';
  }

  @override
  String bulkWhatMarkingLayer(String layer, String name) {
    return 'Marking $layer on all of “$name”';
  }

  @override
  String bulkClearAllTitle(String name) {
    return 'Clear all of “$name”?';
  }

  @override
  String bulkWhatClearingAll(String name) {
    return 'Clearing all of “$name”';
  }

  @override
  String get bulkClearWarningLeaf =>
      'Un-marks every unit here, including any mefarshim you checked off.';

  @override
  String get bulkClearWarningCategory =>
      'Un-marks every unit under this — including all its mefarshim.';

  @override
  String bulkRangeTitle(int start, int end, String name) {
    return 'Finish units $start–$end of “$name”?';
  }

  @override
  String bulkWhatFinishingRange(int start, int end, String name) {
    return 'Finishing units $start–$end of “$name”';
  }

  @override
  String bulkReportFinished(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Finished $countString units',
      one: 'Finished 1 unit',
    );
    return '$_temp0';
  }

  @override
  String bulkReportCleared(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cleared $countString units',
      one: 'Cleared 1 unit',
    );
    return '$_temp0';
  }

  @override
  String bulkReportMarkedLayer(int count, String layer) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marked $layer on $countString units',
      one: 'Marked $layer on 1 unit',
    );
    return '$_temp0';
  }

  @override
  String bulkReportFinishedRange(int count, int start, int end) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Finished $countString units in $start–$end',
      one: 'Finished 1 unit in $start–$end',
    );
    return '$_temp0';
  }

  @override
  String get whatUndoingBulk => 'Undoing that bulk action';

  @override
  String get rangeDialogTitle => 'Finish a range';

  @override
  String rangeDialogBody(int first, int last) {
    return 'Units $first–$last. Both ends included.';
  }

  @override
  String get rangeFrom => 'From';

  @override
  String get rangeTo => 'To';

  @override
  String get rangeErrorTwoNumbers => 'Enter two numbers.';

  @override
  String rangeErrorBounds(int first, int last) {
    return 'Units run from $first to $last.';
  }

  @override
  String get bulkHistoryTitle => 'Bulk action history';

  @override
  String get bulkHistoryEmpty =>
      'No bulk actions yet.\n\nAnything you finish or clear in bulk shows up here, and stays undoable until you undo it.';

  @override
  String bulkHistoryFinishedEntry(int count, String where) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Finished $countString units',
      one: 'Finished 1 unit',
    );
    return '$_temp0 · $where';
  }

  @override
  String bulkHistoryClearedEntry(int count, String where) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cleared $countString units',
      one: 'Cleared 1 unit',
    );
    return '$_temp0 · $where';
  }

  @override
  String bulkHistorySefarimCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sefarim',
      one: '1 sefer',
    );
    return '$_temp0';
  }

  @override
  String bulkHistoryWhereWithCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sefarim',
      one: '1 sefer',
    );
    return '$name ($_temp0)';
  }

  @override
  String get bulkHistoryUndoTitle => 'Undo this bulk action?';

  @override
  String bulkHistoryUndoFinishBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removes the $countString marks this action made.',
      one: 'Removes the 1 mark this action made.',
    );
    return '$_temp0 Anything you had learned before it is untouched.';
  }

  @override
  String bulkHistoryUndoClearBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restores the $countString units this action cleared.',
      one: 'Restores the 1 unit this action cleared.',
    );
    return '$_temp0';
  }

  @override
  String get whatUndoingThisBulk => 'Undoing this bulk action';

  @override
  String bulkHistoryUndone(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Undone — $countString events removed',
      one: 'Undone — 1 event removed',
    );
    return '$_temp0';
  }

  @override
  String get mefarshimTitle => 'Mefarshim';

  @override
  String get mefarshimExplainer =>
      'Each meforish is off, available to check off here, or required — a unit is done only once every required one is learned. Applies to everything under this item unless overridden.';

  @override
  String get mefarshimSetHere => 'Set on this item.';

  @override
  String mefarshimInheritedFrom(String name) {
    return 'Inherited from $name. Saving pins them here.';
  }

  @override
  String get mefarshimDefault => 'Default (text only). Saving pins a set here.';

  @override
  String get mefarshimAvailable => 'Available';

  @override
  String get mefarshimOff => 'Off';

  @override
  String get mefarshimAddMeforish => 'Add a meforish';

  @override
  String get mefarshimResetToInherited => 'Reset to inherited';

  @override
  String get mefarshimNewTitle => 'New meforish';

  @override
  String mefarshimEditTitle(String name) {
    return 'Edit “$name”';
  }

  @override
  String get mefarshimNeedName =>
      'Give the meforish a name, in either language.';

  @override
  String get tooltipEditMeforish => 'Edit meforish';

  @override
  String whatSavingMeforish(String name) {
    return 'Saving the meforish “$name”';
  }

  @override
  String get mefarshimHebrewOptional => 'Hebrew (optional)';

  @override
  String get tooltipDeleteMeforish => 'Delete meforish';

  @override
  String mefarshimDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String mefarshimDeleteRequiredWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It is currently required in $count places.',
      one: 'It is currently required in 1 place.',
    );
    return '$_temp0 Those units will go back to not needing it, so anything they were waiting on it for becomes complete.';
  }

  @override
  String get mefarshimDeleteLogNote =>
      'Chazaras and learning you already recorded against it stay in your log.';

  @override
  String whatSavingMefarshim(String name) {
    return 'Saving the mefarshim for $name';
  }

  @override
  String whatResettingMefarshim(String name) {
    return 'Resetting the mefarshim for $name';
  }

  @override
  String whatDeletingMeforish(String name) {
    return 'Deleting “$name”';
  }

  @override
  String whatAddingMeforish(String name) {
    return 'Adding the meforish “$name”';
  }

  @override
  String get mefarshimProgressEmpty =>
      'Nothing learned yet.\nAs you check off mefarshim, their totals appear here.';

  @override
  String get chazaraTitle => 'Chazara due';

  @override
  String get chazaraEmpty =>
      'Nothing due for review right now.\nLearned units come back here on a spaced schedule.';

  @override
  String get chazaraDueToday => 'due today';

  @override
  String chazaraOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String chazaraRowSubtitle(String overdue, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews so far',
      one: '1 review so far',
      zero: 'no reviews so far',
    );
    return '$overdue · $_temp0';
  }

  @override
  String get chazaraLogWithDetails => 'Log with details';

  @override
  String chazaraReviewed(String unit) {
    return 'Reviewed $unit';
  }

  @override
  String get siyumEmpty =>
      'No siyumim yet.\nFinish every unit of a sefer — or of a whole seder — and it will appear here. חזק!';

  @override
  String siyumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count siyumim',
      one: '1 siyum',
    );
    return '$_temp0 — יישר כח!';
  }

  @override
  String siyumCompleted(String date, String units) {
    return 'Completed $date · $units';
  }

  @override
  String get siyumEverythingUnderneath => ' · everything underneath';

  @override
  String get journalTitle => 'Notes Journal';

  @override
  String get journalSearchHint => 'Search haaros…';

  @override
  String get journalEmpty =>
      'No haaros yet.\nAdd one when you log or edit a daf — the “Haara” field lands here.';

  @override
  String journalNoMatches(String query) {
    return 'No haaros match “$query”.';
  }

  @override
  String get journalUnknownItem => 'Unknown item';

  @override
  String journalSubtitle(String location, String date) {
    return '$location · $date';
  }

  @override
  String get searchPrompt => 'Search sefarim, mesechtos, dafim…';

  @override
  String get searchNoMatches => 'No matches.';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportTabOverview => 'Overview';

  @override
  String get reportTabCalculator => 'Calculator';

  @override
  String get reportTabGoals => 'Goals';

  @override
  String get reportTabSiyumim => 'Siyumim';

  @override
  String get reportTabMefarshim => 'Mefarshim';

  @override
  String get statsOverall => 'Overall';

  @override
  String get statsLearned => 'Learned';

  @override
  String get statsStreak => 'Streak';

  @override
  String statsStreakValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get statsAvgPerDay => 'Avg / day (30d)';

  @override
  String get statsTimeLearned => 'Time learned';

  @override
  String get statsTimeThisMonth => 'Time this month';

  @override
  String get statsProjectedSiyum => 'Projected siyum';

  @override
  String statsLearnedValue(int learned, int total) {
    final intl.NumberFormat learnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String learnedString = learnedNumberFormat.format(learned);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$learnedString / $totalString';
  }

  @override
  String statsPercentValue(String percent) {
    return '$percent%';
  }

  @override
  String get statsNone => '—';

  @override
  String get statsProgressOverTime => 'Progress over time';

  @override
  String get statsActivity => 'Activity (last 12 weeks)';

  @override
  String get statsNeedMoreData => 'Learn a few units to see your trend.';

  @override
  String get calculatorWhatFinishing => 'What are you finishing?';

  @override
  String calculatorRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$remainingString of $totalString left';
  }

  @override
  String get calculatorModeRate => 'Rate';

  @override
  String get calculatorModeCycle => 'Cycle';

  @override
  String get calculatorModeByDate => 'By date';

  @override
  String get calculatorAmountPerDay => 'Amount per day';

  @override
  String get calculatorAmountShabbos => 'Amount on Shabbos (optional)';

  @override
  String get calculatorCycleAmounts =>
      'Cycle amounts (comma-separated, one per day)';

  @override
  String get calculatorCycleAmountsHelper =>
      'e.g. “5, 5, 5, 5, 5, 0, 10” is a 7-day cycle';

  @override
  String get calculatorCycleDay => 'Which cycle-day is today?';

  @override
  String get calculatorCycleDayHelper =>
      '1 = first amount above; 4 = you are on day 4';

  @override
  String calculatorTarget(String date) {
    return 'Target: $date';
  }

  @override
  String get calculatorPickDate => 'Pick date';

  @override
  String get calculatorSaveGoal => 'Save as goal';

  @override
  String get calculatorGoalSaved => 'Saved as a goal';

  @override
  String calculatorGoalSetFor(String name) {
    return 'Goal set for “$name”';
  }

  @override
  String get calculatorAlreadyFinished => 'Already finished! 🎉';

  @override
  String get calculatorEnterDailyAmount => 'Enter a daily amount above 0.';

  @override
  String get calculatorEnterAmounts => 'Enter amounts, e.g. “5, 5, 0, 10”.';

  @override
  String get calculatorCycleNeverFinishes =>
      'That cycle never finishes (all zeros).';

  @override
  String get calculatorPickFutureDate => 'Pick a date in the future.';

  @override
  String get calculatorNeverFinish => 'At that rate you never finish.';

  @override
  String calculatorFinishOn(String date, int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days',
      one: '1 day',
    );
    return 'You will finish on $date\n(about $_temp0 from today).';
  }

  @override
  String calculatorCycleLength(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '\nCycle length: $_temp0.';
  }

  @override
  String calculatorRequiredRate(String rate, String date) {
    return 'Learn $rate per day to finish by\n$date.';
  }

  @override
  String get cyclesTitle => 'Learning cycles';

  @override
  String get cyclesWhichToShow => 'Which cycles to show';

  @override
  String get cyclesNew => 'New cycle';

  @override
  String cyclesToday(String date) {
    return 'Today · $date';
  }

  @override
  String get cyclesEmpty =>
      'No cycles yet. Turn on a built-in one, or define your own — any sefarim, in any order, at any pace.';

  @override
  String get cyclesBuiltInExplainer =>
      'Built-in cycles are the ones the Hebrew calendar can work out exactly. For anything else, define your own.';

  @override
  String get cycleBavliName => 'Daf Yomi (Bavli)';

  @override
  String get cycleBavliDescription => 'One daf of Talmud Bavli a day';

  @override
  String get cycleYerushalmiName => 'Daf Yomi (Yerushalmi)';

  @override
  String get cycleYerushalmiDescription => 'One daf of Talmud Yerushalmi a day';

  @override
  String whatShowingCycle(String name) {
    return 'Showing $name';
  }

  @override
  String whatHidingCycle(String name) {
    return 'Hiding $name';
  }

  @override
  String cycleNumber(String description, int number) {
    return '$description · cycle $number';
  }

  @override
  String get tooltipEditCycle => 'Edit cycle';

  @override
  String get cycleNothingToday => 'This cycle has nothing scheduled for today.';

  @override
  String cycleDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get cycleDeleteBody =>
      'Only the cycle is removed. Everything you learned through it stays in your log.';

  @override
  String whatDeletingCycle(String name) {
    return 'Deleting the cycle “$name”';
  }

  @override
  String cycleUnitOutOfRange(String name, int unit) {
    return '“$name” doesn’t have a unit $unit, so this can’t be logged. Check the sefer’s unit count, or link this cycle to a different one.';
  }

  @override
  String get cycleAlreadyLearned => 'Already learned ✓';

  @override
  String cycleLearnedOn(String date) {
    return 'Learned $date ✓';
  }

  @override
  String cycleLogButton(String unit) {
    return 'Log $unit';
  }

  @override
  String cycleLogged(String unit) {
    return 'Logged $unit';
  }

  @override
  String cycleSeferNotInCatalog(String name) {
    return '“$name” isn’t in your catalog under that name.';
  }

  @override
  String get cycleLinkToSefer => 'Link it to a sefer';

  @override
  String cycleLinkTitle(String name) {
    return 'Link “$name” to…';
  }

  @override
  String whatLinkingSefer(String from, String to) {
    return 'Linking “$from” to $to';
  }

  @override
  String cycleLinked(String from, String to) {
    return 'Linked “$from” to $to';
  }

  @override
  String cycleDafHebrew(String sefer, int unit) {
    return '$sefer · דף $unit';
  }

  @override
  String get editCycleTitle => 'Edit cycle';

  @override
  String get newCycleTitle => 'New cycle';

  @override
  String get editCycleNameHint =>
      'e.g. Mishna Yomi, Rambam Yomi, my chazara seder';

  @override
  String get editCycleUnitsPerDay => 'Units per day';

  @override
  String get editCycleUnitsPerDayHelper =>
      'Mishna Yomi is 2; a daf a day is 1.';

  @override
  String get editCycleStartedOn => 'Started on';

  @override
  String get editCycleRepeats => 'Starts over when it finishes';

  @override
  String get editCycleRepeatsSubtitle => 'Off = a one-time programme';

  @override
  String get editCycleSefarimInOrder => 'Sefarim, in order';

  @override
  String editCycleTotalUnits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString units',
      one: '1 unit',
    );
    return '$_temp0';
  }

  @override
  String get editCycleEmpty => 'Add the sefarim this cycle walks through.';

  @override
  String get editCycleAddSefer => 'Add a sefer';

  @override
  String get editCycleSaveExisting => 'Save cycle';

  @override
  String get editCycleCreate => 'Create cycle';

  @override
  String editCycleSegmentSubtitle(int count, int offset) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString units from $offset';
  }

  @override
  String get tooltipMoveUp => 'Move up';

  @override
  String get tooltipMoveDown => 'Move down';

  @override
  String get tooltipRemove => 'Remove';

  @override
  String get editCycleAddDialogTitle => 'Add a sefer or category';

  @override
  String get editCycleEverythingUnderneath => 'everything underneath';

  @override
  String get editCycleNeedName => 'Give the cycle a name.';

  @override
  String get editCycleNeedPerDay => 'Units per day must be at least 1.';

  @override
  String get editCycleNeedSegment =>
      'Add at least one sefer for the cycle to walk.';

  @override
  String whatSavingCycle(String name) {
    return 'Saving the cycle “$name”';
  }

  @override
  String get addNodeTitle => 'Add';

  @override
  String editNodeTitle(String name) {
    return 'Edit “$name”';
  }

  @override
  String get addNodeHebrewName => 'Hebrew name (optional)';

  @override
  String get addNodeParent => 'Parent';

  @override
  String get addNodeTopLevel => '— Top level —';

  @override
  String get addNodeIsLeaf => 'Trackable sefer (has units)';

  @override
  String get addNodeIsLeafSubtitle => 'Off = a folder/category';

  @override
  String get addNodeUnitType => 'Unit type';

  @override
  String get addNodeUnitCount => 'Number of units';

  @override
  String get addNodeFirstUnit => 'First unit number';

  @override
  String get addNodeUnitNames => 'Unit names (optional, one per line)';

  @override
  String get addNodeUnitNamesHelper =>
      'e.g. parsha or siman titles — shown instead of numbers, in order from the first unit.';

  @override
  String get addNodeLoweringCount =>
      'Lowering the count keeps any progress on the removed units hidden but intact — raise it again to restore them.';

  @override
  String get addNodeNeedName => 'Please enter a name.';

  @override
  String get addNodeNeedNameEither => 'Give it a name, in either language.';

  @override
  String get addNodeNeedUnits => 'Number of units must be greater than 0.';

  @override
  String get addNodeTooManyUnits => 'That is more units than any sefer has.';

  @override
  String get addNodeNegativeOffset =>
      'The first unit number cannot be negative.';

  @override
  String addNodeTooManyNames(int names, int units) {
    return 'You listed $names unit names but only have $units units.';
  }

  @override
  String whatSavingNode(String name) {
    return 'Saving “$name”';
  }

  @override
  String whatAddingNode(String name) {
    return 'Adding “$name”';
  }

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesNew => 'New profile';

  @override
  String get profilesActive => 'Active';

  @override
  String get profilesRenameTitle => 'Rename profile';

  @override
  String profilesDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get profilesDeleteBody =>
      'This permanently deletes the profile and all of its learning history, custom sefarim, and goals. This cannot be undone.';

  @override
  String whatSwitchingProfile(String name) {
    return 'Switching to “$name”';
  }

  @override
  String whatRenamingProfile(String from, String to) {
    return 'Renaming “$from” to “$to”';
  }

  @override
  String whatDeletingProfile(String name) {
    return 'Deleting “$name”';
  }

  @override
  String profileDeleted(String name) {
    return 'Deleted “$name”.';
  }

  @override
  String profileLastOneKept(String name) {
    return 'There has to be at least one profile, so “$name” was kept.';
  }

  @override
  String profileDeleteFailed(String name) {
    return 'Deleting “$name” failed.';
  }

  @override
  String whatCreatingProfile(String name) {
    return 'Creating the profile “$name”';
  }

  @override
  String get sortSheetTitle => 'Sort the tree';

  @override
  String get sortDescending => 'Descending';

  @override
  String get sortDescendingSubtitle => 'Highest / latest first';

  @override
  String get sortApplyTo => 'Apply to';

  @override
  String get sortAllLevels => 'All levels';

  @override
  String get sortChildren => 'Children';

  @override
  String sortLevel(int n) {
    return 'Level $n';
  }

  @override
  String get whatSavingSortOrder => 'Saving the sort order';

  @override
  String get sortMetricCatalog => 'Catalog order';

  @override
  String get sortMetricName => 'Name';

  @override
  String get sortMetricPercent => 'Percent complete';

  @override
  String get sortMetricLearned => 'Amount done';

  @override
  String get sortMetricRemaining => 'Amount remaining';

  @override
  String get sortMetricLastLearned => 'Last learned';

  @override
  String sessionLearning(String clock) {
    return '$clock  ·  learning';
  }

  @override
  String sessionPaused(String clock) {
    return '$clock  ·  paused';
  }

  @override
  String sessionLabelled(String clock, String label) {
    return '$clock  ·  $label';
  }

  @override
  String get tooltipPauseSession => 'Pause session';

  @override
  String get tooltipResumeSession => 'Resume session';

  @override
  String get tooltipDiscardSession => 'Discard session';

  @override
  String get whatPausingSession => 'Pausing the session';

  @override
  String get whatResumingSession => 'Resuming the session';

  @override
  String get whatDiscardingSession => 'Discarding the session';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionCalendar => 'Calendar';

  @override
  String get settingsCalendarGregorian => 'Secular (Gregorian)';

  @override
  String get settingsCalendarHebrew => 'Hebrew';

  @override
  String get whatChangingCalendar => 'Changing the calendar';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get whatChangingTheme => 'Changing the theme';

  @override
  String get settingsLanguage => 'Hebrew (עברית)';

  @override
  String get settingsLanguageSubtitle =>
      'Show the app in Hebrew, right-to-left';

  @override
  String get whatChangingLanguage => 'Changing the language';

  @override
  String get settingsSectionReminders => 'Reminders';

  @override
  String get settingsDailyNudge => 'Daily learning nudge';

  @override
  String get settingsDailyNudgeSubtitle =>
      'Show a reminder in the app if you have not learned today';

  @override
  String get whatChangingNudge => 'Changing the daily nudge';

  @override
  String get settingsSectionChazara => 'Chazara';

  @override
  String get settingsReviewIntervals => 'Review intervals';

  @override
  String settingsReviewIntervalsSubtitle(String intervals) {
    return '$intervals days after each pass';
  }

  @override
  String get settingsIntervalsTitle => 'Chazara review intervals';

  @override
  String get settingsIntervalsBody =>
      'Days after each pass before the next review is due, e.g. “1, 3, 7, 16, 35, 70”. The last value repeats after that.';

  @override
  String get settingsIntervalsHint => '1, 3, 7, 16, 35, 70';

  @override
  String get whatSavingIntervals => 'Saving your chazara intervals';

  @override
  String get settingsSectionMeforishBars => 'Mefarshim bars';

  @override
  String get settingsMeforishBarsExplainer =>
      'Show or hide each meforish’s coverage line under the tree’s progress bars.';

  @override
  String whatShowingBar(String name) {
    return 'Showing the $name bar';
  }

  @override
  String whatHidingBar(String name) {
    return 'Hiding the $name bar';
  }

  @override
  String get settingsSectionProfiles => 'Profiles';

  @override
  String get settingsManageProfiles => 'Manage profiles';

  @override
  String get settingsSectionHistory => 'History';

  @override
  String get settingsBulkHistory => 'Bulk action history';

  @override
  String get settingsBulkHistoryEmpty =>
      'Undo a finish-all or clear-all, any time';

  @override
  String settingsBulkHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undoable actions',
      one: '1 undoable action',
    );
    return '$_temp0';
  }

  @override
  String get settingsSectionBackup => 'Backup';

  @override
  String get settingsExportFile => 'Export to file';

  @override
  String get settingsExportFileSubtitle => 'Save all progress as a JSON file';

  @override
  String get settingsImportFile => 'Import from file';

  @override
  String get settingsImportFileSubtitle =>
      'Merge a saved JSON file in — adds anything missing, keeps everything you already have';

  @override
  String get settingsRestoreFile => 'Restore learning from file';

  @override
  String get settingsRestoreFileSubtitle =>
      'Make your learning history exactly match a backup, undoing anything logged since it. Custom sefarim, mefarshim and settings are kept.';

  @override
  String get settingsRestoreEverything => 'Restore everything from file';

  @override
  String get settingsRestoreEverythingSubtitle =>
      'Make this whole profile match a backup — and delete the custom sefarim, mefarshim, mefarshim settings and goals you have added since it, and put your settings back to what it says';

  @override
  String get settingsExportClipboard => 'Export to clipboard';

  @override
  String get settingsExportClipboardSubtitle => 'Copy all progress as JSON';

  @override
  String get settingsImportClipboard => 'Import from clipboard';

  @override
  String get settingsImportClipboardSubtitle =>
      'Paste a previous export to restore/merge';

  @override
  String get settingsCrashLog => 'Crash log';

  @override
  String get settingsCrashLogSubtitle =>
      'Kept on this device only — copy it into a bug report';

  @override
  String get settingsSectionReset => 'Reset';

  @override
  String get settingsClearSettings => 'Clear settings';

  @override
  String get settingsClearSettingsSubtitle =>
      'Reset preferences, goals, learning cycles, custom sefarim, mefarshim, and required-set settings. Your learning log is kept.';

  @override
  String get settingsClearTitle => 'Clear all settings?';

  @override
  String get settingsClearBody =>
      'This resets preferences and removes your goals, learning cycles, custom sefarim, custom mefarshim, and required-mefarshim settings. Your learning log (everything you marked done) is not touched.';

  @override
  String get whatClearingSettings => 'Clearing your settings';

  @override
  String get settingsCleared => 'Settings cleared';

  @override
  String get settingsBackupReminder => 'Remind me to back up';

  @override
  String get settingsBackupReminderSubtitle =>
      'Say so when there is learning no export contains. Your data never leaves this device on its own — this export is the only copy that survives losing it.';

  @override
  String get whatChangingBackupReminder => 'Changing the backup reminder';

  @override
  String get settingsBackupInterval => 'Remind me after';

  @override
  String settingsBackupIntervalSubtitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days of unsaved learning',
      one: '1 day of unsaved learning',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupIntervalBody =>
      'How many days of learning you are willing to have only on this device before the app mentions it.';

  @override
  String get settingsBackupIntervalLabel => 'Days';

  @override
  String get settingsBackupIntervalInvalid => 'Enter a number of days above 0.';

  @override
  String get whatSavingBackupInterval => 'Saving the backup reminder interval';

  @override
  String get backupNeverExported => 'Never exported';

  @override
  String backupLastExported(String date) {
    return 'Last exported $date';
  }

  @override
  String get backupNothingUnsaved =>
      'Everything you have learned is in that backup';

  @override
  String get backupNothingToSaveYet =>
      'Nothing to back up yet — export as soon as you have learned something';

  @override
  String backupUnsavedUnits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString units learned since — they exist only on this device',
      one: '1 unit learned since — it exists only on this device',
    );
    return '$_temp0';
  }

  @override
  String backupBannerNever(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString units of your learning have never been backed up.',
      one: '1 unit of your learning has never been backed up.',
    );
    return '$_temp0';
  }

  @override
  String backupBannerStale(int count, int days) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString units learned since your last backup',
      one: '1 unit learned since your last backup',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days ago',
      one: '1 day ago',
    );
    return '$_temp0 $_temp1.';
  }

  @override
  String get backupBannerWhy =>
      'It lives only on this device — nothing is copied anywhere automatically.';

  @override
  String get backupBannerAction => 'Back up';

  @override
  String get backupBannerDismiss => 'Turn off this reminder';

  @override
  String get backupBannerDismissed =>
      'Backup reminder off — turn it back on in Settings → Backup';

  @override
  String get backupSaveDialogTitle => 'Save backup';

  @override
  String get backupChooseFile => 'Choose a backup file';

  @override
  String get backupChooseRestoreFile => 'Choose a backup to restore';

  @override
  String get whatExportingBackup => 'Exporting your backup';

  @override
  String get whatExportingClipboard => 'Exporting to the clipboard';

  @override
  String get whatImportingBackup => 'Importing your backup';

  @override
  String get whatRestoringBackup => 'Restoring from your backup';

  @override
  String get backupSaved => 'Saved backup';

  @override
  String get backupExportCancelled => 'Export cancelled';

  @override
  String get backupImportCancelled => 'Import cancelled';

  @override
  String get backupRestoreCancelled => 'Restore cancelled';

  @override
  String get backupExportedClipboard => 'Exported to clipboard';

  @override
  String get backupImportTitle => 'Import data';

  @override
  String get backupImportHint => 'Paste export JSON here';

  @override
  String backupImportFailed(String reason) {
    return 'Import failed: $reason';
  }

  @override
  String get backupImportUnreadable =>
      'Import failed: the file could not be read — it is not text.';

  @override
  String get backupImportAppFailure =>
      'Import failed inside the app, not in your file. Keep the file — it is fine. Details says what went wrong.';

  @override
  String backupImported(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $countString new events',
      one: 'Imported 1 new event',
    );
    return '$_temp0';
  }

  @override
  String get backupNoEvents => 'That backup has no learning events in it';

  @override
  String backupAlreadyUpToDate(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Already up to date — all $countString events were already here. Import merges, so it cannot undo anything you did since. Use “Restore from file” for that.';
  }

  @override
  String get restoreConfirmTitle => 'Restore from this backup?';

  @override
  String get restoreConfirmNoChange =>
      'This profile already matches the backup — nothing will change.';

  @override
  String get restoreConfirmIntro =>
      'This makes your learning history exactly match the backup, undoing everything logged since it.';

  @override
  String get restoreConfirmIntroEverything =>
      'This makes the whole profile match the backup, undoing everything recorded since it — including the sefarim and goals you have added, and your settings, which go back to what the backup says.';

  @override
  String restoreConfirmLosingCustom(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString custom sefarim, mefarshim and mefarshim settings added since the backup will be deleted.',
      one:
          '1 custom sefer, meforish or mefarshim setting added since the backup will be deleted.',
    );
    return '$_temp0';
  }

  @override
  String restoreConfirmLosingGoals(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString target finish dates set since the backup will be deleted.',
      one: '1 target finish date set since the backup will be deleted.',
    );
    return '$_temp0';
  }

  @override
  String restoreSummaryDeletedCustom(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString custom sefarim and settings deleted',
      one: '1 custom sefer or setting deleted',
    );
    return '$_temp0';
  }

  @override
  String restoreSummaryDeletedGoals(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString goals deleted',
      one: '1 goal deleted',
    );
    return '$_temp0';
  }

  @override
  String restoreConfirmLosing(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString units you have marked since the backup will no longer be marked.',
      one: '1 unit you have marked since the backup will no longer be marked.',
    );
    return '$_temp0';
  }

  @override
  String restoreConfirmGaining(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString units will be marked again.',
      one: '1 unit will be marked again.',
    );
    return '$_temp0';
  }

  @override
  String get restoreConfirmBackupFirst =>
      'Export a fresh backup first if you want to keep the newer progress.';

  @override
  String get restoreAlreadyMatched =>
      'Restored — this profile already matched that backup';

  @override
  String get restoreNoUnitChange =>
      'Restored to the backup — no change to which units are marked';

  @override
  String restoreSummary(String changes) {
    return 'Restored to the backup: $changes';
  }

  @override
  String restoreSummaryRestored(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString units are marked again',
      one: '1 unit is marked again',
    );
    return '$_temp0';
  }

  @override
  String restoreSummaryRemoved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString units are no longer marked',
      one: '1 unit is no longer marked',
    );
    return '$_temp0';
  }

  @override
  String get crashLogTitle => 'Crash log';

  @override
  String get crashLogCopy => 'Copy to clipboard';

  @override
  String get crashLogClear => 'Clear log';

  @override
  String get crashLogCopied => 'Crash log copied';

  @override
  String get whatCopyingCrashLog => 'Copying the crash log';

  @override
  String get crashLogEmpty =>
      'Nothing has crashed.\n\nIf something ever does, the details land here — on this device only — so you can copy them into a bug report.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorCatalogTitle => 'The catalog could not be loaded';

  @override
  String get errorCatalogBody =>
      'The bundled list of sefarim failed to load, so the tree cannot be shown. Your learning log is untouched.';

  @override
  String get errorLogTitle => 'Your learning log could not be read';

  @override
  String get errorLogBody =>
      'The database did not open. Nothing has been changed or lost — this is a read that failed.';

  @override
  String get errorProfilesTitle => 'Your profiles could not be read';

  @override
  String get errorProfilesBody =>
      'The database did not open. Nothing has been changed or lost.';

  @override
  String get errorRetry => 'Try again';

  @override
  String get errorShowDetails => 'Show details';

  @override
  String get errorHideDetails => 'Hide details';

  @override
  String get errorOpenCrashLog => 'Open crash log';

  @override
  String get errorDetailsHint =>
      'The full error is below, and is already in the crash log.';
}
