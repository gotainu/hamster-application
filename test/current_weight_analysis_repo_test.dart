import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';

import 'current_weight_analysis_test_support.dart';

const _version = 'vetcompass_uk_2016_adult_weight_v1';
const _cohort = 'syrian_adult_weight';
const _day = '2026-10-11';

class _FakeReads implements CurrentWeightReadSource {
  String? owner;
  final owners = StreamController<String?>.broadcast();
  final documents = <String, StreamController<WeightAnalysisDocument>>{};
  final watchedPaths = <String>[];
  _FakeReads(this.owner);
  @override
  String? get currentOwnerId => owner;
  @override
  Stream<String?> watchOwnerId() async* {
    yield owner;
    yield* owners.stream;
  }

  StreamController<WeightAnalysisDocument> channel(String path) =>
      documents.putIfAbsent(
          path, () => StreamController<WeightAnalysisDocument>.broadcast());
  Stream<WeightAnalysisDocument> watch(String path) {
    watchedPaths.add(path);
    return channel(path).stream;
  }

  @override
  Stream<WeightAnalysisDocument> watchUserDocument(
          String ownerId, String collection, String documentId) =>
      watch('users/$ownerId/$collection/$documentId');
  @override
  Stream<WeightAnalysisDocument> watchReferenceDocument(String cohortId,
          {String? versionId}) =>
      watch(
          'reference_cohorts/$cohortId${versionId == null ? '' : '/versions/$versionId'}');
  void switchOwner(String? value) {
    owner = value;
    owners.add(value);
  }

  void emit(String path, Map<String, dynamic>? data,
          {bool cache = false, bool pending = false}) =>
      channel(path).add(WeightAnalysisDocument(
          exists: data != null,
          data: data,
          isFromCache: cache,
          hasPendingWrites: pending));
  Future<void> close() async {
    await owners.close();
    for (final channel in documents.values) {
      await channel.close();
    }
  }
}

Future<void> _flush() => pumpEventQueue(times: 5);
void _user(_FakeReads source, String owner,
    {String day = _day,
    Map<String, dynamic>? features,
    String? species = 'ゴールデン'}) {
  source.emit('users/$owner/daily_health_features/$day',
      features ?? currentWeightFeaturesFixture(evaluationDateKey: day));
  source.emit('users/$owner/pet_profiles/main_pet',
      {'species': species, 'birthday': '2026-01-01', 'memo': 'not copied'});
}

Map<String, dynamic> _pointer(String version) => {
      'speciesCode': 'syrian',
      'metric': 'weight',
      'unit': 'g',
      'sourceType': 'published_research',
      'currentReferenceVersion': version,
    };
Future<void> _reference(_FakeReads source, {String version = _version}) async {
  source.emit('reference_cohorts/$_cohort', _pointer(version));
  await _flush();
  source.emit('reference_cohorts/$_cohort/versions/$version',
      currentWeightReferenceFixture(version: version));
  await _flush();
}

