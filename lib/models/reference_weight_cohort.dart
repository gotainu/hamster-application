/// The published population context is independent of any immutable user report.
/// It is never a healthy range or an exact percentile distribution.
class ReferenceWeightCohort {
  final String cohortId;
  final String speciesCode;
  final String referenceVersion;
  final String sourceVersion;
  final double median;
  final double p25;
  final double p75;
  final String ageBand;
  final String adultDefinition;
  final String measurementDefinition;
  final String sourceDoi;
  final String sourceUrl;
  final String sourceTitle;
  final String population;
  final int sourceYear;
  final int studyYear;
  final int speciesPopulationN;
  final int? weightSampleN;
  final bool sampleSizeCaution;
  final List<String> limitations;
  final List<String> usableComparisonExpressions;

  const ReferenceWeightCohort._({
    required this.cohortId,
    required this.speciesCode,
    required this.referenceVersion,
    required this.sourceVersion,
    required this.median,
    required this.p25,
    required this.p75,
    required this.ageBand,
    required this.adultDefinition,
    required this.measurementDefinition,
    required this.sourceDoi,
    required this.sourceUrl,
    required this.sourceTitle,
    required this.population,
    required this.sourceYear,
    required this.studyYear,
    required this.speciesPopulationN,
    required this.weightSampleN,
    required this.sampleSizeCaution,
    required this.limitations,
    required this.usableComparisonExpressions,
  });

  /// Mirrors the currently supported server research contract. A different
  /// reference definition needs an explicit eligibility implementation first.
  factory ReferenceWeightCohort.fromMap(Map<String, dynamic> data,
      {required String expectedSpecies, String? expectedVersion}) {
    final median = _positive(data['median']);
    final lower = _positive(data['p25']);
    final upper = _positive(data['p75']);
    final quality = data['dataQuality'];
    final version = data['referenceVersion'];
    final sourceVersion = data['sourceVersion'];
    final limitations = _strings(data['limitations']);
    final expressions = _strings(data['usableComparisonExpressions']);
    final sourceYear = _positiveInt(data['sourceYear']);
    final studyYear = _positiveInt(data['studyYear']);
    final speciesN = _positiveInt(data['speciesPopulationN']);
    final uri = data['sourceURL'] is String
        ? Uri.tryParse(data['sourceURL'] as String)
        : null;
    const supportedExpressions = {
      '公開研究の中央50%の範囲より軽め',
      '公開研究の中央50%の範囲内',
      '公開研究の中央50%の範囲より重め',
    };
    if (normalizeWeightReferenceSpecies(expectedSpecies) != expectedSpecies ||
        data['speciesCode'] != expectedSpecies ||
        data['cohortId'] != '${expectedSpecies}_adult_weight' ||
        data['metric'] != 'weight' ||
        data['unit'] != 'g' ||
        data['sourceType'] != 'published_research' ||
        data['ageBand'] != 'adult_over_3_months' ||
        data['adultDefinition'] != 'strictly_over_3_calendar_months' ||
        data['measurementDefinition'] !=
            'mean_of_each_animals_recorded_weights_over_3_months' ||
        median == null ||
        lower == null ||
        upper == null ||
        lower > median ||
        median > upper ||
        !isWeightReferenceVersionId(version) ||
        !isWeightReferenceVersionId(sourceVersion) ||
        (expectedVersion != null && version != expectedVersion) ||
        data['sourceDOI'] != '10.1111/jsap.13527' ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !_hasText(data['sourceTitle']) ||
        !_hasText(data['population']) ||
        sourceYear == null ||
        studyYear == null ||
        speciesN == null ||
        !data.containsKey('weightSampleN') ||
        data['weightSampleN'] != null ||
        data['sampleSizeCaution'] is! bool ||
        limitations == null ||
        limitations.isEmpty ||
        expressions == null ||
        expressions.length != supportedExpressions.length ||
        !supportedExpressions.every(expressions.contains) ||
        quality is! Map ||
        quality['weightSampleSizeReported'] != false ||
        quality['speciesSampleSizeIsNotWeightSampleSize'] != true ||
        quality['populationIncludesClinicalPatients'] != true ||
        quality['exactPercentileAvailable'] != false ||
        quality['healthyReferenceRange'] != false ||
        quality['comparisonMeasureMismatch'] != true ||
        quality['smallSpeciesPopulation'] is! bool ||
        (expectedSpecies == 'campbell' &&
            (data['sampleSizeCaution'] != true ||
                quality['smallSpeciesPopulation'] != true))) {
      throw const FormatException('Unsupported weight reference definition');
    }
    return ReferenceWeightCohort._(
      cohortId: data['cohortId'] as String,
      speciesCode: expectedSpecies,
      referenceVersion: version as String,
      sourceVersion: sourceVersion as String,
      median: median,
      p25: lower,
      p75: upper,
      ageBand: data['ageBand'] as String,
      adultDefinition: data['adultDefinition'] as String,
      measurementDefinition: data['measurementDefinition'] as String,
      sourceDoi: data['sourceDOI'] as String,
      sourceUrl: data['sourceURL'] as String,
      sourceTitle: data['sourceTitle'] as String,
      population: data['population'] as String,
      sourceYear: sourceYear,
      studyYear: studyYear,
      speciesPopulationN: speciesN,
      weightSampleN: null,
      sampleSizeCaution: data['sampleSizeCaution'] as bool,
      limitations: List.unmodifiable(limitations),
      usableComparisonExpressions: List.unmodifiable(expressions),
    );
  }
}

