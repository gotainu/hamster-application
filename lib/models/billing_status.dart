// lib/models/billing_status.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum BillingPlan {
  none,
  paid,
}

enum BillingStatusValue {
  none,
  active,
  trialing,
  pastDue,
  canceled,
  unpaid,
  incomplete,
  unknown,
}

class BillingStatus {
  const BillingStatus({
    required this.plan,
    required this.status,
    required this.provider,
    required this.currentPeriodEnd,
    required this.updatedAt,
  });

  final BillingPlan plan;
  final BillingStatusValue status;
  final String? provider;
  final DateTime? currentPeriodEnd;
  final DateTime? updatedAt;

  bool get isPaid {
    return plan == BillingPlan.paid &&
        (status == BillingStatusValue.active ||
            status == BillingStatusValue.trialing);
  }

  bool get canUsePaidFeatures {
    return isPaid && !isExpired;
  }

  bool get needsPaymentAttention {
    return status == BillingStatusValue.pastDue ||
        status == BillingStatusValue.unpaid;
  }

  bool get isInactive {
    return !canUsePaidFeatures;
  }

  bool get isExpired {
    final end = currentPeriodEnd;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  String get planLabel {
    switch (plan) {
      case BillingPlan.paid:
        return '有料プラン';
      case BillingPlan.none:
        return '未契約';
    }
  }

  String get statusLabel {
    switch (status) {
      case BillingStatusValue.active:
        return '有効';
      case BillingStatusValue.trialing:
        return 'トライアル中';
      case BillingStatusValue.pastDue:
        return '支払い確認中';
      case BillingStatusValue.canceled:
        return 'キャンセル済み';
      case BillingStatusValue.unpaid:
        return '未払い';
      case BillingStatusValue.incomplete:
        return '未完了';
      case BillingStatusValue.none:
        return '未契約';
      case BillingStatusValue.unknown:
        return '不明';
    }
  }

  static BillingStatus empty() {
    return const BillingStatus(
      plan: BillingPlan.none,
      status: BillingStatusValue.none,
      provider: null,
      currentPeriodEnd: null,
      updatedAt: null,
    );
  }

  factory BillingStatus.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return BillingStatus.empty();
    }

    return BillingStatus(
      plan: _parsePlan(data['plan']),
      status: _parseStatus(data['status']),
      provider: data['provider'] as String?,
      currentPeriodEnd: _parseDate(data['currentPeriodEnd']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static BillingPlan _parsePlan(dynamic value) {
    switch (value) {
      case 'paid':
        return BillingPlan.paid;
      case 'none':
      case null:
        return BillingPlan.none;
      default:
        return BillingPlan.none;
    }
  }

  static BillingStatusValue _parseStatus(dynamic value) {
    switch (value) {
      case 'active':
        return BillingStatusValue.active;
      case 'trialing':
        return BillingStatusValue.trialing;
      case 'past_due':
        return BillingStatusValue.pastDue;
      case 'canceled':
        return BillingStatusValue.canceled;
      case 'unpaid':
        return BillingStatusValue.unpaid;
      case 'incomplete':
      case 'incomplete_expired':
        return BillingStatusValue.incomplete;
      case 'none':
      case null:
        return BillingStatusValue.none;
      default:
        return BillingStatusValue.unknown;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }

    return null;
  }
}
