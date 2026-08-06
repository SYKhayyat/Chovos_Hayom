// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'חובות היום';

  @override
  String get actionCancel => 'ביטול';

  @override
  String get actionSave => 'שמירה';

  @override
  String get actionDelete => 'מחיקה';

  @override
  String get actionAdd => 'הוספה';

  @override
  String get actionCreate => 'יצירה';

  @override
  String get actionClear => 'ניקוי';

  @override
  String get actionFinish => 'סיום';

  @override
  String get actionMark => 'סימון';

  @override
  String get actionRestore => 'שחזור';

  @override
  String get actionImport => 'ייבוא';

  @override
  String get actionUndo => 'ביטול פעולה';

  @override
  String get actionRename => 'שינוי שם';

  @override
  String get actionEdit => 'עריכה';

  @override
  String get actionReview => 'חזרה';

  @override
  String get actionReset => 'איפוס';

  @override
  String get actionDetails => 'פרטים';

  @override
  String get labelName => 'שם';

  @override
  String get labelRequired => 'חובה';

  @override
  String get labelOptional => 'רשות';

  @override
  String get labelNameEnglish => 'שם (אנגלית)';

  @override
  String get labelNameHebrew => 'שם (עברית)';

  @override
  String get namePairHelp =>
      'די באחד מהם. האפליקציה מציגה את זה שמתאים לשפה שבה אתה משתמש, ונופלת לשני אם הוא חסר.';

  @override
  String writeFailed(String what) {
    return '$what — נכשל.';
  }

  @override
  String get notFoundTitle => 'לא נמצא';

  @override
  String notFoundBody(String name) {
    return 'אין כאן דבר.\n\n״$name״ אינו מסך שקיים בגרסה זו של האפליקציה.';
  }

  @override
  String get expandAll => 'פתיחת הכול';

  @override
  String get collapseAll => 'סגירת הכול';

  @override
  String get tooltipExpand => 'פתיחה';

  @override
  String get tooltipCollapse => 'סגירה';

  @override
  String get tooltipSort => 'מיון';

  @override
  String tooltipSortActive(String metric) {
    return 'מיון: $metric';
  }

  @override
  String get tooltipSearch => 'חיפוש';

  @override
  String get tooltipMore => 'פעולות נוספות';

  @override
  String get tooltipAddCustomSefer => 'הוספת ספר משלך';

  @override
  String get nudgeHaventLearnedToday =>
      'עדיין לא למדת היום — בחר משהו מהרשימה!';

  @override
  String drawerProfile(String name) {
    return 'פרופיל: $name';
  }

  @override
  String get navLearningTree => 'עץ הלימוד';

  @override
  String get navLearningCycles => 'מחזורי לימוד';

  @override
  String get navReports => 'דוחות';

  @override
  String get navChazaraDue => 'חזרות לביצוע';

  @override
  String get navNotesJournal => 'יומן הערות';

  @override
  String get navProfiles => 'פרופילים';

  @override
  String get navAddCustomSefer => 'הוספת ספר משלך';

  @override
  String get navSettings => 'הגדרות';

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
  String get nodeMenuTooltip => 'מפרשים / עריכה / הוספה / הסתרה';

  @override
  String get menuMefarshim => 'מפרשים…';

  @override
  String get menuBulkActions => 'סיום הכול / ניקוי הכול';

  @override
  String get menuAddSubItem => 'הוספת פריט משנה';

  @override
  String get menuCloneStructure => 'שכפול המבנה';

  @override
  String get menuHideDelete => 'הסתרה / מחיקה';

  @override
  String get menuResetToDefault => 'איפוס לברירת המחדל';

  @override
  String get menuRemovePermanently => 'הסרה לצמיתות';

  @override
  String hideNodeTitle(String name) {
    return 'להסתיר את ״$name״?';
  }

  @override
  String get hideNodeBody =>
      'הפריט יוסר מהעץ. ההתקדמות שרשמת נשמרת במלואה, ואפשר להחזירו באמצעות ״איפוס לברירת המחדל״.';

  @override
  String get hideNodeConfirm => 'הסתרה';

  @override
  String whatCloning(String name) {
    return 'שכפול ״$name״';
  }

  @override
  String clonedNode(String name) {
    return '״$name״ שוכפל';
  }

  @override
  String whatHiding(String name) {
    return 'הסתרת ״$name״';
  }

  @override
  String whatResetting(String name) {
    return 'איפוס ״$name״';
  }

  @override
  String get unitLabelPerek => 'פרק';

  @override
  String get unitLabelDaf => 'דף';

  @override
  String get unitLabelAmud => 'עמוד';

  @override
  String get unitLabelSiman => 'סימן';

  @override
  String get unitLabelHalacha => 'הלכה';

  @override
  String get unitLabelPage => 'עמוד';

  @override
  String get unitLabelCustom => 'יחידה';

  @override
  String get unitLabelUnknown => 'יחידה';

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
  String get unitLabelPluralPerek => 'פרקים';

  @override
  String get unitLabelPluralDaf => 'דפים';

  @override
  String get unitLabelPluralAmud => 'עמודים';

  @override
  String get unitLabelPluralSiman => 'סימנים';

  @override
  String get unitLabelPluralHalacha => 'הלכות';

  @override
  String get unitLabelPluralPage => 'עמודים';

  @override
  String get unitLabelPluralCustom => 'יחידות';

  @override
  String get unitLabelPluralUnknown => 'יחידות';

  @override
  String nodeAndUnit(String node, String unit) {
    return '$node · $unit';
  }

  @override
  String nodeWithPath(String name, String path) {
    return '$name — $path';
  }

  @override
  String get tooltipBulkActions => 'סיום הכול / ניקוי הכול';

  @override
  String get tooltipMefarshim => 'מפרשים';

  @override
  String get tooltipSetGoalDate => 'קביעת תאריך יעד';

  @override
  String gridCellSemanticDone(String unit) {
    return '$unit, נלמד';
  }

  @override
  String gridCellSemanticNotDone(String unit) {
    return '$unit, לא נלמד';
  }

  @override
  String gridCellSemanticPartial(String unit, int percent) {
    return '$unit, נלמד חלקית, $percent%';
  }

  @override
  String gridCellSemanticReviews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חזרות',
      one: 'חזרה אחת',
    );
    return '$_temp0';
  }

  @override
  String get gridCellSemanticHasDetails => 'יש פרטים רשומים';

  @override
  String whatMarkingLearned(String unit) {
    return 'סימון $unit כנלמד';
  }

  @override
  String whatUnmarking(String unit) {
    return 'ביטול הסימון של $unit';
  }

  @override
  String whatLogging(String unit) {
    return 'רישום $unit';
  }

  @override
  String whatSettingGoal(String name) {
    return 'קביעת יעד עבור $name';
  }

  @override
  String get cellMenuViewEditDetails => 'הצגה / עריכה של הפרטים';

  @override
  String get cellMenuViewEditDetailsSubtitle => 'מתי סיימת, כמה זמן, ההערה שלך';

  @override
  String get cellMenuRelog => 'רישום מחדש עם תאריך / משך / הערה';

  @override
  String get cellMenuLog => 'רישום עם תאריך / משך / הערה';

  @override
  String get cellMenuAddChazara => 'הוספת חזרה';

  @override
  String get cellMenuUnmark => 'ביטול הסימון';

  @override
  String get cellMenuMarkLearned => 'סימון כנלמד';

  @override
  String get seferMissing =>
      'הספר הזה כבר לא קיים.\nייתכן שהוסתר, נמחק או הוחלף.';

  @override
  String get itemMissing => 'הפריט הזה כבר לא קיים.\nייתכן שהוסתר או נמחק.';

  @override
  String get itemMissingRenamed =>
      'הפריט הזה כבר לא קיים.\nייתכן שהוסר או ששמו שונה.';

  @override
  String get cycleMissing =>
      'המחזור הזה כבר לא קיים.\nייתכן שנמחק, או שהוא שייך לפרופיל אחר.';

  @override
  String get goalReached => 'הגעת ליעד! 🎉';

  @override
  String goalStatus(Object date, Object rate, Object status) {
    return 'עד $date · נדרש $rate ליום · $status';
  }

  @override
  String get goalOnTrack => 'בקצב';

  @override
  String get goalBehind => 'בפיגור';

  @override
  String get tooltipRemoveGoal => 'הסרת היעד';

  @override
  String whatRemovingGoal(String name) {
    return 'הסרת היעד עבור $name';
  }

  @override
  String whatRestoringGoal(String name) {
    return 'החזרת היעד עבור $name';
  }

  @override
  String get goalsEmpty =>
      'אין עדיין יעדים.\nקבע תאריך יעד במחשבון, או פתח ספר כלשהו והקש על הדגל.';

  @override
  String get goalsSetOne => 'קביעת יעד';

  @override
  String goalRemovedFor(String name) {
    return 'היעד עבור ״$name״ הוסר';
  }

  @override
  String get layersComplete => 'הושלם — כל המפרשים הנדרשים נלמדו.';

  @override
  String layersRemaining(int missing, int total) {
    return 'נותרו $missing מתוך $total מפרשים נדרשים.';
  }

  @override
  String get deletedMeforish => 'מפרש שנמחק';

  @override
  String get markAllRequiredLearned => 'סימון כל הנדרשים כנלמדו';

  @override
  String get logWithDateDurationHaara => 'רישום עם תאריך / משך / הערה…';

  @override
  String get clearThisUnit => 'ניקוי היחידה הזו';

  @override
  String whatMarkingLayer(String layer, String unit) {
    return 'סימון $layer על $unit';
  }

  @override
  String whatUnmarkingLayer(String layer, String unit) {
    return 'ביטול הסימון של $layer על $unit';
  }

  @override
  String whatMarkingEveryRequired(String unit) {
    return 'סימון כל המפרשים הנדרשים על $unit';
  }

  @override
  String whatClearingUnit(String unit) {
    return 'ניקוי $unit';
  }

  @override
  String get logSheetWhatYouLearned => 'מה למדת:';

  @override
  String get logSheetManualDateTime => 'קביעת תאריך ושעה ידנית';

  @override
  String get logSheetDefaultsToNow => 'ברירת המחדל היא עכשיו';

  @override
  String get logSheetPickDate => 'בחירת תאריך';

  @override
  String get logSheetPickTime => 'בחירת שעה';

  @override
  String logSheetTimer(String clock) {
    return 'שעון  $clock';
  }

  @override
  String get logSheetStart => 'התחלה';

  @override
  String get logSheetStop => 'עצירה';

  @override
  String get logSheetKeepsRunning => 'השעון ימשיך לרוץ גם אם תסגור — לך ללמוד.';

  @override
  String get logSheetDuration => 'כמה זמן לקח (דקות, רשות)';

  @override
  String get logSheetHaara => 'הערה (רשות)';

  @override
  String get logSheetHaaraHint => 'חידוש, שאלה, מראה מקום, איך הלך…';

  @override
  String get logSheetHaaraHelper => 'נאסף ביומן ההערות שלך.';

  @override
  String get logSheetMarkLearned => 'סימון כנלמד';

  @override
  String get logSheetSaveChanges => 'שמירת השינויים';

  @override
  String get whatStartingTimer => 'הפעלת שעון הלימוד';

  @override
  String get whatPausingTimer => 'השהיית שעון הלימוד';

  @override
  String get whatResettingTimer => 'איפוס שעון הלימוד';

  @override
  String get whatEndingTimer => 'סיום שעון הלימוד';

  @override
  String dateTimeLabel(String date, String time) {
    return '$date · $time';
  }

  @override
  String get addChazaraTitle => 'הוספת חזרה';

  @override
  String get addChazaraReviewed => 'נחזר:';

  @override
  String get addChazaraSubmit => 'רישום החזרה';

  @override
  String whatLoggingChazara(String unit) {
    return 'רישום חזרה על $unit';
  }

  @override
  String get detailsNotLearnedYet => 'עדיין לא נלמד.';

  @override
  String get detailsFinished => 'הסתיים';

  @override
  String get detailsTimeToLearn => 'זמן הלימוד';

  @override
  String get detailsNotRecorded => 'לא נרשם';

  @override
  String get detailsChazaraPasses => 'מספר חזרות';

  @override
  String get detailsNoneYet => 'עדיין אין';

  @override
  String get detailsHaara => 'הערה';

  @override
  String get detailsNoHaara => 'אין הערה';

  @override
  String get detailsEdit => 'עריכת הפרטים';

  @override
  String get detailsAddChazara => 'הוספת חזרה';

  @override
  String get detailsUnmark => 'ביטול הסימון';

  @override
  String detailsEditTitle(String unit) {
    return 'עריכה · $unit';
  }

  @override
  String chazaraPass(int n) {
    return 'חזרה $n';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes ד׳';
  }

  @override
  String whatSavingDetails(String unit) {
    return 'שמירת הפרטים של $unit';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes דקות';
  }

  @override
  String durationHours(int hours) {
    return '$hours שעות';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours שע׳ $minutes ד׳';
  }

  @override
  String get bulkTitle => 'פעולות מרוכזות';

  @override
  String bulkAllUnitsUnderneath(String name) {
    return '$name · כל היחידות שמתחתיו';
  }

  @override
  String get bulkFinishAll => 'סיום הכול';

  @override
  String get bulkFinishAllSubtitle => 'סימון המפרשים הנדרשים בכל יחידה כנלמדו';

  @override
  String bulkMarkAllLayer(String layer) {
    return 'סימון הכול — $layer';
  }

  @override
  String get bulkMainTextSubtitle => 'הפנים בכל יחידה';

  @override
  String get bulkFinishRange => 'סיום טווח…';

  @override
  String get bulkFinishRangeSubtitle => 'בחירת יחידת התחלה וסיום';

  @override
  String get bulkClearAll => 'ניקוי הכול';

  @override
  String get bulkClearAllSubtitle => 'ביטול הסימון של כל יחידה (ושל מפרשיה)';

  @override
  String get bulkNothingToChange => 'אין מה לשנות';

  @override
  String bulkConfirmUnits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הפעולה משנה $countString יחידות.',
      one: 'הפעולה משנה יחידה אחת.',
    );
    return '$_temp0';
  }

  @override
  String get bulkUndoNote =>
      'אפשר לבטל את הפעולה דרך הגדרות ← היסטוריית פעולות מרוכזות, בכל זמן שתרצה.';

  @override
  String bulkFinishAllTitle(String name) {
    return 'לסיים את כל ״$name״?';
  }

  @override
  String bulkWhatFinishingAll(String name) {
    return 'סיום כל ״$name״';
  }

  @override
  String bulkMarkLayerTitle(String layer, String name) {
    return 'לסמן $layer בכל ״$name״?';
  }

  @override
  String bulkWhatMarkingLayer(String layer, String name) {
    return 'סימון $layer בכל ״$name״';
  }

  @override
  String bulkClearAllTitle(String name) {
    return 'לנקות את כל ״$name״?';
  }

  @override
  String bulkWhatClearingAll(String name) {
    return 'ניקוי כל ״$name״';
  }

  @override
  String get bulkClearWarningLeaf =>
      'מבטל את הסימון של כל יחידה כאן, כולל כל מפרש שסימנת.';

  @override
  String get bulkClearWarningCategory =>
      'מבטל את הסימון של כל יחידה שמתחת לזה — כולל כל המפרשים.';

  @override
  String bulkRangeTitle(int start, int end, String name) {
    return 'לסיים את היחידות $start–$end של ״$name״?';
  }

  @override
  String bulkWhatFinishingRange(int start, int end, String name) {
    return 'סיום היחידות $start–$end של ״$name״';
  }

  @override
  String bulkReportFinished(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הסתיימו $countString יחידות',
      one: 'הסתיימה יחידה אחת',
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
      other: 'נוקו $countString יחידות',
      one: 'נוקתה יחידה אחת',
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
      other: '$layer סומן ב־$countString יחידות',
      one: '$layer סומן ביחידה אחת',
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
      other: 'הסתיימו $countString יחידות בטווח $start–$end',
      one: 'הסתיימה יחידה אחת בטווח $start–$end',
    );
    return '$_temp0';
  }

  @override
  String get whatUndoingBulk => 'ביטול הפעולה המרוכזת';

  @override
  String get rangeDialogTitle => 'סיום טווח';

  @override
  String rangeDialogBody(int first, int last) {
    return 'יחידות $first–$last. שני הקצוות כלולים.';
  }

  @override
  String get rangeFrom => 'מ־';

  @override
  String get rangeTo => 'עד';

  @override
  String get rangeErrorTwoNumbers => 'הזן שני מספרים.';

  @override
  String rangeErrorBounds(int first, int last) {
    return 'היחידות נעות בין $first ל־$last.';
  }

  @override
  String get bulkHistoryTitle => 'היסטוריית פעולות מרוכזות';

  @override
  String get bulkHistoryEmpty =>
      'אין עדיין פעולות מרוכזות.\n\nכל סיום או ניקוי מרוכז יופיע כאן, ויישאר ניתן לביטול עד שתבטל אותו.';

  @override
  String bulkHistoryFinishedEntry(int count, String where) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הסתיימו $countString יחידות',
      one: 'הסתיימה יחידה אחת',
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
      other: 'נוקו $countString יחידות',
      one: 'נוקתה יחידה אחת',
    );
    return '$_temp0 · $where';
  }

  @override
  String bulkHistorySefarimCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ספרים',
      one: 'ספר אחד',
    );
    return '$_temp0';
  }

  @override
  String bulkHistoryWhereWithCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ספרים',
      one: 'ספר אחד',
    );
    return '$name ($_temp0)';
  }

  @override
  String get bulkHistoryUndoTitle => 'לבטל את הפעולה המרוכזת הזו?';

  @override
  String bulkHistoryUndoFinishBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מסיר את $countString הסימונים שהפעולה הזו יצרה.',
      one: 'מסיר את הסימון האחד שהפעולה הזו יצרה.',
    );
    return '$_temp0 כל מה שלמדת לפניה נשאר כפי שהוא.';
  }

  @override
  String bulkHistoryUndoClearBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מחזיר את $countString היחידות שהפעולה הזו ניקתה.',
      one: 'מחזיר את היחידה האחת שהפעולה הזו ניקתה.',
    );
    return '$_temp0';
  }

  @override
  String get whatUndoingThisBulk => 'ביטול הפעולה המרוכזת הזו';

  @override
  String bulkHistoryUndone(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בוטל — $countString רשומות הוסרו',
      one: 'בוטל — רשומה אחת הוסרה',
    );
    return '$_temp0';
  }

  @override
  String get mefarshimTitle => 'מפרשים';

  @override
  String get mefarshimExplainer =>
      'כל מפרש הוא כבוי, זמין לסימון כאן, או חובה — יחידה נחשבת גמורה רק לאחר שכל חובה נלמד. חל על כל מה שמתחת לפריט הזה, אלא אם נקבע אחרת.';

  @override
  String get mefarshimSetHere => 'נקבע על פריט זה.';

  @override
  String mefarshimInheritedFrom(String name) {
    return 'בירושה מ־$name. שמירה תקבע אותם כאן.';
  }

  @override
  String get mefarshimDefault =>
      'ברירת מחדל (פנים בלבד). שמירה תקבע כאן קבוצה.';

  @override
  String get mefarshimAvailable => 'זמין';

  @override
  String get mefarshimOff => 'כבוי';

  @override
  String get mefarshimAddMeforish => 'הוספת מפרש';

  @override
  String get mefarshimResetToInherited => 'איפוס לירושה';

  @override
  String get mefarshimNewTitle => 'מפרש חדש';

  @override
  String mefarshimEditTitle(String name) {
    return 'עריכת ״$name״';
  }

  @override
  String get mefarshimNeedName => 'תן למפרש שם, באחת מהשפות.';

  @override
  String get tooltipEditMeforish => 'עריכת המפרש';

  @override
  String whatSavingMeforish(String name) {
    return 'שמירת המפרש ״$name״';
  }

  @override
  String get mefarshimHebrewOptional => 'עברית (רשות)';

  @override
  String get tooltipDeleteMeforish => 'מחיקת המפרש';

  @override
  String mefarshimDeleteTitle(String name) {
    return 'למחוק את ״$name״?';
  }

  @override
  String mefarshimDeleteRequiredWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הוא מוגדר כחובה ב־$count מקומות.',
      one: 'הוא מוגדר כחובה במקום אחד.',
    );
    return '$_temp0 היחידות האלה לא יזדקקו לו עוד, וכל מה שהמתין לו ייחשב גמור.';
  }

  @override
  String get mefarshimDeleteLogNote =>
      'חזרות ולימוד שכבר רשמת עליו נשארים ביומן שלך.';

  @override
  String whatSavingMefarshim(String name) {
    return 'שמירת המפרשים של $name';
  }

  @override
  String whatResettingMefarshim(String name) {
    return 'איפוס המפרשים של $name';
  }

  @override
  String whatDeletingMeforish(String name) {
    return 'מחיקת ״$name״';
  }

  @override
  String whatAddingMeforish(String name) {
    return 'הוספת המפרש ״$name״';
  }

  @override
  String get mefarshimProgressEmpty =>
      'עדיין לא נלמד דבר.\nככל שתסמן מפרשים, הסיכומים שלהם יופיעו כאן.';

  @override
  String get chazaraTitle => 'חזרות לביצוע';

  @override
  String get chazaraEmpty =>
      'אין כרגע דבר לחזרה.\nיחידות שנלמדו חוזרות לכאן לפי לוח זמנים מדורג.';

  @override
  String get chazaraDueToday => 'לביצוע היום';

  @override
  String chazaraOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'באיחור של $count ימים',
      one: 'באיחור של יום אחד',
    );
    return '$_temp0';
  }

  @override
  String chazaraRowSubtitle(String overdue, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חזרות עד כה',
      one: 'חזרה אחת עד כה',
      zero: 'עדיין ללא חזרות',
    );
    return '$overdue · $_temp0';
  }

  @override
  String get chazaraLogWithDetails => 'רישום עם פרטים';

  @override
  String chazaraReviewed(String unit) {
    return 'נערכה חזרה על $unit';
  }

  @override
  String get siyumEmpty =>
      'אין עדיין סיומים.\nסיים כל יחידה בספר — או בסדר שלם — והוא יופיע כאן. חזק!';

  @override
  String siyumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count סיומים',
      one: 'סיום אחד',
    );
    return '$_temp0 — יישר כח!';
  }

  @override
  String siyumCompleted(String date, String units) {
    return 'הסתיים $date · $units';
  }

  @override
  String get siyumEverythingUnderneath => ' · כל מה שמתחתיו';

  @override
  String get journalTitle => 'יומן הערות';

  @override
  String get journalSearchHint => 'חיפוש בהערות…';

  @override
  String get journalEmpty =>
      'אין עדיין הערות.\nהוסף אחת כשאתה רושם או עורך דף — שדה ״הערה״ מגיע לכאן.';

  @override
  String journalNoMatches(String query) {
    return 'אין הערות התואמות ל״$query״.';
  }

  @override
  String get journalUnknownItem => 'פריט לא ידוע';

  @override
  String journalSubtitle(String location, String date) {
    return '$location · $date';
  }

  @override
  String get searchPrompt => 'חיפוש ספרים, מסכתות, דפים…';

  @override
  String get searchNoMatches => 'אין תוצאות.';

  @override
  String get reportsTitle => 'דוחות';

  @override
  String get reportTabOverview => 'סקירה';

  @override
  String get reportTabCalculator => 'מחשבון';

  @override
  String get reportTabGoals => 'יעדים';

  @override
  String get reportTabSiyumim => 'סיומים';

  @override
  String get reportTabMefarshim => 'מפרשים';

  @override
  String get statsOverall => 'סך הכול';

  @override
  String get statsLearned => 'נלמד';

  @override
  String get statsStreak => 'רצף';

  @override
  String statsStreakValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ימים',
      one: 'יום אחד',
    );
    return '$_temp0';
  }

  @override
  String get statsAvgPerDay => 'ממוצע ליום (30 ימים)';

  @override
  String get statsTimeLearned => 'זמן לימוד';

  @override
  String get statsTimeThisMonth => 'זמן החודש';

  @override
  String get statsProjectedSiyum => 'סיום צפוי';

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
  String get statsProgressOverTime => 'התקדמות לאורך זמן';

  @override
  String get statsActivity => 'פעילות (12 השבועות האחרונים)';

  @override
  String get statsNeedMoreData => 'למד עוד כמה יחידות כדי לראות מגמה.';

  @override
  String get calculatorWhatFinishing => 'מה אתה מסיים?';

  @override
  String calculatorRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'נותרו $remainingString מתוך $totalString';
  }

  @override
  String get calculatorModeRate => 'קצב';

  @override
  String get calculatorModeCycle => 'מחזור';

  @override
  String get calculatorModeByDate => 'לפי תאריך';

  @override
  String get calculatorAmountPerDay => 'כמות ליום';

  @override
  String get calculatorAmountShabbos => 'כמות בשבת (רשות)';

  @override
  String get calculatorCycleAmounts =>
      'כמויות המחזור (מופרדות בפסיק, אחת לכל יום)';

  @override
  String get calculatorCycleAmountsHelper =>
      'לדוגמה ״5, 5, 5, 5, 5, 0, 10״ הוא מחזור של 7 ימים';

  @override
  String get calculatorCycleDay => 'באיזה יום במחזור אתה היום?';

  @override
  String get calculatorCycleDayHelper =>
      '1 = הכמות הראשונה למעלה; 4 = אתה ביום הרביעי';

  @override
  String calculatorTarget(String date) {
    return 'יעד: $date';
  }

  @override
  String get calculatorPickDate => 'בחירת תאריך';

  @override
  String get calculatorSaveGoal => 'שמירה כיעד';

  @override
  String get calculatorGoalSaved => 'נשמר כיעד';

  @override
  String calculatorGoalSetFor(String name) {
    return 'נקבע יעד עבור ״$name״';
  }

  @override
  String get calculatorAlreadyFinished => 'כבר סיימת! 🎉';

  @override
  String get calculatorEnterDailyAmount => 'הזן כמות יומית גדולה מ־0.';

  @override
  String get calculatorEnterAmounts => 'הזן כמויות, לדוגמה ״5, 5, 0, 10״.';

  @override
  String get calculatorCycleNeverFinishes =>
      'המחזור הזה לעולם לא מסתיים (הכול אפסים).';

  @override
  String get calculatorPickFutureDate => 'בחר תאריך בעתיד.';

  @override
  String get calculatorNeverFinish => 'בקצב הזה לעולם לא תסיים.';

  @override
  String calculatorFinishOn(String date, int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString ימים',
      one: 'יום אחד',
    );
    return 'תסיים בתאריך $date\n(בעוד $_temp0 בערך).';
  }

  @override
  String calculatorCycleLength(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ימים',
      one: 'יום אחד',
    );
    return '\nאורך המחזור: $_temp0.';
  }

  @override
  String calculatorRequiredRate(String rate, String date) {
    return 'למד $rate ליום כדי לסיים עד\n$date.';
  }

  @override
  String get cyclesTitle => 'מחזורי לימוד';

  @override
  String get cyclesWhichToShow => 'אילו מחזורים להציג';

  @override
  String get cyclesNew => 'מחזור חדש';

  @override
  String cyclesToday(String date) {
    return 'היום · $date';
  }

  @override
  String get cyclesEmpty =>
      'אין עדיין מחזורים. הפעל אחד מובנה, או הגדר משלך — כל ספר, בכל סדר, בכל קצב.';

  @override
  String get cyclesBuiltInExplainer =>
      'המחזורים המובנים הם אלה שלוח השנה העברי יכול לחשב במדויק. לכל דבר אחר, הגדר מחזור משלך.';

  @override
  String get cycleBavliName => 'דף יומי (בבלי)';

  @override
  String get cycleBavliDescription => 'דף אחד בתלמוד בבלי ליום';

  @override
  String get cycleYerushalmiName => 'דף יומי (ירושלמי)';

  @override
  String get cycleYerushalmiDescription => 'דף אחד בתלמוד ירושלמי ליום';

  @override
  String whatShowingCycle(String name) {
    return 'הצגת $name';
  }

  @override
  String whatHidingCycle(String name) {
    return 'הסתרת $name';
  }

  @override
  String cycleNumber(String description, int number) {
    return '$description · מחזור $number';
  }

  @override
  String get tooltipEditCycle => 'עריכת המחזור';

  @override
  String get cycleNothingToday => 'אין למחזור הזה דבר בלוח להיום.';

  @override
  String cycleDeleteTitle(String name) {
    return 'למחוק את ״$name״?';
  }

  @override
  String get cycleDeleteBody =>
      'רק המחזור נמחק. כל מה שלמדת דרכו נשאר ביומן שלך.';

  @override
  String whatDeletingCycle(String name) {
    return 'מחיקת המחזור ״$name״';
  }

  @override
  String cycleUnitOutOfRange(String name, int unit) {
    return 'ל״$name״ אין יחידה $unit, ולכן לא ניתן לרשום זאת. בדוק את מספר היחידות של הספר, או קשר את המחזור לספר אחר.';
  }

  @override
  String get cycleAlreadyLearned => 'כבר נלמד ✓';

  @override
  String cycleLearnedOn(String date) {
    return 'נלמד ב־$date ✓';
  }

  @override
  String cycleLogButton(String unit) {
    return 'רישום $unit';
  }

  @override
  String cycleLogged(String unit) {
    return '$unit נרשם';
  }

  @override
  String cycleSeferNotInCatalog(String name) {
    return '״$name״ אינו מופיע בקטלוג שלך בשם הזה.';
  }

  @override
  String get cycleLinkToSefer => 'קישור לספר';

  @override
  String cycleLinkTitle(String name) {
    return 'קישור ״$name״ אל…';
  }

  @override
  String whatLinkingSefer(String from, String to) {
    return 'קישור ״$from״ אל $to';
  }

  @override
  String cycleLinked(String from, String to) {
    return '״$from״ קושר אל $to';
  }

  @override
  String cycleDafHebrew(String sefer, int unit) {
    return '$sefer · דף $unit';
  }

  @override
  String get editCycleTitle => 'עריכת מחזור';

  @override
  String get newCycleTitle => 'מחזור חדש';

  @override
  String get editCycleNameHint =>
      'לדוגמה משנה יומית, רמב״ם יומי, סדר החזרה שלי';

  @override
  String get editCycleUnitsPerDay => 'יחידות ליום';

  @override
  String get editCycleUnitsPerDayHelper => 'משנה יומית היא 2; דף ליום הוא 1.';

  @override
  String get editCycleStartedOn => 'התחיל בתאריך';

  @override
  String get editCycleRepeats => 'מתחיל מחדש בסיומו';

  @override
  String get editCycleRepeatsSubtitle => 'כבוי = תוכנית חד־פעמית';

  @override
  String get editCycleSefarimInOrder => 'ספרים, לפי הסדר';

  @override
  String editCycleTotalUnits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString יחידות',
      one: 'יחידה אחת',
    );
    return '$_temp0';
  }

  @override
  String get editCycleEmpty => 'הוסף את הספרים שהמחזור עובר עליהם.';

  @override
  String get editCycleAddSefer => 'הוספת ספר';

  @override
  String get editCycleSaveExisting => 'שמירת המחזור';

  @override
  String get editCycleCreate => 'יצירת המחזור';

  @override
  String editCycleSegmentSubtitle(int count, int offset) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString יחידות מ־$offset';
  }

  @override
  String get tooltipMoveUp => 'העלאה';

  @override
  String get tooltipMoveDown => 'הורדה';

  @override
  String get tooltipRemove => 'הסרה';

  @override
  String get editCycleAddDialogTitle => 'הוספת ספר או קטגוריה';

  @override
  String get editCycleEverythingUnderneath => 'כל מה שמתחתיו';

  @override
  String get editCycleNeedName => 'תן שם למחזור.';

  @override
  String get editCycleNeedPerDay => 'יחידות ליום חייב להיות לפחות 1.';

  @override
  String get editCycleNeedSegment => 'הוסף לפחות ספר אחד שהמחזור יעבור עליו.';

  @override
  String whatSavingCycle(String name) {
    return 'שמירת המחזור ״$name״';
  }

  @override
  String get addNodeTitle => 'הוספה';

  @override
  String editNodeTitle(String name) {
    return 'עריכת ״$name״';
  }

  @override
  String get addNodeHebrewName => 'שם בעברית (רשות)';

  @override
  String get addNodeParent => 'פריט אב';

  @override
  String get addNodeTopLevel => '— רמה עליונה —';

  @override
  String get addNodeIsLeaf => 'ספר למעקב (בעל יחידות)';

  @override
  String get addNodeIsLeafSubtitle => 'כבוי = תיקייה/קטגוריה';

  @override
  String get addNodeUnitType => 'סוג היחידה';

  @override
  String get addNodeUnitCount => 'מספר היחידות';

  @override
  String get addNodeFirstUnit => 'מספר היחידה הראשונה';

  @override
  String get addNodeUnitNames => 'שמות היחידות (רשות, אחד בכל שורה)';

  @override
  String get addNodeUnitNamesHelper =>
      'לדוגמה שמות פרשיות או סימנים — יוצגו במקום מספרים, לפי הסדר מהיחידה הראשונה.';

  @override
  String get addNodeLoweringCount =>
      'הקטנת המספר מסתירה את ההתקדמות ביחידות שהוסרו אך שומרת אותה — הגדל אותו שוב כדי להחזירן.';

  @override
  String get addNodeNeedName => 'אנא הזן שם.';

  @override
  String get addNodeNeedNameEither => 'תן לו שם, באחת מהשפות.';

  @override
  String get addNodeNeedUnits => 'מספר היחידות חייב להיות גדול מ־0.';

  @override
  String get addNodeTooManyUnits => 'זה יותר יחידות ממה שיש בכל ספר.';

  @override
  String get addNodeNegativeOffset =>
      'מספר היחידה הראשונה אינו יכול להיות שלילי.';

  @override
  String addNodeTooManyNames(int names, int units) {
    return 'רשמת $names שמות יחידות אך יש רק $units יחידות.';
  }

  @override
  String whatSavingNode(String name) {
    return 'שמירת ״$name״';
  }

  @override
  String whatAddingNode(String name) {
    return 'הוספת ״$name״';
  }

  @override
  String get profilesTitle => 'פרופילים';

  @override
  String get profilesNew => 'פרופיל חדש';

  @override
  String get profilesActive => 'פעיל';

  @override
  String get profilesRenameTitle => 'שינוי שם הפרופיל';

  @override
  String profilesDeleteTitle(String name) {
    return 'למחוק את ״$name״?';
  }

  @override
  String get profilesDeleteBody =>
      'פעולה זו מוחקת לצמיתות את הפרופיל ואת כל היסטוריית הלימוד שלו, הספרים שהוספת והיעדים. לא ניתן לבטל אותה.';

  @override
  String whatSwitchingProfile(String name) {
    return 'מעבר אל ״$name״';
  }

  @override
  String whatRenamingProfile(String from, String to) {
    return 'שינוי השם מ־״$from״ ל־״$to״';
  }

  @override
  String whatDeletingProfile(String name) {
    return 'מחיקת ״$name״';
  }

  @override
  String profileDeleted(String name) {
    return '״$name״ נמחק.';
  }

  @override
  String profileLastOneKept(String name) {
    return 'חייב להישאר לפחות פרופיל אחד, ולכן ״$name״ נשמר.';
  }

  @override
  String profileDeleteFailed(String name) {
    return 'מחיקת ״$name״ נכשלה.';
  }

  @override
  String whatCreatingProfile(String name) {
    return 'יצירת הפרופיל ״$name״';
  }

  @override
  String get sortSheetTitle => 'מיון העץ';

  @override
  String get sortDescending => 'סדר יורד';

  @override
  String get sortDescendingSubtitle => 'הגבוה / האחרון תחילה';

  @override
  String get sortApplyTo => 'החל על';

  @override
  String get sortAllLevels => 'כל הרמות';

  @override
  String get sortChildren => 'פריטי משנה';

  @override
  String sortLevel(int n) {
    return 'רמה $n';
  }

  @override
  String get whatSavingSortOrder => 'שמירת סדר המיון';

  @override
  String get sortMetricCatalog => 'סדר הקטלוג';

  @override
  String get sortMetricName => 'שם';

  @override
  String get sortMetricPercent => 'אחוז השלמה';

  @override
  String get sortMetricLearned => 'כמות שנלמדה';

  @override
  String get sortMetricRemaining => 'כמות שנותרה';

  @override
  String get sortMetricLastLearned => 'נלמד לאחרונה';

  @override
  String sessionLearning(String clock) {
    return '$clock  ·  לומד';
  }

  @override
  String sessionPaused(String clock) {
    return '$clock  ·  מושהה';
  }

  @override
  String sessionLabelled(String clock, String label) {
    return '$clock  ·  $label';
  }

  @override
  String get tooltipPauseSession => 'השהיית הלימוד';

  @override
  String get tooltipResumeSession => 'המשך הלימוד';

  @override
  String get tooltipDiscardSession => 'ביטול הלימוד';

  @override
  String get whatPausingSession => 'השהיית הלימוד';

  @override
  String get whatResumingSession => 'המשך הלימוד';

  @override
  String get whatDiscardingSession => 'ביטול הלימוד';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsSectionCalendar => 'לוח שנה';

  @override
  String get settingsCalendarGregorian => 'לועזי (גרגוריאני)';

  @override
  String get settingsCalendarHebrew => 'עברי';

  @override
  String get whatChangingCalendar => 'שינוי לוח השנה';

  @override
  String get settingsSectionAppearance => 'מראה';

  @override
  String get settingsThemeSystem => 'לפי המערכת';

  @override
  String get settingsThemeLight => 'בהיר';

  @override
  String get settingsThemeDark => 'כהה';

  @override
  String get whatChangingTheme => 'שינוי ערכת הנושא';

  @override
  String get settingsLanguage => 'עברית';

  @override
  String get settingsLanguageSubtitle => 'הצגת האפליקציה בעברית, מימין לשמאל';

  @override
  String get whatChangingLanguage => 'שינוי השפה';

  @override
  String get settingsSectionReminders => 'תזכורות';

  @override
  String get settingsDailyNudge => 'תזכורת לימוד יומית';

  @override
  String get settingsDailyNudgeSubtitle =>
      'הצגת תזכורת באפליקציה אם עדיין לא למדת היום';

  @override
  String get whatChangingNudge => 'שינוי התזכורת היומית';

  @override
  String get settingsSectionChazara => 'חזרה';

  @override
  String get settingsReviewIntervals => 'מרווחי חזרה';

  @override
  String settingsReviewIntervalsSubtitle(String intervals) {
    return '$intervals ימים לאחר כל חזרה';
  }

  @override
  String get settingsIntervalsTitle => 'מרווחי החזרה';

  @override
  String get settingsIntervalsBody =>
      'מספר הימים לאחר כל חזרה עד לחזרה הבאה, לדוגמה ״1, 3, 7, 16, 35, 70״. הערך האחרון חוזר על עצמו מכאן והלאה.';

  @override
  String get settingsIntervalsHint => '1, 3, 7, 16, 35, 70';

  @override
  String get whatSavingIntervals => 'שמירת מרווחי החזרה';

  @override
  String get settingsSectionMeforishBars => 'פסי מפרשים';

  @override
  String get settingsMeforishBarsExplainer =>
      'הצגה או הסתרה של פס הכיסוי של כל מפרש מתחת לפסי ההתקדמות בעץ.';

  @override
  String whatShowingBar(String name) {
    return 'הצגת הפס של $name';
  }

  @override
  String whatHidingBar(String name) {
    return 'הסתרת הפס של $name';
  }

  @override
  String get settingsSectionProfiles => 'פרופילים';

  @override
  String get settingsManageProfiles => 'ניהול פרופילים';

  @override
  String get settingsSectionHistory => 'היסטוריה';

  @override
  String get settingsBulkHistory => 'היסטוריית פעולות מרוכזות';

  @override
  String get settingsBulkHistoryEmpty =>
      'ביטול סיום־הכול או ניקוי־הכול, בכל זמן';

  @override
  String settingsBulkHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פעולות ניתנות לביטול',
      one: 'פעולה אחת ניתנת לביטול',
    );
    return '$_temp0';
  }

  @override
  String get settingsSectionBackup => 'גיבוי';

  @override
  String get settingsExportFile => 'ייצוא לקובץ';

  @override
  String get settingsExportFileSubtitle => 'שמירת כל ההתקדמות כקובץ JSON';

  @override
  String get settingsImportFile => 'ייבוא מקובץ';

  @override
  String get settingsImportFileSubtitle =>
      'מיזוג קובץ JSON שמור — מוסיף את מה שחסר, שומר על כל מה שכבר יש לך';

  @override
  String get settingsRestoreFile => 'שחזור מקובץ';

  @override
  String get settingsRestoreFileSubtitle =>
      'התאמת היסטוריית הלימוד שלך לגיבוי במדויק, תוך ביטול כל מה שנרשם מאז. ספרים מיוחדים, מפרשים והגדרות נשמרים.';

  @override
  String get settingsRestoreEverything => 'שחזור הכול מקובץ';

  @override
  String get settingsRestoreEverythingSubtitle =>
      'התאמת כל הפרופיל הזה לגיבוי — וגם מחיקת הספרים המיוחדים, המפרשים והגדרות המפרשים שהוספת מאז';

  @override
  String get settingsExportClipboard => 'ייצוא ללוח';

  @override
  String get settingsExportClipboardSubtitle => 'העתקת כל ההתקדמות כ־JSON';

  @override
  String get settingsImportClipboard => 'ייבוא מהלוח';

  @override
  String get settingsImportClipboardSubtitle => 'הדבק ייצוא קודם לשחזור/מיזוג';

  @override
  String get settingsCrashLog => 'יומן קריסות';

  @override
  String get settingsCrashLogSubtitle =>
      'נשמר במכשיר הזה בלבד — העתק אותו לדיווח על תקלה';

  @override
  String get settingsSectionReset => 'איפוס';

  @override
  String get settingsClearSettings => 'ניקוי ההגדרות';

  @override
  String get settingsClearSettingsSubtitle =>
      'איפוס ההעדפות והסרת היעדים, מחזורי הלימוד, הספרים שהוספת, המפרשים והגדרות החובה. יומן הלימוד שלך נשמר.';

  @override
  String get settingsClearTitle => 'לנקות את כל ההגדרות?';

  @override
  String get settingsClearBody =>
      'פעולה זו מאפסת את ההעדפות ומסירה את היעדים, מחזורי הלימוד, הספרים שהוספת, המפרשים שהוספת והגדרות המפרשים הנדרשים. יומן הלימוד שלך (כל מה שסימנת כנלמד) אינו נוגע.';

  @override
  String get whatClearingSettings => 'ניקוי ההגדרות';

  @override
  String get settingsCleared => 'ההגדרות נוקו';

  @override
  String get settingsBackupReminder => 'הזכר לי לגבות';

  @override
  String get settingsBackupReminderSubtitle =>
      'הודעה כשיש לימוד שאף ייצוא אינו כולל. הנתונים שלך לעולם אינם יוצאים מהמכשיר מעצמם — הייצוא הזה הוא העותק היחיד שישרוד את אובדנו.';

  @override
  String get whatChangingBackupReminder => 'שינוי תזכורת הגיבוי';

  @override
  String get settingsBackupInterval => 'הזכר לי לאחר';

  @override
  String settingsBackupIntervalSubtitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ימים של לימוד שאינו מגובה',
      one: 'יום אחד של לימוד שאינו מגובה',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupIntervalBody =>
      'כמה ימי לימוד אתה מוכן שיהיו רק על המכשיר הזה לפני שהאפליקציה תזכיר לך.';

  @override
  String get settingsBackupIntervalLabel => 'ימים';

  @override
  String get settingsBackupIntervalInvalid => 'הזן מספר ימים גדול מ־0.';

  @override
  String get whatSavingBackupInterval => 'שמירת מרווח תזכורת הגיבוי';

  @override
  String get backupNeverExported => 'מעולם לא יוצא';

  @override
  String backupLastExported(String date) {
    return 'יוצא לאחרונה ב־$date';
  }

  @override
  String get backupNothingUnsaved => 'כל מה שלמדת נמצא בגיבוי הזה';

  @override
  String get backupNothingToSaveYet =>
      'אין עדיין מה לגבות — ייצא גיבוי מיד כשתלמד משהו';

  @override
  String backupUnsavedUnits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString יחידות נלמדו מאז — הן קיימות רק על המכשיר הזה',
      one: 'יחידה אחת נלמדה מאז — היא קיימת רק על המכשיר הזה',
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
      other: '$countString יחידות מהלימוד שלך מעולם לא גובו.',
      one: 'יחידה אחת מהלימוד שלך מעולם לא גובתה.',
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
      other: '$countString יחידות נלמדו מאז הגיבוי האחרון',
      one: 'יחידה אחת נלמדה מאז הגיבוי האחרון',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'לפני $daysString ימים',
      one: 'לפני יום אחד',
    );
    return '$_temp0 $_temp1.';
  }

  @override
  String get backupBannerWhy =>
      'הוא נמצא רק על המכשיר הזה — שום דבר אינו מועתק לשום מקום באופן אוטומטי.';

  @override
  String get backupBannerAction => 'גיבוי';

  @override
  String get backupBannerDismiss => 'כיבוי התזכורת הזו';

  @override
  String get backupBannerDismissed =>
      'תזכורת הגיבוי כבויה — אפשר להפעילה שוב בהגדרות ← גיבוי';

  @override
  String get backupSaveDialogTitle => 'שמירת גיבוי';

  @override
  String get backupChooseFile => 'בחירת קובץ גיבוי';

  @override
  String get backupChooseRestoreFile => 'בחירת גיבוי לשחזור';

  @override
  String get whatExportingBackup => 'ייצוא הגיבוי';

  @override
  String get whatExportingClipboard => 'ייצוא ללוח';

  @override
  String get whatImportingBackup => 'ייבוא הגיבוי';

  @override
  String get whatRestoringBackup => 'שחזור מהגיבוי';

  @override
  String get backupSaved => 'הגיבוי נשמר';

  @override
  String get backupExportCancelled => 'הייצוא בוטל';

  @override
  String get backupImportCancelled => 'הייבוא בוטל';

  @override
  String get backupRestoreCancelled => 'השחזור בוטל';

  @override
  String get backupExportedClipboard => 'יוצא ללוח';

  @override
  String get backupImportTitle => 'ייבוא נתונים';

  @override
  String get backupImportHint => 'הדבק כאן את ה־JSON של הייצוא';

  @override
  String backupImportFailed(String reason) {
    return 'הייבוא נכשל: $reason';
  }

  @override
  String get backupImportUnreadable =>
      'הייבוא נכשל: לא ניתן היה לקרוא את הקובץ — הוא אינו טקסט.';

  @override
  String get backupImportAppFailure =>
      'הייבוא נכשל בתוך האפליקציה, לא בקובץ שלך. שמור על הקובץ — הוא תקין. ב״פרטים״ מופיעה הסיבה.';

  @override
  String backupImported(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'יובאו $countString רשומות חדשות',
      one: 'יובאה רשומה חדשה אחת',
    );
    return '$_temp0';
  }

  @override
  String get backupNoEvents => 'אין בגיבוי הזה רשומות לימוד';

  @override
  String backupAlreadyUpToDate(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'הכול כבר מעודכן — כל $countString הרשומות כבר היו כאן. ייבוא ממזג, ולכן אינו יכול לבטל דבר שעשית מאז. לשם כך השתמש ב״שחזור מקובץ״.';
  }

  @override
  String get restoreConfirmTitle => 'לשחזר מהגיבוי הזה?';

  @override
  String get restoreConfirmNoChange =>
      'הפרופיל הזה כבר תואם לגיבוי — דבר לא ישתנה.';

  @override
  String get restoreConfirmIntro =>
      'פעולה זו מתאימה את היסטוריית הלימוד שלך לגיבוי במדויק, ומבטלת כל מה שנרשם מאז.';

  @override
  String get restoreConfirmIntroEverything =>
      'פעולה זו מתאימה את כל הפרופיל לגיבוי, ומבטלת כל מה שנרשם מאז — כולל הספרים וההגדרות שהוספת.';

  @override
  String restoreConfirmLosingCustom(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString ספרים מיוחדים, מפרשים והגדרות מפרשים שהוספת מאז הגיבוי יימחקו.',
      one: 'ספר מיוחד, מפרש או הגדרת מפרשים אחת שהוספת מאז הגיבוי יימחקו.',
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
      other: '$countString ספרים מיוחדים והגדרות נמחקו',
      one: 'ספר מיוחד או הגדרה אחת נמחקו',
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
      other: '$countString יחידות שסימנת מאז הגיבוי לא יהיו מסומנות עוד.',
      one: 'יחידה אחת שסימנת מאז הגיבוי לא תהיה מסומנת עוד.',
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
      other: '$countString יחידות יסומנו מחדש.',
      one: 'יחידה אחת תסומן מחדש.',
    );
    return '$_temp0';
  }

  @override
  String get restoreConfirmBackupFirst =>
      'ייצא גיבוי טרי תחילה אם ברצונך לשמור על ההתקדמות החדשה יותר.';

  @override
  String get restoreAlreadyMatched => 'שוחזר — הפרופיל הזה כבר תאם לגיבוי';

  @override
  String get restoreNoUnitChange => 'שוחזר לגיבוי — אין שינוי ביחידות המסומנות';

  @override
  String restoreSummary(String changes) {
    return 'שוחזר לגיבוי: $changes';
  }

  @override
  String restoreSummaryRestored(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString יחידות מסומנות מחדש',
      one: 'יחידה אחת מסומנת מחדש',
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
      other: '$countString יחידות אינן מסומנות עוד',
      one: 'יחידה אחת אינה מסומנת עוד',
    );
    return '$_temp0';
  }

  @override
  String get crashLogTitle => 'יומן קריסות';

  @override
  String get crashLogCopy => 'העתקה ללוח';

  @override
  String get crashLogClear => 'ניקוי היומן';

  @override
  String get crashLogCopied => 'יומן הקריסות הועתק';

  @override
  String get whatCopyingCrashLog => 'העתקת יומן הקריסות';

  @override
  String get crashLogEmpty =>
      'דבר לא קרס.\n\nאם משהו יקרוס אי־פעם, הפרטים יגיעו לכאן — במכשיר הזה בלבד — כדי שתוכל להעתיק אותם לדיווח על תקלה.';

  @override
  String get errorTitle => 'משהו השתבש';

  @override
  String get errorCatalogTitle => 'לא ניתן היה לטעון את הקטלוג';

  @override
  String get errorCatalogBody =>
      'רשימת הספרים המובנית לא נטענה, ולכן אי אפשר להציג את העץ. יומן הלימוד שלך לא נפגע.';

  @override
  String get errorLogTitle => 'לא ניתן היה לקרוא את יומן הלימוד';

  @override
  String get errorLogBody =>
      'מסד הנתונים לא נפתח. שום דבר לא שונה ולא אבד — זו קריאה שנכשלה.';

  @override
  String get errorProfilesTitle => 'לא ניתן היה לקרוא את הפרופילים';

  @override
  String get errorProfilesBody =>
      'מסד הנתונים לא נפתח. שום דבר לא שונה ולא אבד.';

  @override
  String get errorRetry => 'נסה שוב';

  @override
  String get errorShowDetails => 'הצגת הפרטים';

  @override
  String get errorHideDetails => 'הסתרת הפרטים';

  @override
  String get errorOpenCrashLog => 'פתיחת יומן הקריסות';

  @override
  String get errorDetailsHint =>
      'השגיאה המלאה מופיעה למטה, וכבר נרשמה ביומן הקריסות.';
}
