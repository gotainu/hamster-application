import 'package:cloud_firestore/cloud_firestore.dart';
import 'care_action_catalog.dart';

enum CareActionAnswer { performed, notPerformed, unanswered }

extension CareActionAnswerWire on CareActionAnswer {
  String get wire => switch (this) {
        CareActionAnswer.performed => 'performed',
        CareActionAnswer.notPerformed => 'not_performed',
        CareActionAnswer.unanswered => 'unanswered'
      };
  String get label => switch (this) {
        CareActionAnswer.performed => '実施した',
        CareActionAnswer.notPerformed => 'していない',
        CareActionAnswer.unanswered => '未回答'
      };
}

class CareActionResponse {
  const CareActionResponse(
      {this.answer = CareActionAnswer.unanswered,
      this.details = const {},
      this.answerProvenance,
      this.occurredDateKey,
      this.timePrecision = 'unknown',
      this.nonPerformanceScope});
  final CareActionAnswer answer;
  final Map<String, dynamic> details;
  // null preserves an already queued v1 mutation byte-for-byte.
  final String? answerProvenance;
  String get effectiveProvenance => answerProvenance ?? 'legacy_unspecified';
  final String? occurredDateKey;
  final String timePrecision;
  final String? nonPerformanceScope;
  factory CareActionResponse.fromMap(Map<String, dynamic> data) =>
      CareActionResponse(
          answer: switch (data['answer']) {
            'performed' => CareActionAnswer.performed,
            'not_performed' => CareActionAnswer.notPerformed,
            _ => CareActionAnswer.unanswered
          },
          details: data['answer'] == 'performed' && data['details'] is Map
              ? Map<String, dynamic>.from(data['details'])
              : const {},
          answerProvenance: data['answerProvenance'] as String?,
          occurredDateKey: data['occurredDateKey'] as String?,
          timePrecision: data['timePrecision'] as String? ?? 'unknown',
          nonPerformanceScope: data['nonPerformanceScope'] as String?);
  Map<String, dynamic> toPayload() => {
        'answer': answer.wire,
        if (answerProvenance != null) 'answerProvenance': answerProvenance,
        if (answer == CareActionAnswer.performed && details.isNotEmpty)
          'details': details
      };
  CareActionResponse select(CareActionAnswer value) => CareActionResponse(
      answer: value,
      answerProvenance: value == CareActionAnswer.unanswered
          ? 'unanswered'
          : 'item_selection',
      details: value == CareActionAnswer.performed ? details : const {});
}

class DailyCareActions {
  const DailyCareActions(
      {required this.dayKey,
      required this.revision,
      required this.actions,
      this.status = 'active',
      this.mutationId,
      this.acceptedAt,
      this.catalogVersion,
      this.schemaVersion});
  final String dayKey;
  final int revision;
  final String status;
  final String? mutationId;
  final Map<String, CareActionResponse> actions;
  final DateTime? acceptedAt;
  final String? catalogVersion;
  final int? schemaVersion;
  factory DailyCareActions.fromMap(Map<String, dynamic> data,
      {required String dayKey}) {
    final source = data['actions'];
    return DailyCareActions(
        dayKey: dayKey,
        revision: data['revision'] as int? ?? 0,
        status: data['status'] as String? ?? 'active',
        mutationId: data['mutationId'] as String?,
        actions: source is Map
            ? {
                for (final entry in source.entries)
                  if (entry.key is String && entry.value is Map)
                    (careActionItem(entry.key)?.id ?? entry.key):
                        CareActionResponse.fromMap(
                            Map<String, dynamic>.from(entry.value))
              }
            : {},
        acceptedAt: data['acceptedAt'] is Timestamp
            ? (data['acceptedAt'] as Timestamp).toDate()
            : null,
        catalogVersion: data['catalogVersion'] as String?,
        schemaVersion: data['schemaVersion'] as int?);
  }
  bool get hasExplicitAnswer =>
      status == 'active' &&
      actions.values.any((a) => a.answer != CareActionAnswer.unanswered);
}

class CareActionMutation {
  const CareActionMutation(
      {required this.dayKey,
      required this.expectedRevision,
      required this.mutationId,
      required this.actions,
      this.operation = 'save',
      this.inputUiVersion = 'care_actions_input_v1',
      this.inputRoute = 'daily_checkin'});
  final String dayKey;
  final int expectedRevision;
  final String mutationId;
  final String operation;
  final String inputUiVersion;
  final String inputRoute;
  final Map<String, CareActionResponse> actions;
  Map<String, dynamic> toMap() => {
        'dayKey': dayKey,
        'expectedRevision': expectedRevision,
        'mutationId': mutationId,
        'operation': operation,
        'actions': actions.map((k, v) => MapEntry(k, v.toPayload())),
        'inputUiVersion': inputUiVersion,
        'inputRoute': inputRoute
      };
  factory CareActionMutation.fromMap(Map<String, dynamic> data) =>
      CareActionMutation(
          dayKey: data['dayKey'] as String,
          expectedRevision: data['expectedRevision'] as int,
          mutationId: data['mutationId'] as String,
          operation: data['operation'] as String,
          inputUiVersion: data['inputUiVersion'] as String,
          inputRoute: data['inputRoute'] as String,
          actions: (data['actions'] as Map).map((k, v) => MapEntry(k as String,
              CareActionResponse.fromMap(Map<String, dynamic>.from(v)))));
}

enum CareActionSaveState { saved, pendingSync }

class CareActionSaveResult {
  const CareActionSaveResult(
      {required this.state,
      required this.mutation,
      this.revision,
      this.replayed = false,
      this.rewardStatus = 'not_processed',
      this.achievementRecorded = false,
      this.mirroredAwardCount = 0,
      this.confirmationPending = false});
  final CareActionSaveState state;
  final CareActionMutation mutation;
  final int? revision;
  final bool replayed;
  final String rewardStatus;
  final bool achievementRecorded;
  final int mirroredAwardCount;
  final bool confirmationPending;
  bool get confirmed => state == CareActionSaveState.saved;
}

class CareActionLoadResult {
  const CareActionLoadResult(
      {this.record, this.pending, this.serverConfirmed = true});
  final DailyCareActions? record;
  final CareActionMutation? pending;
  final bool serverConfirmed;
}
