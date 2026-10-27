import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/breeding_environment.dart';
import 'package:hamster_project/models/environment_history.dart';
import 'package:hamster_project/viewmodels/environment_history_view_model.dart';

void main() {
  test(
      'legacy fields are strings; missing dimensions and temperature stay unknown on save',
      () {
    final env =
        BreedingEnvironment.fromMap({'cageWidth': 60, 'wheelDiameter': '20'});
    expect(env.cageWidth, '60');
    expect(env.cageHeight, isNull);
    expect(env.toMapForSave()['temperatureControl'], isNull);
    expect(env.revision, 0);
  });
  test('displayed today is not a confirmed effective date', () {
    final draft = EnvironmentEffectiveDraft(DateTime(2026, 10, 12));
    expect(draft.confirmed, isFalse);
    expect(() => draft.toEffective(), throwsStateError);
    draft.confirmDate(DateTime(2026, 10, 10));
    expect(draft.toEffective().toMap(),
        {'precision': 'date_only', 'dateKey': '2026-10-10'});
    draft.confirmUnknown();
    expect(draft.toEffective().toMap(), {'precision': 'unknown'});
  });
  test(
      'history displays date precision, correction, and changes, not secret fields',
      () {
    final entry = EnvironmentHistoryEntry.fromMap({
      'revision': 3,
      'kind': 'correction',
      'targetRevision': 2,
      'effective': {'precision': 'date_only', 'dateKey': '2026-10-10'},
      'acceptedAt': '2026-10-12T03:00:00.000Z',
      'changes': {
        'beddingThickness': {
          'before': {'value': 10, 'unit': 'cm', 'quality': 'known'},
          'after': {'value': 25, 'unit': 'cm', 'quality': 'known'},
        }
      },
    });
    final view = EnvironmentHistoryViewModel(entry);
    expect(view.title, '2026/10/10 · 入力の訂正');
    expect(view.changeLines, ['床材の深さ　10 cm → 25 cm']);
    expect(entry.targetRevision, 2);
  });
  test('unknown and invalid values are not rendered as zero', () {
    expect(
        EnvironmentHistoryViewModel.valueText(
            const EnvironmentHistoryValue(null, 'cm', 'unknown')),
        '不明');
    expect(
        EnvironmentHistoryViewModel.valueText(
            const EnvironmentHistoryValue(null, 'cm', 'invalid')),
        '確認が必要');
  });
  test(
      'malformed legacy tags stay unknown and temporal read retains both clocks',
      () {
    final legacy = BreedingEnvironment.fromMap(
        {'accessoryTags': '古い文字列', 'wheelDiameter': 'Infinity'});
    expect(legacy.accessoryTagsRecorded, isFalse);
    expect(legacy.wheelDiameterAsDouble(), isNull);
    final result = EnvironmentAtResult.fromMap({
      'observedAt': '2026-10-11T00:00:00.000Z',
      'knowledgeCutoff': '2026-10-11T00:00:00.000Z',
      'values': {},
      'quality': {
        'unknownFields': ['wheelDiameter'],
        'ambiguousFields': [],
        'reasons': ['not_known_by_cutoff']
      },
      'evidenceRevisionIds': ['00000001']
    });
    expect(result.observedAt, DateTime.utc(2026, 10, 11));
    expect(result.knowledgeCutoff, DateTime.utc(2026, 10, 11));
    expect(result.unknownFields, ['wheelDiameter']);
    expect(result.evidenceRevisionIds, ['00000001']);
  });
  test('mutation roundtrip retains exact precision and expected revision', () {
    final mutation = EnvironmentMutation(
      mutationId: '00000000-0000-4000-8000-000000000001',
      expectedRevision: 2,
      operation: EnvironmentOperation.correction,
      targetRevision: 1,
      values: const {'wheelDiameter': '28'},
      effective:
          EnvironmentEffective.instant(DateTime.utc(2026, 10, 10, 4, 30)),
    );
    expect(EnvironmentMutation.fromMap(mutation.toMap()).toMap(),
        mutation.toMap());
    expect(mutation.toMap()['effective'],
        {'precision': 'instant', 'occurredAt': '2026-10-10T04:30:00.000Z'});
  });
}
