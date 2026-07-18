import 'dart:async';

import '../models/daily_record_completion.dart';
import '../models/weight_record.dart';
import 'daily_checkin_repo.dart';
import 'distance_records_repo.dart';
import 'weight_records_repo.dart';

class DailyRecordCompletionService {
  final DailyCheckinRepo _checkinRepo;
  final DistanceRecordsRepo _distanceRepo;
  final WeightRecordsRepo _weightRepo;
  final int weightReminderDays;

  DailyRecordCompletionService({
    DailyCheckinRepo? checkinRepo,
    DistanceRecordsRepo? distanceRepo,
    WeightRecordsRepo? weightRepo,
    this.weightReminderDays = 7,
  })  : _checkinRepo = checkinRepo ?? DailyCheckinRepo(),
        _distanceRepo = distanceRepo ?? DistanceRecordsRepo(),
        _weightRepo = weightRepo ?? WeightRecordsRepo();

  Stream<DailyRecordCompletion> watch({
    DateTime? referenceDate,
  }) {
    final reference = _normalize(referenceDate ?? DateTime.now());
    final wheelRecordDate = reference.subtract(const Duration(days: 1));

    late final StreamController<DailyRecordCompletion> controller;

    var conditionLoaded = false;
    var wheelLoaded = false;
    var weightLoaded = false;

    var conditionCompleted = false;
    var wheelCompleted = false;
    WeightRecord? latestWeight;

    StreamSubscription<dynamic>? conditionSubscription;
    StreamSubscription<dynamic>? wheelSubscription;
    StreamSubscription<dynamic>? weightSubscription;

    void emit() {
      if (!conditionLoaded || !wheelLoaded || !weightLoaded) return;

      controller.add(
        DailyRecordCompletion(
          conditionCompleted: conditionCompleted,
          wheelCompleted: wheelCompleted,
          latestWeight: latestWeight,
          weightReminderDays: weightReminderDays,
          referenceDate: reference,
        ),
      );
    }

    controller = StreamController<DailyRecordCompletion>(
      onListen: () {
        conditionSubscription =
            _checkinRepo.watchByDate(reference).listen((record) {
          conditionLoaded = true;
          conditionCompleted = record != null;
          emit();
        }, onError: controller.addError);

        wheelSubscription =
            _distanceRepo.watchDailyRecord(wheelRecordDate).listen((record) {
          wheelLoaded = true;
          wheelCompleted = record != null;
          emit();
        }, onError: controller.addError);

        weightSubscription = _weightRepo.watchLatest().listen((record) {
          weightLoaded = true;
          latestWeight = record;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await conditionSubscription?.cancel();
        await wheelSubscription?.cancel();
        await weightSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  DateTime _normalize(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
