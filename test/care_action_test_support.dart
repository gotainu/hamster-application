import 'package:flutter/material.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/services/daily_care_actions_repo.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';

class CareTestStore implements CareActionStore {
  CareActionLoadResult initial = const CareActionLoadResult();
  final saved = <CareActionMutation>[];
  bool fail = false;
  bool offline = false;
  String rewardStatus = 'not_processed';
  bool achievementRecorded = false, confirmationPending = false;
  @override
  Future<CareActionLoadResult> load(String dayKey) async => initial;
  @override
  Future<CareActionSaveResult> save(CareActionMutation mutation) async {
    saved.add(mutation);
    if (fail) throw StateError('save failed');
    final result = CareActionSaveResult(
        state: offline
            ? CareActionSaveState.pendingSync
            : CareActionSaveState.saved,
        mutation: mutation,
        revision: mutation.expectedRevision + 1,
        rewardStatus: rewardStatus,
        achievementRecorded: achievementRecorded,
        confirmationPending: confirmationPending);
    if (offline) {
      initial = CareActionLoadResult(pending: mutation, serverConfirmed: false);
    }
    return result;
  }
}

class CareHealthTestStore implements DailyCheckinStore {
  DailyCheckin? initial;
  int saves = 0;
  bool fail = false;
  DailyCheckin? saved;
  @override
  String dateKeyLocal(DateTime dayLocal) => '2026-10-12';
  @override
  DateTime normalizeLocalDay(DateTime dt) => DateTime(2026, 10, 12);
  @override
  Future<DailyCheckin?> fetchByDate(DateTime dayLocal) async => initial;
  @override
  Stream<DailyCheckin?> watchByDate(DateTime dayLocal) => const Stream.empty();
  @override
  Future<void> saveDailyCheckin(
      {required DateTime date,
      required DailyCondition condition,
      required List<String> concernTags,
      required Map<String, DailyObservationLevel> observationLevels,
      String memo = ''}) async {
    saves++;
    if (fail) throw StateError('health failed');
    saved = DailyCheckin(
        dayKey: dateKeyLocal(date),
        date: normalizeLocalDay(date),
        condition: condition,
        concernTags: concernTags,
        observationLevels: observationLevels,
        memo: memo);
  }
}

Widget careInputTestApp(CareHealthTestStore health, CareTestStore care,
        {VoidCallback? onHealth, VoidCallback? onCare}) =>
    MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: DailyConditionInputCard(
                    repo: health,
                    careRepo: care,
                    date: DateTime(2026, 10, 12),
                    onSaved: onHealth,
                    onCareSaved: onCare))));
