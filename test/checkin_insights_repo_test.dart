import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/checkin_insight.dart';
import 'package:hamster_project/services/current_checkin_insights_repo.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'checkin_insight_test_support.dart';

class _Reads implements CurrentCheckinReadSource {
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

  @override
  Stream<WeightAnalysisDocument> watchUserDocument(
          String ownerId, String collection, String id) =>
      channels
          .putIfAbsent('$ownerId/$collection/$id',
              () => StreamController<WeightAnalysisDocument>.broadcast())
          .stream;
  void emit(String path, Map<String, dynamic>? data,
          {bool cache = false, bool pending = false}) =>
      channels
          .putIfAbsent(
              path, () => StreamController<WeightAnalysisDocument>.broadcast())
          .add(WeightAnalysisDocument(
              exists: data != null,
              data: data,
              isFromCache: cache,
              hasPendingWrites: pending));
  void switchOwner(String? next) {
    owner = next;
    owners.add(next);
  }

  Future<void> close() async {
    await owners.close();
    for (final stream in channels.values) {
      await stream.close();
    }
  }
}

Future<void> _flush() => pumpEventQueue(times: 5);
void main() {
  test(
      'current checkin reads only exact-day Silver and Gold; cache/pending denied',
      () async {
    final reads = _Reads();
    final events = <CurrentCheckinAnalysis?>[];
    final sub = CurrentCheckinInsightsRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11, 2),
            evaluationTicks: const Stream.empty())
        .watchCurrent()
        .listen(events.add);
    await _flush();
    expect(
        reads.channels.keys,
        unorderedEquals([
          'owner-a/daily_health_features/2026-10-11',
          'owner-a/individual_insights/2026-10-11'
        ]));
    for (final flags in [(true, false), (false, true)]) {
      reads.emit(
          'owner-a/daily_health_features/2026-10-11', checkinSilverFixture());
      reads.emit('owner-a/individual_insights/2026-10-11', checkinGoldFixture(),
          cache: flags.$1, pending: flags.$2);
      await _flush();
      expect(events.last, isNull);
    }
    reads.emit('owner-a/individual_insights/2026-10-11', checkinGoldFixture());
    await _flush();
    expect(events.last!.insights.insights.single.metric, 'condition');
    reads.emit(
        'owner-a/daily_health_features/2026-10-11', checkinSilverFixture(),
        cache: true);
    await _flush();
    expect(events.last, isNull);
    await sub.cancel();
    await reads.close();
  });
  test(
      'owner change, errors, new source generation and JST date rollover omit stale data',
      () async {
    final reads = _Reads();
    final events = <CurrentCheckinAnalysis?>[];
    final ticks = StreamController<DateTime>();
    final sub = CurrentCheckinInsightsRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11, 2),
            evaluationTicks: ticks.stream)
        .watchCurrent()
        .listen(events.add);
    await _flush();
    reads.emit(
        'owner-a/daily_health_features/2026-10-11', checkinSilverFixture());
    reads.emit('owner-a/individual_insights/2026-10-11', checkinGoldFixture());
    await _flush();
    expect(events.last, isNotNull);
    reads.emit('owner-a/daily_health_features/2026-10-11',
        checkinSilverFixture(generation: '2026-10-11T03:00:00Z'));
    await _flush();
    expect(events.last, isNull);
    reads.emit('owner-a/individual_insights/2026-10-11',
        checkinGoldFixture(generation: '2026-10-11T03:00:00Z'));
    await _flush();
    expect(events.last, isNotNull);
    final index = events.length;
    reads.switchOwner('owner-b');
    await _flush();
    expect(events.last, isNull);
    reads.emit('owner-a/individual_insights/2026-10-11', checkinGoldFixture());
    reads.emit(
        'owner-b/daily_health_features/2026-10-11', checkinSilverFixture());
    reads.emit('owner-b/individual_insights/2026-10-11', checkinGoldFixture());
    await _flush();
    expect(
        events
            .skip(index)
            .whereType<CurrentCheckinAnalysis>()
            .every((e) => e.ownerId == 'owner-b'),
        isTrue);
    reads.channels['owner-b/individual_insights/2026-10-11']!
        .addError(StateError('read error'));
    await _flush();
    expect(events.last, isNull);
    ticks.add(DateTime.utc(2026, 10, 11, 15));
    await _flush();
    expect(events.last, isNull);
    expect(reads.channels.keys,
        contains('owner-b/individual_insights/2026-10-12'));
    await sub.cancel();
    await ticks.close();
    await reads.close();
  });
}
