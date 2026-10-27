import 'package:hamster_project/models/breeding_environment.dart';
import 'package:hamster_project/models/environment_history.dart';
import 'package:hamster_project/services/breeding_environment_repo.dart';

Map<String, dynamic> environmentFixture({int revision = 3}) => {
      'cageWidth': '60',
      'cageDepth': '40',
      'cageHeight': '40',
      'beddingThickness': '10',
      'wheelDiameter': '20',
      'temperatureControl': 'エアコン',
      'accessoryTags': ['隠れ家', '砂場'],
      'revision': revision,
      'environmentHistorySchemaVersion': 1,
    };
EnvironmentHistoryEntry environmentHistoryFixture(
        {int revision = 3,
        String kind = 'change',
        String precision = 'date_only'}) =>
    EnvironmentHistoryEntry.fromMap({
      'revision': revision,
      'kind': kind,
      'targetRevision': kind == 'correction' ? 2 : null,
      'effective': {
        'precision': precision,
        'dateKey': precision == 'date_only' ? '2026-10-10' : null
      },
      'acceptedAt': '2026-10-12T03:00:00.000Z',
      'beforeValueMeaning': kind == 'correction'
          ? 'previous_recorded_input'
          : precision == 'unknown'
              ? 'unknown'
              : 'previous_day_confirmed_environment',
      'values': {
        'beddingThickness': {'value': 25, 'unit': 'cm', 'quality': 'known'},
        if (kind != 'correction')
          'wheelDiameter': {'value': 28, 'unit': 'cm', 'quality': 'known'}
      },
      'changes': {
        'beddingThickness': {
          'before': {
            'value': precision == 'unknown' ? null : 10,
            'unit': 'cm',
            'quality': precision == 'unknown' ? 'unknown' : 'known'
          },
          'after': {'value': 25, 'unit': 'cm', 'quality': 'known'}
        },
        if (kind != 'correction')
          'wheelDiameter': {
            'before': {
              'value': precision == 'unknown' ? null : 20,
              'unit': 'cm',
              'quality': precision == 'unknown' ? 'unknown' : 'known'
            },
            'after': {'value': 28, 'unit': 'cm', 'quality': 'known'}
          },
      },
    });

class EnvironmentTestStore implements EnvironmentStore {
  EnvironmentLoadResult initial = EnvironmentLoadResult(
      environment: BreedingEnvironment.fromMap(environmentFixture()));
  List<EnvironmentHistoryEntry> entries = [environmentHistoryFixture()];
  final saved = <EnvironmentMutation>[];
  int loads = 0, historyReads = 0;
  bool offline = false, failLoad = false;
  Object? saveError;
  final pages = <EnvironmentHistoryPage>[];
  @override
  Future<EnvironmentLoadResult> load() async {
    loads++;
    if (failLoad) throw StateError('synthetic');
    return initial;
  }

  @override
  Future<EnvironmentSaveResult> save(EnvironmentMutation mutation) async {
    saved.add(mutation);
    if (saveError != null) throw saveError!;
    return EnvironmentSaveResult(
        confirmed: !offline,
        mutation: mutation,
        revision: mutation.expectedRevision + 1);
  }

  @override
  Future<EnvironmentHistoryPage> history(
      {int limit = 20, int? beforeRevision}) async {
    historyReads++;
    if (pages.isNotEmpty) return pages.removeAt(0);
    return EnvironmentHistoryPage(entries: entries);
  }
}
