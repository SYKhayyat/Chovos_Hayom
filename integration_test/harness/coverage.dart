import 'package:chovos_hayom/app/routes.dart';

import 'journey.dart';
import 'journeys/app.dart';
import 'journeys/deep.dart';
import 'journeys/learning.dart';
import 'journeys/planning.dart';

/// Every journey the harness knows about, in the order a person meets them.
List<Journey> allJourneys() => [
  ...learningJourneys(),
  ...deepJourneys(),
  ...planningJourneys(),
  ...appJourneys(),
];

/// Which journeys are responsible for which screen.
///
/// **Declared rather than inferred, and that is the point.** A harness that
/// covers a screen *by accident* — because a journey happened to tap through it
/// on the way somewhere else — is a harness whose coverage changes when an
/// unrelated journey is reordered. So the claim is written down here, the guard
/// checks it in both directions, and this table doubles as the answer to "what
/// does the device harness actually test?".
///
/// Both directions matter. A route with no journey is a screen nothing on a
/// real phone ever opens. A journey that claims a route it does not reach is a
/// screen believed to be covered that is not, which is the more dangerous of the
/// two because it reads as coverage.
final Map<String, List<String>> harnessCovers = {
  Routes.dashboard: [
    'learning/tree-opens',
    'principles/compact-layout-holds',
    'principles/keyboard-can-leave',
    'principles/destructive-asks-first',
  ],
  Routes.plannerToday: [
    'planner/today-goals',
    'principles/compact-layout-holds',
  ],
  Routes.plannerCalendar: [
    'planner/calendar-three-ranges',
    'planner/calendar-arrows-step',
    'planner/calendar-pages-by-key',
    'planner/calendar-day-sheet',
    'principles/compact-layout-holds',
  ],
  Routes.plannerPlans: [
    'planner/plans-list-and-create',
    'planner/plan-rules',
    'planner/plan-overrides-and-sequence',
    'planner/date-typed-in-english',
    'planner/date-typed-in-hebrew',
    'planner/date-ambiguous-is-reported',
    'planner/date-refuses-nonsense',
    'principles/compact-layout-holds',
  ],
  Routes.stats: [
    'reports/tabs',
    'reports/calculator-answers',
    // The chazara row opens here (#45): it reports repeats rather than being
    // due, so there is no separate screen left for it to open.
    'learning/chazara-report',
    'principles/compact-layout-holds',
  ],
  Routes.calculator: ['reports/tabs', 'reports/calculator-answers'],
  Routes.goals: ['reports/tabs', 'reports/goal-round-trip'],
  Routes.siyumim: ['reports/tabs', 'reports/siyum-round-trip'],
  Routes.mefarshim: ['reports/tabs', 'reports/meforish-round-trip'],
  Routes.cycles: [
    'planner/cycles-round-trip',
    'planning/cycle-editor',
    'principles/compact-layout-holds',
  ],
  Routes.newCycle: ['planner/cycles-round-trip'],
  // The chazara report is a tab of the report screen, so it is reached the same
  // way the other tabs are (#46).
  Routes.chazara: [
    'reports/tabs',
    'learning/chazara-report',
    'principles/compact-layout-holds',
  ],
  Routes.journal: [
    'learning/journal-round-trip',
    'principles/compact-layout-holds',
  ],
  Routes.profiles: [
    'profiles/switch-and-come-back',
    'principles/compact-layout-holds',
  ],
  Routes.settings: [
    'settings/everything-is-reachable',
    'settings/day-sheet-layout',
    'settings/a-setting-sticks',
    'settings/backup-can-be-taken',
    'principles/compact-layout-holds',
  ],
  Routes.bulkHistory: ['app/bulk-history-undo'],
  Routes.crashLog: ['app/crash-log-is-readable'],
  Routes.addItem: [
    'learning/custom-sefer-round-trip',
    'principles/compact-layout-holds',
  ],
  Routes.sefer('shas.moed.shabbos'): [
    'learning/sefer-grid',
    'learning/mark-a-daf',
  ],
  Routes.category('shas.moed'): ['learning/category-subtree'],
  Routes.editItem('shas.moed.shabbos'): ['learning/edit-node-details'],
  Routes.editCycle('harness-cycle'): ['planning/cycle-editor'],
  Routes.editPlan('harness-plan'): [
    'planner/plans-list-and-create',
    'planner/plan-rules',
    'planner/plan-overrides-and-sequence',
  ],
  // The plan's own screen (#47) — where it stands and how fast it is moving,
  // and the home of the reflow the day sheet also offers.
  Routes.plan('harness-plan'): ['planner/plan-standing'],
  Routes.editPlanAdvanced('harness-plan'): [
    'planner/plan-rules',
    'planner/plan-overrides-and-sequence',
  ],
  Routes.editPlan(''): ['planner/plans-list-and-create'],
  Routes.addItemUnder('harness-parent'): ['learning/custom-sefer-round-trip'],
};
