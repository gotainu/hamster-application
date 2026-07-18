import 'weight_record.dart';

enum WeightTrendState {
  insufficientData,
  stable,
  changed,
  caution,
}

class WeightTrendEvaluation {
  final List<WeightRecord> records;
  final WeightRecord? latest;
  final WeightRecord? previous;
  final double? previousDifferenceGrams;
  final double? previousChangeRate;
  final double? periodChangeRate;
  final int? daysSinceLatest;
  final WeightTrendState state;
  final String headline;
  final String message;

  const WeightTrendEvaluation({
    required this.records,
    required this.latest,
    required this.previous,
    required this.previousDifferenceGrams,
    required this.previousChangeRate,
    required this.periodChangeRate,
    required this.daysSinceLatest,
    required this.state,
    required this.headline,
    required this.message,
  });

  bool get hasData => latest != null;
  bool get hasEnoughForTrend => records.length >= 2;

  bool get shouldEmphasize => state == WeightTrendState.caution;
}
