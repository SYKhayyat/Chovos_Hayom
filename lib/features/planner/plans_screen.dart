import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../app/routes.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/recurrence.dart';
import '../../l10n/generated/app_localizations.dart';

/// The way in. Until this existed a plan was only reachable by hand-writing JSON
/// into preferences, so "a plan is an entity" was true of the model and false of
/// the app.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(plansConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plansTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, Routes.editPlan('')),
        icon: const Icon(Icons.add),
        label: Text(l10n.plansAdd),
      ),
      body: config.plans.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.plansEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView.builder(
              itemCount: config.plans.length,
              itemBuilder: (context, index) {
                final plan = config.plans[index];
                return ListTile(
                  title: Text(plan.name),
                  subtitle: Text(describePlan(l10n, plan)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.editPlan(plan.id)),
                );
              },
            ),
    );
  }
}

/// One line saying what a plan actually is, so the list is readable without
/// opening every plan: how much, how often, and — because it is the decision a
/// user is most likely to have forgotten — what happens to a missed day.
String describePlan(AppLocalizations l10n, LearningPlan plan) {
  final rule = plan.assignments.isEmpty ? null : plan.assignments.first.rule;
  final amount = ruleDescription(l10n, rule);
  final perDay = '${l10n.plansUnitsPerDay}: ${plan.unitsPerDay}';
  return amount == null ? perDay : '$perDay · $amount';
}

/// A human description of *when* a plan fires, or null if it has no rule at all.
///
/// A plan with no assignment never fires, so "never" is a real state worth
/// showing rather than an empty string — a user who created a plan and sees
/// nothing on the calendar needs to be told why.
String? ruleDescription(AppLocalizations l10n, RecurrenceRule? rule) {
  if (rule == null) return null;
  if (rule is DailyRule) return l10n.plansRuleDaily;
  if (rule is WeekdayRule) {
    if (rule.weekdays.isEmpty) return l10n.plansRuleDaily;
    return '${l10n.plansRuleWeekdays} (${rule.weekdays.length})';
  }
  if (rule is DayOfMonthRule) return l10n.plansRuleDayOfMonth;
  if (rule is HebrewDayRule) return l10n.plansRuleHebrewDay;
  return l10n.plansRuleDaily;
}
