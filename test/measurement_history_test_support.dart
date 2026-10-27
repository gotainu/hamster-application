import 'package:hamster_project/services/measurement_history_client.dart';
import 'package:hamster_project/services/weight_records_repo.dart';
import 'package:hamster_project/services/distance_records_repo.dart';
import 'package:hamster_project/models/weight_record.dart';

class MemoryMeasurementPending implements MeasurementPendingStore {
  final values = <String, Map<String, dynamic>>{};
  String key(String owner, String kind) => '$owner:$kind';
  @override
  Future<Map<String, dynamic>?> read(String owner, String kind) async =>
      values[key(owner, kind)];
  @override
  Future<void> write(
      String owner, String kind, Map<String, dynamic> value) async {
    values[key(owner, kind)] = value;
  }

  @override
  Future<void> remove(String owner, String kind) async {
    values.remove(key(owner, kind));
  }
}

Map<String, dynamic> measurementReply(Map<String, dynamic> request,
    {bool replayed = false}) {
  final revision = (request['expectedRevision'] as int) + 1;
  final cancel = request['operation'] == 'cancel';
  final projection = {
    'dayKey': request['dayKey'],
    'date': request['date'],
    'revision': revision,
    'recordId': 'record-one',
    'subjectId': 'subject-one',
    'weightGrams': request['weightGrams'],
    'memo': request['memo'] ?? '',
    'rotations': request['rotations'],
    'distance': request['distance'] ?? 31.4,
    'wheelDiameterCm': request['wheelDiameterCm'] ?? 20.0,
    'timing': request['timing']
  };
  return {
    'saved': true,
    'replayed': replayed,
    'changed': true,
    'dayKey': request['dayKey'],
    'subjectId': 'subject-one',
    'recordId': 'record-one',
    'revision': revision,
    'mutationId': request['mutationId'],
    'recordStatus': cancel ? 'cancelled' : 'active',
    'projection': cancel ? null : projection,
    'acceptedAt': '2026-10-13T01:00:00.123Z',
    'acceptedAtEpochNanoseconds': '1791853200123456789'
  };
}

MeasurementHistoryClient testMeasurementClient(
        {String kind = 'weight',
        MemoryMeasurementPending? pending,
        Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submit,
        String? Function()? owner,
        int dayRevision = 0}) =>
    MeasurementHistoryClient(
        kind: kind,
        pendingStore: pending ?? MemoryMeasurementPending(),
        owner: owner ?? () => 'owner',
        readProfile: () async => {'subjectId': 'subject-one'},
        readDayRevision: (_) async => dayRevision,
        submit: submit ?? (request) async => measurementReply(request));

class WeightHistoryUiRepo extends WeightRecordsRepo {
  WeightHistoryUiRepo({WeightRecord? record, MeasurementHistoryClient? client})
      : initial = record,
        super(historyClient: client ?? testMeasurementClient());
  WeightRecord? initial;
  @override
  Future<WeightRecord?> fetchByDate(DateTime value) async => initial;
  @override
  Future<WeightRecord?> fetchLatestBefore(DateTime value) async => null;
}

class DistanceHistoryUiRepo extends DistanceRecordsRepo {
  DistanceHistoryUiRepo(
      {DailyDistanceRecord? record, MeasurementHistoryClient? client})
      : initial = record,
        super(historyClient: client ?? testMeasurementClient(kind: 'distance'));
  DailyDistanceRecord? initial;
  @override
  Future<DailyDistanceRecord?> fetchDailyRecord(DateTime value) async =>
      initial;
  @override
  Future<double?> refreshWheelDiameter() async => 30;
  @override
  double? get cachedWheelDiameterCm => 30;
}

WeightRecord historyWeight(
        {String? subject = 'subject-one', int revision = 2}) =>
    WeightRecord(
        dayKey: '2026-10-12',
        date: DateTime(2026, 10, 12),
        weightGrams: 120,
        memo: '記録',
        subjectId: subject,
        recordId: subject == null ? null : 'record-one',
        revision: revision,
        timing: subject == null ? null : measurementDateTiming('2026-10-12'));
DailyDistanceRecord historyDistance(
        {double? diameter = 20,
        String? subject = 'subject-one',
        int rotations = 100}) =>
    DailyDistanceRecord(
        dayKey: '2026-10-12',
        date: DateTime(2026, 10, 12),
        distance: 62.8,
        rotations: rotations,
        wheelDiameterCm: diameter,
        subjectId: subject,
        recordId: subject == null ? null : 'record-one',
        revision: 2,
        timing: subject == null
            ? null
            : {
                ...unknownMeasurementTiming,
                'windowMeaning': 'selected_night_to_next_morning'
              });
