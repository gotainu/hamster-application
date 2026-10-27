import 'package:uuid/uuid.dart';
import '../models/daily_observation_history.dart';
import '../models/observation_catalog.dart';
import '../services/daily_checkin_repo.dart';

/// Confirmation and intent are separate from the answer's value.
class ObservationInputViewModel {
  ObservationInputViewModel({required this.date, required this.dayKey});
  final DateTime date;
  final String dayKey;
  ObservationLoadResult state = const ObservationLoadResult();
  ObservationOperation? operation;
  ObservationTiming? timing;
  String get confirmedDateLabel => '${date.month}/${date.day} · 日付のみ';
  String get dateAccessibilityLabel =>
      '${date.year}年${date.month}月${date.day}日の観察、時刻は未確認';
  bool get hasExisting => state.current != null;
  bool get canSave =>
      state.serverConfirmed &&
      state.hasProfile &&
      state.pending == null &&
      operation != null &&
      timing != null;
  void load(ObservationLoadResult value) {
    state = value;
    operation =
        value.current == null ? ObservationOperation.newObservation : null;
    timing = null;
  }

  void chooseOperation(ObservationOperation value) {
    operation = value;
    timing =
        value == ObservationOperation.correction ? state.current?.timing : null;
  }

  void confirmNow(DateTime time) =>
      timing = ObservationTiming.instant(time, nowConfirmed: true);
  void confirmTime(DateTime time) => timing = ObservationTiming.instant(time);
  void confirmDate() => timing = ObservationTiming.dateOnly(dayKey);
  void confirmUnknown() => timing = const ObservationTiming.unknown();
  ObservationMutation mutation(
      {required DailyCondition condition,
      required List<String> tags,
      required String memo,
      bool cancel = false}) {
    if (!cancel && !canSave) {
      throw StateError('observation_confirmation_required');
    }
    final current = state.current;
    return ObservationMutation(
        mutationId: const Uuid().v4(),
        dayKey: dayKey,
        date: date,
        expectedRevision: state.revision,
        subjectId: state.subjectId,
        operation: cancel ? ObservationOperation.cancel : operation!,
        targetEventId: cancel || operation == ObservationOperation.correction
            ? current?.eventId
            : null,
        targetRevision: cancel || operation == ObservationOperation.correction
            ? current?.eventRevision ?? 0
            : null,
        timing: timing ?? const ObservationTiming.unknown(),
        condition: condition.name,
        concernTags: normalizeObservationIds(tags),
        memo: memo.trim(),
        catalogVersion: observationCatalogVersion);
  }
}
