import 'package:cloud_firestore/cloud_firestore.dart';

class InitialTrialAccess {
  const InitialTrialAccess(
      {required this.status,
      required this.endsAt,
      required this.policyVersion,
      required this.aiRequestLimit,
      required this.aiRequestUsed});
  final String? status;
  final DateTime? endsAt;
  final String? policyVersion;
  final int aiRequestLimit;
  final int aiRequestUsed;
  bool get isActive => isActiveAt(DateTime.now());
  bool isActiveAt(DateTime now) =>
      status == 'active' && endsAt != null && now.isBefore(endsAt!);
  factory InitialTrialAccess.empty() => const InitialTrialAccess(
      status: null,
      endsAt: null,
      policyVersion: null,
      aiRequestLimit: 0,
      aiRequestUsed: 0);
  factory InitialTrialAccess.fromMap(Map<String, dynamic>? map) =>
      InitialTrialAccess(
        status: map?['status'] as String?,
        endsAt: (map?['endsAt'] as Timestamp?)?.toDate(),
        policyVersion: map?['policyVersion'] as String?,
        aiRequestLimit: (map?['aiRequestLimit'] as num?)?.toInt() ?? 0,
        aiRequestUsed: (map?['aiRequestUsed'] as num?)?.toInt() ?? 0,
      );
}
