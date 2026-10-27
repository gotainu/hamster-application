import 'package:cloud_firestore/cloud_firestore.dart';

enum CareContinuityPhase { empty, active, grace, expired }

/// Server-derived display contract. Clients never decide expiry or award dates.
class CareContinuityState {
  const CareContinuityState(
      {required this.serverDateKey,
      required this.phase,
      required this.todayAchieved,
      required this.periodEarned,
      required this.lifetimeAchievementDays,
      this.periodId,
      this.periodStartedOn,
      this.lastAchievementDateKey,
      this.expiresAt,
      this.policyVersion = 'continuity_v1',
      this.confirmationPending = false});
  final String serverDateKey;
  final CareContinuityPhase phase;
  final bool todayAchieved;
  final int periodEarned;
  final int lifetimeAchievementDays;
  final String? periodId;
  final String? periodStartedOn;
  final String? lastAchievementDateKey;
  final DateTime? expiresAt;
  final String policyVersion;
  final bool confirmationPending;
  factory CareContinuityState.fromMap(Map<String, dynamic> data) {
    final phase = CareContinuityPhase.values
        .firstWhere((value) => value.name == data['phase']);
    final day = data['serverDateKey'];
    if (day is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        data['todayAchieved'] is! bool ||
        data['periodEarned'] is! num ||
        (data['periodEarned'] as num) < 0 ||
        data['lifetimeAchievementDays'] is! num) {
      throw const FormatException('Invalid server continuity state');
    }
    return CareContinuityState(
        serverDateKey: day,
        phase: phase,
        todayAchieved: data['todayAchieved'] as bool,
        periodEarned: (data['periodEarned'] as num).toInt(),
        lifetimeAchievementDays:
            (data['lifetimeAchievementDays'] as num).toInt(),
        periodId: data['periodId'] as String?,
        periodStartedOn: data['periodStartedOn'] as String?,
        lastAchievementDateKey: data['lastAchievementDateKey'] as String?,
        expiresAt: careServerDate(data['expiresAt']),
        policyVersion: data['policyVersion'] as String? ?? 'continuity_v1',
        confirmationPending: data['confirmationPending'] == true);
  }
}

DateTime? careServerDate(Object? value) => value is Timestamp
    ? value.toDate()
    : value is String
        ? DateTime.tryParse(value)
        : null;

class CareContinuityDay {
  const CareContinuityDay(
      {required this.dayKey,
      required this.achieved,
      this.sourceKind,
      this.sourceDateKey,
      this.acceptedAt,
      this.periodId});
  final String dayKey;
  final bool achieved;
  final String? sourceKind;
  final String? sourceDateKey;
  final DateTime? acceptedAt;
  final String? periodId;
  factory CareContinuityDay.fromMap(Map<String, dynamic> data,
          {required String id}) =>
      CareContinuityDay(
          dayKey: data['dayKey'] as String? ?? id,
          achieved: data['achieved'] == true,
          sourceKind: data['sourceKind'] as String?,
          sourceDateKey: data['sourceDateKey'] as String?,
          acceptedAt: careServerDate(data['acceptedAt']),
          periodId: data['periodId'] as String?);
}

/// A saved care record can remain pending only for reward reconciliation.
class CareRewardRetryResult {
  const CareRewardRetryResult(
      {required this.status, this.confirmationPending = false});
  final String status;
  final bool confirmationPending;
  bool get confirmed =>
      !confirmationPending &&
      (status == 'processed' || status == 'not_eligible');
}
