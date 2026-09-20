class StarRewardsProgress {
  /// 現在保有している星。将来の失効ルールが有効になっても、ここだけを
  /// 変更するため、達成履歴は失われない。
  final int total;
  final int lifetimeEarned;

  const StarRewardsProgress({
    required this.total,
    int? lifetimeEarned,
  }) : lifetimeEarned = lifetimeEarned ?? total;

  factory StarRewardsProgress.fromJson(Map<String, dynamic> json) {
    int nonNegativeValue(Object? raw) {
      final value = raw is num ? raw.toInt() : 0;
      return value < 0 ? 0 : value;
    }

    final total = nonNegativeValue(json['balance'] ?? json['total']);
    return StarRewardsProgress(
      total: total,
      lifetimeEarned: nonNegativeValue(json['lifetimeEarned'] ?? total),
    );
  }
}
