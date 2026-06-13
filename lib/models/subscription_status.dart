import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionStatus {
  final String plan;
  final String status;
  final String provider;
  final DateTime? currentPeriodEnd;
  final DateTime? updatedAt;

  const SubscriptionStatus({
    required this.plan,
    required this.status,
    required this.provider,
    required this.currentPeriodEnd,
    required this.updatedAt,
  });

  static const inactive = SubscriptionStatus(
    plan: 'none',
    status: 'inactive',
    provider: 'none',
    currentPeriodEnd: null,
    updatedAt: null,
  );

  bool get isPaidPlan => plan == 'paid';

  bool get isActiveStatus => status == 'active';

  bool get isExpired {
    final end = currentPeriodEnd;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  bool get isEntitled {
    return isPaidPlan && isActiveStatus && !isExpired;
  }

  String get displayPlanText {
    if (isEntitled) return '有料プラン';
    if (isPaidPlan && isExpired) return '有料プラン期限切れ';
    return '未契約';
  }

  String get displayStatusText {
    if (isEntitled) return '有効';
    if (isExpired) return '期限切れ';
    if (status == 'canceled') return '解約済み';
    if (status == 'past_due') return '支払い確認中';
    return '未契約';
  }

  factory SubscriptionStatus.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return SubscriptionStatus.inactive;

    final data = doc.data() ?? {};

    return SubscriptionStatus(
      plan: data['plan'] as String? ?? 'none',
      status: data['status'] as String? ?? 'inactive',
      provider: data['provider'] as String? ?? 'none',
      currentPeriodEnd: _asDateTime(data['currentPeriodEnd']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      return parsed;
    }

    return null;
  }
}
