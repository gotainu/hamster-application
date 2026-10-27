import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/daily_health_features.dart';
import 'package:hamster_project/models/reference_weight_cohort.dart';

String fixtureDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Map<String, dynamic> currentWeightFeaturesFixture({
  double median = 100,
  double latest = 100,
  bool ready = true,
  String evaluationDateKey = '2026-10-11',
}) {
  final evaluation = DateTime.parse('${evaluationDateKey}T00:00:00Z');
  final first = fixtureDateKey(evaluation.subtract(const Duration(days: 20)));
  final last = fixtureDateKey(evaluation.subtract(const Duration(days: 7)));
  return {
    'dateKey': evaluationDateKey,
    'schemaVersion': 5,
    'generatedAt': evaluation.add(const Duration(hours: 2)),
    'body': {
      'latestWeightGrams': latest,
      'latestWeightDate': evaluation.subtract(const Duration(days: 1)),
      'daysSinceMeasurement': 1,
      'personalBaseline': {
        'status': ready ? 'ready' : 'learning',
        'method': 'median_mad_ewma_v1',
        'recordCount': ready ? 8 : 5,
        'requiredRecordCount': 7,
        'spanDays': 14,
        'requiredSpanDays': 14,
        'firstDateKey': first,
        'lastDateKey': last,
        'median': median,
        'mad': 0,
        'ewma': median,
        'ewmaAlpha': .3,
        'deviationPct': latest / median * 100 - 100,
        'robustZScore': null,
      },
    },
    'dataQuality': {
      'availableDomains': ['body'],
      'missingDomains': ['activity', 'condition', 'environment'],
      'staleDomains': [],
      'completeness': .25,
    },
  };
}

Map<String, dynamic> currentWeightReferenceFixture({
  String species = 'syrian',
  String version = 'vetcompass_uk_2016_adult_weight_v1',
}) =>
    {
      'cohortId': '${species}_adult_weight',
      'speciesCode': species,
      'metric': 'weight',
      'unit': 'g',
      'sourceType': 'published_research',
      'referenceVersion': version,
      'sourceVersion': 'jsap_13527_table1_published_2022',
      'ageBand': 'adult_over_3_months',
      'adultDefinition': 'strictly_over_3_calendar_months',
      'measurementDefinition':
          'mean_of_each_animals_recorded_weights_over_3_months',
      'median': 133,
      'p25': 100,
      'p75': 160,
      'speciesPopulationN': species == 'campbell' ? 52 : 12197,
      'weightSampleN': null,
      'sourceDOI': '10.1111/jsap.13527',
      'sourceURL': 'https://onlinelibrary.wiley.com/doi/10.1111/jsap.13527',
      'sourceTitle':
          'Demography, disorders and mortality of pet hamsters under primary veterinary care in the United Kingdom in 2016',
      'sourceYear': 2022,
      'studyYear': 2016,
      'population': 'UK VetCompass primary veterinary care, 2016',
      'sampleSizeCaution': species == 'campbell',
      'dataQuality': {
        'weightSampleSizeReported': false,
        'speciesSampleSizeIsNotWeightSampleSize': true,
        'populationIncludesClinicalPatients': true,
        'exactPercentileAvailable': false,
        'healthyReferenceRange': false,
        'comparisonMeasureMismatch': true,
        'smallSpeciesPopulation': species == 'campbell',
      },
      'usableComparisonExpressions': [
        '公開研究の中央50%の範囲より軽め',
        '公開研究の中央50%の範囲内',
        '公開研究の中央50%の範囲より重め',
      ],
      'limitations': [
        '英国の一次診療集団であり、健康上の正常範囲ではありません。',
        '種別総個体数は体重測定有効標本数ではありません。',
        if (species == 'campbell') 'キャンベルの比較は少数集団のため慎重に扱ってください。',
      ],
    };

CurrentWeightAnalysis currentWeightAnalysisFixture({
  double median = 100,
  double latest = 100,
  String? species = 'ゴールデン',
  String? birthdayDateKey = '2026-01-01',
  bool ready = true,
  bool referenceAvailable = true,
  String ownerId = 'synthetic-owner',
  String evaluationDateKey = '2026-10-11',
  Map<String, dynamic>? features,
}) {
  final speciesCode = normalizeWeightReferenceSpecies(species);
  return CurrentWeightAnalysis(
    ownerId: ownerId,
    evaluationDateKey: evaluationDateKey,
    features: DailyHealthFeatures.fromMap(
        features ??
            currentWeightFeaturesFixture(
                median: median,
                latest: latest,
                ready: ready,
                evaluationDateKey: evaluationDateKey),
        fallbackDateKey: evaluationDateKey),
    profile: CurrentWeightProfile(
        rawSpecies: species, birthdayDateKey: birthdayDateKey),
    reference: referenceAvailable && speciesCode != null
        ? ReferenceWeightCohort.fromMap(
            currentWeightReferenceFixture(species: speciesCode),
            expectedSpecies: speciesCode)
        : null,
  );
}