void main() {
  test(
      'only server-confirmed current Silver/profile/version reaches comparison',
      () async {
    final reads = _FakeReads('owner-a');
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11, 2),
            evaluationTicks: const Stream.empty())
        .watchCurrent()
        .listen(events.add);
    await _flush();
    reads.emit('users/owner-a/daily_health_features/$_day', null, cache: true);
    reads.emit('users/owner-a/pet_profiles/main_pet',
        {'species': 'ゴールデン', 'birthday': '2026-01-01'});
    await _flush();
    expect(events.whereType<CurrentWeightAnalysis>(), isEmpty);
    _user(reads, 'owner-a');
    await _flush();
    reads.emit('reference_cohorts/$_cohort', _pointer(_version), cache: true);
    await _flush();
    expect(events.last, isNull);
    reads.emit('reference_cohorts/$_cohort', _pointer(_version));
    await _flush();
    reads.emit('reference_cohorts/$_cohort/versions/$_version',
        currentWeightReferenceFixture(),
        pending: true);
    await _flush();
    expect(events.last, isNull);
    reads.emit('reference_cohorts/$_cohort/versions/$_version',
        currentWeightReferenceFixture());
    await _flush();
    expect(events.last!.canCompare, isTrue);
    expect(events.last!.individualWeightGrams, 100);
    expect(events.last!.reference!.referenceVersion, _version);
    expect(
        reads.watchedPaths,
        containsAll([
          'users/owner-a/daily_health_features/$_day',
          'users/owner-a/pet_profiles/main_pet',
          'reference_cohorts/$_cohort',
          'reference_cohorts/$_cohort/versions/$_version',
        ]));
    expect(
        reads.watchedPaths.any((path) =>
            path.contains('personality_reports') ||
            path.contains('report_pointers') ||
            path.contains('weight_records')),
        isFalse);
    await subscription.cancel();
    await reads.close();
  });

  test('account switching clears old identity and discards late old values',
      () async {
    final reads = _FakeReads('owner-a');
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11),
            evaluationTicks: const Stream.empty())
        .watchCurrent()
        .listen(events.add);
    await _flush();
    _user(reads, 'owner-a');
    await _flush();
    await _reference(reads);
    expect(events.last!.ownerId, 'owner-a');
    final switchIndex = events.length;
    reads.switchOwner('owner-b');
    reads.emit('users/owner-a/daily_health_features/$_day',
        currentWeightFeaturesFixture(median: 220));
    await _flush();
    expect(events.last, isNull);
    _user(reads, 'owner-b');
    await _flush();
    await _reference(reads);
    expect(events.last!.ownerId, 'owner-b');
    expect(
        events
            .skip(switchIndex)
            .whereType<CurrentWeightAnalysis>()
            .every((value) => value.ownerId == 'owner-b'),
        isTrue);
    reads.switchOwner(null);
    await _flush();
    expect(events.last, isNull);
    await subscription.cancel();
    await reads.close();
  });

  test(
      'new research pointer clears old cohort until matching version is confirmed',
      () async {
    final reads = _FakeReads('owner');
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11),
            evaluationTicks: const Stream.empty())
        .watchCurrent()
        .listen(events.add);
    await _flush();
    _user(reads, 'owner');
    await _flush();
    await _reference(reads);
    expect(events.last!.canCompare, isTrue);
    reads.emit('reference_cohorts/$_cohort', _pointer('research_v2'));
    await _flush();
    expect(events.last, isNull);
    reads.emit('reference_cohorts/$_cohort/versions/$_version',
        currentWeightReferenceFixture());
    await _flush();
    expect(events.last, isNull);
    reads.emit('reference_cohorts/$_cohort/versions/research_v2',
        currentWeightReferenceFixture());
    await _flush();
    expect(events.last!.canCompare, isFalse); // version mismatch
    reads.emit('reference_cohorts/$_cohort/versions/research_v2',
        currentWeightReferenceFixture(version: 'research_v2'));
    await _flush();
    expect(events.last!.reference!.referenceVersion, 'research_v2');
    expect(events.last!.canCompare, isTrue);
    await subscription.cancel();
    await reads.close();
  });

  test(
      'missing reference, unknown species, learning and read error safely omit',
      () async {
    final reads = _FakeReads('owner');
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11),
            evaluationTicks: const Stream.empty())
        .watchCurrent()
        .listen(events.add);
    await _flush();
    _user(reads, 'owner', features: currentWeightFeaturesFixture(ready: false));
    await _flush();
    expect(events.last!.omissionReason, 'baseline_learning');
    expect(
        reads.watchedPaths.any((path) => path.startsWith('reference_cohorts')),
        isFalse);
    _user(reads, 'owner', species: '不明');
    await _flush();
    expect(events.last!.omissionReason, 'unknown_species');
    _user(reads, 'owner');
    await _flush();
    reads.emit('reference_cohorts/$_cohort', null);
    await _flush();
    expect(events.last!.omissionReason, 'reference_unavailable');
    reads
        .channel('reference_cohorts/$_cohort')
        .addError(StateError('permission-denied'));
    await _flush();
    expect(events.last, isNull);
    await _reference(reads);
    expect(events.last!.canCompare, isTrue);
    await subscription.cancel();
    await reads.close();
  });

  test('JST midnight switches exact day and never falls back to stale Silver',
      () async {
    final reads = _FakeReads('owner');
    final ticks = StreamController<DateTime>();
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 10, 14, 59),
            evaluationTicks: ticks.stream)
        .watchCurrent()
        .listen(events.add);
    await _flush();
    _user(reads, 'owner', day: '2026-10-10');
    await _flush();
    await _reference(reads);
    expect(events.last!.evaluationDateKey, '2026-10-10');
    ticks.add(DateTime.utc(2026, 10, 10, 15));
    await _flush();
    expect(events.last, isNull);
    expect(reads.watchedPaths,
        contains('users/owner/daily_health_features/2026-10-11'));
    reads.emit('users/owner/daily_health_features/2026-10-11', null);
    reads.emit('users/owner/pet_profiles/main_pet',
        {'species': 'ゴールデン', 'birthday': '2026-01-01'});
    await _flush();
    expect(events.last, isNull);
    _user(reads, 'owner');
    await _flush();
    await _reference(reads);
    expect(events.last!.evaluationDateKey, '2026-10-11');
    expect(events.last!.canCompare, isTrue);
    await subscription.cancel();
    await ticks.close();
    await reads.close();
  });

  test(
      'wrong document date, cached profile and invalid Silver do not authorize comparison',
      () async {
    final reads = _FakeReads('owner');
    final events = <CurrentWeightAnalysis?>[];
    final subscription = CurrentWeightAnalysisRepo(
            source: reads,
            now: () => DateTime.utc(2026, 10, 11),
            evaluationTicks: const Stream.empty())
        .watchCurrent()
        .listen(events.add);
    await _flush();
    reads.emit('users/owner/daily_health_features/$_day',
        currentWeightFeaturesFixture(evaluationDateKey: '2026-10-10'));
    reads.emit('users/owner/pet_profiles/main_pet',
        {'species': 'ゴールデン', 'birthday': '2026-01-01'});
    await _flush();
    expect(events.last!.omissionReason, 'current_silver_unavailable');
    reads.emit('users/owner/daily_health_features/$_day',
        currentWeightFeaturesFixture());
    reads.emit('users/owner/pet_profiles/main_pet',
        {'species': 'ゴールデン', 'birthday': '2026-01-01'},
        cache: true);
    await _flush();
    expect(events.last, isNull);
    reads.emit('users/owner/pet_profiles/main_pet',
        {'species': 'ゴールデン', 'birthday': '2026-01-01'});
    reads.emit('users/owner/daily_health_features/$_day',
        currentWeightFeaturesFixture()..remove('dateKey'));
    await _flush();
    expect(events.last, isNull); // parser fallback cannot establish identity
    reads.emit('users/owner/daily_health_features/$_day',
        currentWeightFeaturesFixture()..['schemaVersion'] = '5');
    await _flush();
    expect(events.last, isNull); // coercion cannot establish server schema
    await subscription.cancel();
    await reads.close();
  });
  group('Phase 2 confirmed individual analysis without research', () {
    CurrentWeightAnalysisRepo repo(_FakeReads reads) =>
        CurrentWeightAnalysisRepo(
          source: reads,
          now: () => DateTime.utc(2026, 10, 11),
          evaluationTicks: const Stream.empty(),
          includeIndividualAnalysisWithoutReference: true,
        );

    test('pending/cache research leaves confirmed baseline, never a comparison',
        () async {
      final reads = _FakeReads('owner');
      final events = <CurrentWeightAnalysis?>[];
      final subscription = repo(reads).watchCurrent().listen(events.add);
      await _flush();
      _user(reads, 'owner');
      await _flush();
      expect(events.last!.baseline.median, 100);
      expect(events.last!.reference, isNull);
      expect(events.last!.canCompare, isFalse);
      reads.emit('reference_cohorts/$_cohort', _pointer(_version), cache: true);
      await _flush();
      expect(events.last!.baseline.median, 100);
      expect(events.last!.reference, isNull);
      reads.emit('reference_cohorts/$_cohort', _pointer(_version));
      await _flush();
      reads.emit('reference_cohorts/$_cohort/versions/$_version',
          currentWeightReferenceFixture(),
          pending: true);
      await _flush();
      expect(events.last!.reference, isNull);
      reads.emit('reference_cohorts/$_cohort/versions/$_version',
          currentWeightReferenceFixture());
      await _flush();
      expect(events.last!.canCompare, isTrue);
      await subscription.cancel();
      await reads.close();
    });

    test('cached/error root removes old reference and recovers exact version',
        () async {
      final reads = _FakeReads('owner');
      final events = <CurrentWeightAnalysis?>[];
      final subscription = repo(reads).watchCurrent().listen(events.add);
      await _flush();
      _user(reads, 'owner');
      await _flush();
      await _reference(reads);
      expect(events.last!.canCompare, isTrue);
      reads.emit('reference_cohorts/$_cohort', _pointer(_version), cache: true);
      await _flush();
      expect(events.last!.baseline.median, 100);
      expect(events.last!.reference, isNull);
      reads.emit('reference_cohorts/$_cohort/versions/$_version',
          currentWeightReferenceFixture());
      await _flush();
      expect(events.last!.reference, isNull); // old cancelled version
      await _reference(reads);
      expect(events.last!.canCompare, isTrue);
      reads
          .channel('reference_cohorts/$_cohort')
          .addError(StateError('permission-denied'));
      await _flush();
      expect(events.last!.baseline.median, 100);
      expect(events.last!.reference, isNull);
      await _reference(reads);
      expect(events.last!.canCompare, isTrue);
      await subscription.cancel();
      await reads.close();
    });

    test('version switch/cache/error never keeps a previously confirmed cohort',
        () async {
      final reads = _FakeReads('owner');
      final events = <CurrentWeightAnalysis?>[];
      final subscription = repo(reads).watchCurrent().listen(events.add);
      await _flush();
      _user(reads, 'owner');
      await _flush();
      await _reference(reads);
      reads.emit('reference_cohorts/$_cohort/versions/$_version',
          currentWeightReferenceFixture(),
          cache: true);
      await _flush();
      expect(events.last!.reference, isNull);
      reads.emit('reference_cohorts/$_cohort', _pointer('research_v2'));
      await _flush();
      expect(events.last!.reference, isNull);
      reads
          .channel('reference_cohorts/$_cohort/versions/research_v2')
          .addError(StateError('unavailable'));
      await _flush();
      expect(events.last!.baseline.median, 100);
      expect(events.last!.reference, isNull);
      reads.emit('reference_cohorts/$_cohort/versions/$_version',
          currentWeightReferenceFixture());
      await _flush();
      expect(events.last!.reference, isNull);
      reads.emit('reference_cohorts/$_cohort/versions/research_v2',
          currentWeightReferenceFixture(version: 'research_v2'));
      await _flush();
      expect(events.last!.reference!.referenceVersion, 'research_v2');
      await subscription.cancel();
      await reads.close();
    });

    test('opt-in never bypasses Silver/profile confirmation or owner identity',
        () async {
      final reads = _FakeReads('owner-a');
      final events = <CurrentWeightAnalysis?>[];
      final subscription = repo(reads).watchCurrent().listen(events.add);
      await _flush();
      _user(reads, 'owner-a');
      await _flush();
      expect(events.last!.ownerId, 'owner-a');
      reads.emit('users/owner-a/daily_health_features/$_day',
          currentWeightFeaturesFixture(),
          cache: true);
      await _flush();
      expect(events.last, isNull);
      _user(reads, 'owner-a');
      reads.emit('users/owner-a/pet_profiles/main_pet',
          {'species': 'ゴールデン', 'birthday': '2026-01-01'},
          pending: true);
      await _flush();
      expect(events.last, isNull);
      _user(reads, 'owner-a');
      await _flush();
      reads
          .channel('users/owner-a/daily_health_features/$_day')
          .addError(StateError('unavailable'));
      await _flush();
      expect(events.last, isNull);
      final switchIndex = events.length;
      reads.switchOwner('owner-b');
      await _flush();
      expect(events.last, isNull);
      _user(reads, 'owner-a',
          features: currentWeightFeaturesFixture(median: 220));
      _user(reads, 'owner-b');
      await _flush();
      expect(events.last!.ownerId, 'owner-b');
      expect(
          events
              .skip(switchIndex)
              .whereType<CurrentWeightAnalysis>()
              .every((value) => value.ownerId == 'owner-b'),
          isTrue);
      reads.switchOwner(null);
      await _flush();
      expect(events.last, isNull);
      await subscription.cancel();
      await reads.close();
    });
  });
}
