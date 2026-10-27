import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/observation_catalog.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';

void main() {
  test('one catalog supplies eight active choices and seven automatic normals',
      () {
    expect(activeObservationItems().map((item) => item.id), [
      'appetite',
      'water',
      'elimination',
      'breathing',
      'movement',
      'eyesNose',
      'coatSkin',
      'other',
    ]);
    expect(
        dailyObservationIds,
        activeObservationItems()
            .where((item) => item.defaultNormal)
            .map((item) => item.id));
    expect(observationCatalogVersion, isNotEmpty);
    expect(observationItem('chewing')?.active, isFalse);
    expect(observationItem('other')?.insightEligible, isFalse);
  });

  test('old IDs and names resolve without losing retired history', () {
    expect(resolveObservationId('poop'), 'elimination');
    expect(resolveObservationId('排泄'), 'elimination');
    expect(resolveObservationId('かじり方'), 'chewing');
    expect(observationLabel('chewing'), 'かじり方');
    expect(resolveObservationId('unknown'), isNull);
    expect(observationLabel('unknown'), 'unknown');
    expect(normalizeObservationIds(['poop', 'elimination', 'chewing']),
        ['elimination', 'chewing']);
  });

  test('addition, order, rename and retirement require only catalog data', () {
    final updated = [
      ...observationCatalog.where((item) => item.id != 'appetite'),
      const ObservationCatalogItem(
          id: 'appetite',
          label: '食欲の様子',
          order: 90,
          active: false,
          insightEligible: true,
          defaultNormal: true,
          aliases: [],
          legacyNames: ['食欲']),
      const ObservationCatalogItem(
          id: 'futureObservation',
          label: '追加項目',
          order: 0,
          active: true,
          insightEligible: true,
          defaultNormal: false,
          aliases: [],
          legacyNames: []),
    ];
    expect(
        activeObservationItems(catalog: updated).first.id, 'futureObservation');
    expect(
        activeObservationItems(catalog: updated)
            .any((item) => item.id == 'appetite'),
        isFalse);
    expect(resolveObservationId('食欲', catalog: updated), 'appetite');
    expect(observationLabel('appetite', catalog: updated), '食欲の様子');
  });

  test('equal order uses the same deterministic ID tie-breaker as Functions',
      () {
    ObservationCatalogItem item(String id) => ObservationCatalogItem(
          id: id,
          label: id,
          order: 0,
          active: true,
          insightEligible: true,
          defaultNormal: false,
          aliases: [],
          legacyNames: [],
        );
    expect(
        activeObservationItems(catalog: [item('a'), item('Z')])
            .map((entry) => entry.id),
        ['Z', 'a']);
  });

  test('alias tags are canonical and automatic normal is not a selected tag',
      () {
    final levels = buildDailyObservationLevels(
        condition: DailyCondition.slightlyConcerned,
        concernTags: ['poop', 'elimination']);
    expect(levels['elimination'], DailyObservationLevel.changed);
    expect(levels.containsKey('poop'), isFalse);
    expect(levels['appetite'], DailyObservationLevel.normal);
    final checkin = DailyCheckin.fromJson({
      'condition': 'slightlyConcerned',
      'concernTags': ['poop', 'elimination', 'chewing'],
      'observationLevels': {'poop': 'changed', 'appetite': 'normal'},
      'schemaVersion': 2,
    }, fallbackDayKey: '2026-10-11');
    expect(checkin.concernTags, ['elimination', 'chewing']);
    expect(checkin.observationLevels['elimination'],
        DailyObservationLevel.changed);
    expect(checkin.observationResponseMode, isNull,
        reason:
            'old schema2 records have no explicit per-item answer provenance');
    expect(checkin.schemaVersion, 2);
  });

  test(
      'new schema2 payload adds catalog provenance without changing old fields',
      () {
    final payload = buildDailyCheckinPayload(
      dayKey: '2026-10-11',
      localDay: DateTime(2026, 10, 11),
      condition: DailyCondition.slightlyConcerned,
      concernTags: ['poop', 'elimination'],
      memo: '  memo  ',
      isNew: true,
    );
    expect(payload['schemaVersion'], 2);
    expect(payload['condition'], 'slightlyConcerned');
    expect(payload['concernTags'], ['elimination']);
    expect(payload['observationCatalogVersion'], observationCatalogVersion);
    expect(payload['observationResponseMode'], 'overall_with_selected_tags');
    expect(payload['observationLevels'], {
      'appetite': 'normal',
      'water': 'normal',
      'elimination': 'changed',
      'breathing': 'normal',
      'movement': 'normal',
      'eyesNose': 'normal',
      'coatSkin': 'normal',
    });
    expect(payload.containsKey('createdAt'), isTrue);
    expect(payload.containsKey('updatedAt'), isTrue);
    expect(payload['memo'], 'memo');
    final update = buildDailyCheckinPayload(
        dayKey: '2026-10-11',
        localDay: DateTime(2026, 10, 11),
        condition: DailyCondition.normal,
        concernTags: [],
        isNew: false);
    expect(update.containsKey('createdAt'), isFalse);
    expect(update.containsKey('answeredObservationIds'), isFalse);
  });
}
