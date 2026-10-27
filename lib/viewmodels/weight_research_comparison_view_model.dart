import 'package:intl/intl.dart';

import '../models/current_weight_analysis.dart';
import '../models/personality_report.dart';
import '../models/weight_research_comparison.dart';

/// Shared wording/rounding only. Baseline statistics and applicability come
/// from their respective source; neither adapter reads or rewrites reports.
class WeightResearchComparisonViewModel {
  const WeightResearchComparisonViewModel(this.comparison);
  final WeightResearchComparison comparison;

  static WeightResearchComparisonViewModel? fromCurrent(
      CurrentWeightAnalysis analysis) {
    if (!analysis.canCompare) return null;
    final reference = analysis.reference!;
    return _valid(WeightResearchComparison(
      individualWeightGrams: analysis.individualWeightGrams!,
      referenceMedianGrams: reference.median,
      referenceP25Grams: reference.p25,
      referenceP75Grams: reference.p75,
    ));
  }

  /// A saved report preserves the server's saved applicability decision.
  static WeightResearchComparisonViewModel? fromSnapshot(
      PersonalityMetricSnapshot snapshot) {
    final population = snapshot.population;
    if (population?.isApplicable != true) return null;
    return _valid(WeightResearchComparison(
      individualWeightGrams: snapshot.median,
      referenceMedianGrams: population!.median!,
      referenceP25Grams: population.p25!,
      referenceP75Grams: population.p75!,
    ));
  }

  static WeightResearchComparisonViewModel? _valid(
          WeightResearchComparison comparison) =>
      comparison.isValid ? WeightResearchComparisonViewModel(comparison) : null;

  double get delta =>
      comparison.individualWeightGrams - comparison.referenceMedianGrams;
  String get individualValue => formatWeight(comparison.individualWeightGrams);
  String get deltaValue => delta == 0 ? '0g' : weightDifferenceLabel(delta);
  String get deltaCaption => delta == 0
      ? '同じ水準'
      : delta < 0
          ? '軽め'
          : '重め';
  String get deltaContext => delta == 0 ? '参考中央値と' : '参考中央値より';
  String get summary =>
      delta == 0 ? '同種の参考中央値と同じ水準' : '同種の参考中央値より$deltaValue$deltaCaption';
  String get discovery => delta == 0 ? summary : '同種の参考中央値より$deltaCaption';

  // Compact plot captions are shared by live analysis and frozen reports.
  static const compactIndividualLabel = 'この子';
  static const compactReferenceLabel = '参考中央値';
  static const compactRangeLabel = '中央50%';

  static const individualLabel = 'この子の普段の体重';
  static const referenceLabel = '同種の研究中央値';
  static const rangeLabel = '研究の中央50%';
  static const referenceNote = '研究集団の参考値で、健康上の正常範囲ではありません。';
}

String formatWeight(double value) => NumberFormat('0.#').format(value);

/// A genuine small difference must never become equality after rounding.
String weightDifferenceLabel(double difference) =>
    difference.abs() < 0.1 ? '0.1g未満' : '${formatWeight(difference.abs())}g';
