import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/models/daily_star_progress.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/services/daily_care_actions_repo.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/services/daily_record_completion_service.dart';
import 'package:hamster_project/services/distance_records_repo.dart';
import 'package:hamster_project/services/weight_records_repo.dart';
import 'package:hamster_project/services/wheel_repo.dart';

class _Db implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Checkin extends DailyCheckinRepo {
  _Checkin() : super(db: _Db(), auth: _Auth());
  @override
  Stream<DailyCheckin?> watchByDate(DateTime d) => Stream.value(null);
}

class _Distance extends DistanceRecordsRepo {
  _Distance()
      : super(
            db: _Db(),
            auth: _Auth(),
            wheelRepo: WheelRepo(db: _Db(), auth: _Auth()));
  @override
  Stream<DailyDistanceRecord?> watchDailyRecord(DateTime d) =>
      Stream.value(null);
}

class _Weight extends WeightRecordsRepo {
  _Weight() : super(db: _Db(), auth: _Auth());
  @override
  Stream<WeightRecord?> watchLatest() => Stream.value(null);
}

class _Care extends DailyCareActionsRepo {
  final Stream<DailyCareActions?> records;
  _Care(this.records);
  @override
  Stream<DailyCareActions?> watchByDay(String day) => records;
}

DailyCareActions _care(CareActionAnswer answer, {String status = 'active'}) =>
    DailyCareActions(
        dayKey: '2026-10-12',
        revision: 1,
        status: status,
        actions: {'roomWalk': CareActionResponse(answer: answer)});
Future<DailyRecordCompletion> _completion(DailyCareActions? record) async {
  final service = DailyRecordCompletionService(
      checkinRepo: _Checkin(),
      distanceRepo: _Distance(),
      weightRepo: _Weight(),
      careRepo: _Care(Stream.value(record)));
  return service.watch(referenceDate: DateTime(2026, 10, 12)).firstWhere(
      (c) => c.conditionCompleted || record?.hasExplicitAnswer != true);
}

void main() {
  for (final answer in [
    CareActionAnswer.performed,
    CareActionAnswer.notPerformed
  ]) {
    test('care ${answer.name} reuses condition slot without fourth slot',
        () async {
      final result = await _completion(_care(answer));
      final slots = DailyStarProgress.fromCompletion(result).slots;
      expect(result.conditionCompleted, isTrue);
      expect(result.wheelCompleted, isFalse);
      expect(slots.length, 3);
      expect(
          slots
              .singleWhere((s) => s.kind == DailyStarSlotKind.condition)
              .filled,
          isTrue);
    });
  }
  test('all unanswered care does not fill condition slot', () async {
    expect(
        (await _completion(_care(CareActionAnswer.unanswered)))
            .conditionCompleted,
        isFalse);
  });
  test('cancelled care does not fill condition slot', () async {
    expect(
        (await _completion(
                _care(CareActionAnswer.performed, status: 'cancelled')))
            .conditionCompleted,
        isFalse);
  });
  test(
      'no server confirmed care never guesses completion from local pending data',
      () async {
    expect((await _completion(null)).conditionCompleted, isFalse);
  });
}
