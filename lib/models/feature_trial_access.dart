import 'package:cloud_firestore/cloud_firestore.dart';

enum TrialFeature { ai, changes }

class FeatureTrialAccess {
  const FeatureTrialAccess({
    required this.activatedAt,
    required this.changesTrialEndsAt,
    required this.aiTrialLimit,
    required this.aiTrialUsed,
  });

  final DateTime? activatedAt;
  final DateTime? changesTrialEndsAt;
  final int aiTrialLimit;
  final int aiTrialUsed;

  factory FeatureTrialAccess.empty() => const FeatureTrialAccess(
      activatedAt: null,
      changesTrialEndsAt: null,
      aiTrialLimit: 3,
      aiTrialUsed: 0);

  factory FeatureTrialAccess.fromMap(Map<String, dynamic>? map) {
    DateTime? parse(dynamic value) =>
        value is Timestamp ? value.toDate().toLocal() : null;
    return FeatureTrialAccess(
      activatedAt: parse(map?['activatedAt']),
      changesTrialEndsAt: parse(map?['changesTrialEndsAt']),
      aiTrialLimit: (map?['aiTrialLimit'] as num?)?.toInt() ?? 3,
      aiTrialUsed: (map?['aiTrialUsed'] as num?)?.toInt() ?? 0,
    );
  }

  bool allows(TrialFeature feature, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return switch (feature) {
      TrialFeature.ai => aiTrialUsed < aiTrialLimit,
      TrialFeature.changes =>
        changesTrialEndsAt != null && at.isBefore(changesTrialEndsAt!),
    };
  }

  String remainingLabel(TrialFeature feature) => switch (feature) {
        TrialFeature.ai =>
          '無料あと${(aiTrialLimit - aiTrialUsed).clamp(0, aiTrialLimit)}回',
        TrialFeature.changes => '5日間無料',
      };
}