bool isWeightReferenceVersionId(Object? value) =>
    value is String && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value);

/// Unknown or missing identities stay unknown. In particular, the legacy pet
/// profile's default species is not used for research eligibility.
String? normalizeWeightReferenceSpecies(String? raw) {
  if (raw == null) return null;
  // Equivalent ASCII-width normalization for persisted Japanese species labels
  // and scientific names; do not infer a species from a partial/unknown name.
  final widthNormalized = String.fromCharCodes(
      raw.runes.map((rune) => rune >= 0xff01 && rune <= 0xff5e
          ? rune - 0xfee0
          : rune == 0x3000
              ? 32
              : rune));
  final key =
      widthNormalized.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  const aliases = <String, String>{
    'syrian': 'syrian',
    'シリアン': 'syrian',
    'シリアンハムスター': 'syrian',
    'ゴールデン': 'syrian',
    'ゴールデンハムスター': 'syrian',
    'キンクマ': 'syrian',
    'syrianhamster': 'syrian',
    'goldenhamster': 'syrian',
    'mesocricetusauratus': 'syrian',
    'djungarian': 'djungarian',
    'ジャンガリアン': 'djungarian',
    'ジャンガリアンハムスター': 'djungarian',
    'ウィンターホワイト': 'djungarian',
    'winterwhitedwarfhamster': 'djungarian',
    'phodopussungorus': 'djungarian',
    'roborovski': 'roborovski',
    'ロボロフスキー': 'roborovski',
    'ロボロフスキーハムスター': 'roborovski',
    'phodopusroborovskii': 'roborovski',
    'chinese': 'chinese',
    'チャイニーズ': 'chinese',
    'チャイニーズハムスター': 'chinese',
    'chinesedwarfhamster': 'chinese',
    'cricetulusgriseus': 'chinese',
    'campbell': 'campbell',
    'キャンベル': 'campbell',
    'キャンベルハムスター': 'campbell',
    'campbellrussianhamster': 'campbell',
    'phodopuscampbelli': 'campbell',
  };
  return aliases[key];
}

bool _hasText(Object? value) => value is String && value.trim().isNotEmpty;
double? _positive(Object? value) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : null;
int? _positiveInt(Object? value) => value is num &&
        value.isFinite &&
        value > 0 &&
        value == value.roundToDouble()
    ? value.toInt()
    : null;
List<String>? _strings(Object? value) =>
    value is List && value.every(_hasText) ? value.cast<String>() : null;
