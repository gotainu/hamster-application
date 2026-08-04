import '../models/weight_record.dart';
import '../models/weight_trend_evaluation.dart';

class WeightTrendEvaluationService {
  /// 医療診断ではなく、アプリ内で変化に気づくための暫定的なUI閾値。
  /// 今後、獣医師監修や実データ検証に合わせてここだけを調整できる。
  final double changedRateThreshold;
  final double cautionRateThreshold;
  final int staleAfterDays;

  const WeightTrendEvaluationService({
    this.changedRateThreshold = 0.05,
    this.cautionRateThreshold = 0.10,
    this.staleAfterDays = 14,
  });

  WeightTrendEvaluation evaluate(
    List<WeightRecord> source, {
    DateTime? now,
  }) {
    final records = [...source]
      ..removeWhere((record) => record.weightGrams <= 0)
      ..sort((a, b) => a.date.compareTo(b.date));

    final reference = (now ?? DateTime.now()).toLocal();

    if (records.isEmpty) {
      return const WeightTrendEvaluation(
        records: [],
        latest: null,
        previous: null,
        previousDifferenceGrams: null,
        previousChangeRate: null,
        periodChangeRate: null,
        daysSinceLatest: null,
        state: WeightTrendState.insufficientData,
        headline: '体重を記録すると変化を確認できます',
        message: '毎日の必須記録ではありません。週1回程度を目安に記録してください。',
      );
    }

    final latest = records.last;
    final previous = records.length >= 2 ? records[records.length - 2] : null;

    final latestDay = DateTime(
      latest.date.year,
      latest.date.month,
      latest.date.day,
    );
    final referenceDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final daysSinceLatest = referenceDay.difference(latestDay).inDays;

    if (previous == null) {
      return WeightTrendEvaluation(
        records: records,
        latest: latest,
        previous: null,
        previousDifferenceGrams: null,
        previousChangeRate: null,
        periodChangeRate: null,
        daysSinceLatest: daysSinceLatest,
        state: WeightTrendState.insufficientData,
        headline: '最初の体重を記録しました',
        message: '次回以降の記録と比較して、個体自身の変化を確認します。',
      );
    }

    final previousDifference = latest.weightGrams - previous.weightGrams;
    final previousRate = previous.weightGrams == 0
        ? null
        : previousDifference / previous.weightGrams;

    final periodBase = records.first;
    final periodRate = periodBase.weightGrams == 0
        ? null
        : (latest.weightGrams - periodBase.weightGrams) /
            periodBase.weightGrams;

    if (daysSinceLatest >= staleAfterDays) {
      return WeightTrendEvaluation(
        records: records,
        latest: latest,
        previous: previous,
        previousDifferenceGrams: previousDifference,
        previousChangeRate: previousRate,
        periodChangeRate: periodRate,
        daysSinceLatest: daysSinceLatest,
        state: WeightTrendState.insufficientData,
        headline: '最新の体重記録から日数が空いています',
        message: '現在の傾向を判断するため、次回の測定をおすすめします。',
      );
    }

    final absolutePreviousRate = previousRate?.abs() ?? 0;
    final absolutePeriodRate = periodRate?.abs() ?? 0;

    if (absolutePreviousRate >= cautionRateThreshold ||
        absolutePeriodRate >= cautionRateThreshold) {
      return WeightTrendEvaluation(
        records: records,
        latest: latest,
        previous: previous,
        previousDifferenceGrams: previousDifference,
        previousChangeRate: previousRate,
        periodChangeRate: periodRate,
        daysSinceLatest: daysSinceLatest,
        state: WeightTrendState.caution,
        headline: '体重に大きめの変化があります',
        message: '測定条件をそろえて再確認し、ほかの体調変化とあわせて確認してください。',
      );
    }

    if (absolutePreviousRate >= changedRateThreshold ||
        absolutePeriodRate >= changedRateThreshold) {
      return WeightTrendEvaluation(
        records: records,
        latest: latest,
        previous: previous,
        previousDifferenceGrams: previousDifference,
        previousChangeRate: previousRate,
        periodChangeRate: periodRate,
        daysSinceLatest: daysSinceLatest,
        state: WeightTrendState.changed,
        headline: '体重に変化があります',
        message: 'すぐに異常と判断せず、同じ条件で次回の記録と比較してください。',
      );
    }

    return WeightTrendEvaluation(
      records: records,
      latest: latest,
      previous: previous,
      previousDifferenceGrams: previousDifference,
      previousChangeRate: previousRate,
      periodChangeRate: periodRate,
      daysSinceLatest: daysSinceLatest,
      state: WeightTrendState.stable,
      headline: '最近の体重は概ね安定しています',
      message: '個体自身の過去記録と比べて、大きな変化は見られません。',
    );
  }
}
