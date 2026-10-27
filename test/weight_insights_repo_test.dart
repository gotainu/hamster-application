import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'current_weight_analysis_test_support.dart';
import 'weight_insight_test_support.dart';

class _Reads implements CurrentWeightReadSource {
  String? owner = 'owner-a';
  final owners = StreamController<String?>.broadcast();
  final channels = <String, StreamController<WeightAnalysisDocument>>{};
  @override
  String? get currentOwnerId => owner;
  @override
  Stream<String?> watchOwnerId() async* {
    yield owner;
    yield* owners.stream;
  }

  Stream<WeightAnalysisDocument> watch(String path) => channels
      .putIfAbsent(
          path, () => StreamController<WeightAnalysisDocument>.broadcast())
      .stream;
  @override
  Stream<WeightAnalysisDocument> watchUserDocument(
          String ownerId, String collection, String documentId) =>
      watch('$ownerId/$collection/$documentId');
  @override
  Stream<WeightAnalysisDocument> watchReferenceDocument(String cohortId,
          {String? versionId}) =>
      watch('ref/$cohortId/$versionId');
  void emit(String path, Map<String, dynamic>? value,
          {bool cache = false, bool pending = false}) =>
      channels
          .putIfAbsent(
              path, () => StreamController<WeightAnalysisDocument>.broadcast())
          .add(WeightAnalysisDocument(
              exists: value != null,
              data: value,
              isFromCache: cache,
              hasPendingWrites: pending));
  void switchOwner(String? next) {
    owner = next;
    owners.add(next);
  }

  Future<void> close() async {
    await owners.close();
    for (final channel in channels.values) {
      await channel.close();
    }
  }
}

Future<void> _flush() => pumpEventQueue(times: 5);
void _user(_Reads reads, String owner, {bool learning = false}) {
  reads.emit('$owner/daily_health_features/2026-10-11',
      currentWeightFeaturesFixture(latest: 103, ready: !learning));
  reads.emit('$owner/pet_profiles/main_pet', {'species': '不明'});
}

void main() {
  test('Gold cache and pending writes never become a confirmed current Insight',
      () async {
    final reads = _Reads();
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11, 2),
            evaluationTicks: const Stream.empty(),
            includeInsights: true,
            includeIndividualAnalysisWithoutReference: true)
        .watchCurrent()
        .listen(events.add);
    await _flush();
    _user(reads, 'owner-a');
    await _flush();
    for (final flags in [(true, false), (false, true)]) {
      reads.emit(
          'owner-a/individual_insights/2026-10-11', weightInsightSetFixture(),
          cache: flags.$1, pending: flags.$2);
      await _flush();
      expect(events.last!.insights, isNull);
    }
    reads.emit(
        'owner-a/individual_insights/2026-10-11', weightInsightSetFixture());
    await _flush();
    expect(events.last!.insights!.insights.length, 2);
    reads.emit('owner-a/individual_insights/2026-10-11', null);
    await _flush();
    expect(events.last!.insights, isNull);
    await subscription.cancel();
    await reads.close();
  });
  test(
      'newer Silver rejects old Gold generation and preserves independent baseline',
      () async {
    final reads = _Reads();
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11, 2),
            evaluationTicks: const Stream.empty(),
            includeInsights: true,
            includeIndividualAnalysisWithoutReference: true)
        .watchCurrent()
        .listen(events.add);
    await _flush();
    _user(reads, 'owner-a');
    reads.emit(
        'owner-a/individual_insights/2026-10-11', weightInsightSetFixture());
    await _flush();
    expect(events.last!.insights, isNotNull);
    final updated = currentWeightFeaturesFixture(latest: 103);
    updated['generatedAt'] = DateTime.utc(2026, 10, 11, 3);
    reads.emit('owner-a/daily_health_features/2026-10-11', updated);
    await _flush();
    expect(events.last!.insights, isNull);
    expect(events.last!.individualWeightGrams, 100);
    reads.emit('owner-a/individual_insights/2026-10-11',
        weightInsightSetFixture(generatedAt: '2026-10-11T03:00:00Z'));
    await _flush();
    expect(events.last!.insights, isNotNull);
    await subscription.cancel();
    await reads.close();
  });
  test(
      'learning period, account change and read errors fail safely without research',
      () async {
    final reads = _Reads();
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11, 2),
            evaluationTicks: const Stream.empty(),
            includeInsights: true,
            includeIndividualAnalysisWithoutReference: true)
        .watchCurrent()
        .listen(events.add);
    await _flush();
    _user(reads, 'owner-a', learning: true);
    reads.emit('owner-a/individual_insights/2026-10-11',
        weightInsightSetFixture(range: false, learning: true));
    await _flush();
    expect(events.last!.insights!.insights.length, 1);
    expect(events.last!.omissionReason, 'baseline_learning');
    final oldIndex = events.length;
    reads.switchOwner('owner-b');
    await _flush();
    expect(events.last, isNull);
    reads.emit(
        'owner-a/individual_insights/2026-10-11', weightInsightSetFixture());
    _user(reads, 'owner-b');
    await _flush();
    expect(events.last!.ownerId, 'owner-b');
    expect(events.last!.insights, isNull);
    expect(
        events
            .skip(oldIndex)
            .whereType<CurrentWeightAnalysis>()
            .every((a) => a.ownerId == 'owner-b'),
        isTrue);
    reads.emit(
        'owner-b/individual_insights/2026-10-11', weightInsightSetFixture());
    await _flush();
    expect(events.last!.insights, isNotNull);
    reads.channels['owner-b/individual_insights/2026-10-11']!
        .addError(StateError('permission denied'));
    await _flush();
    expect(events.last!.insights, isNull);
    expect(events.last!.individualWeightGrams, 100);
    await subscription.cancel();
    await reads.close();
  });
}
