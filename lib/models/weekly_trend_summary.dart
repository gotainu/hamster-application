enum TrendDirection {
  improving,
  worsening,
  stable,
  unknown,
}

class WeeklyTrendSummary {
  final String deltaText;
  final String directionText;
  final String summaryText;
  final TrendDirection direction;

  const WeeklyTrendSummary({
    required this.deltaText,
    required this.directionText,
    required this.summaryText,
    required this.direction,
  });

  factory WeeklyTrendSummary.insufficientData() {
    return const WeeklyTrendSummary(
      deltaText: '比較データがまだ少ないです',
      directionText: '比較中',
      summaryText: '履歴が増えると先週との変化を表示できます',
      direction: TrendDirection.unknown,
    );
  }
}
