import 'package:uuid/uuid.dart';
import '../models/care_action_catalog.dart';
import '../models/daily_care_actions.dart';

/// A local draft. Visual zero/none defaults are not answers until confirmed.
/// Voice input can use these same selections without changing the save contract.
class CareActionInputViewModel {
  static const int sliderMaxMinutes = 120;
  CareActionInputViewModel(
      {required this.dayKey, this.catalog = careActionCatalog}) {
    for (final item in activeCareActionItems(catalog: catalog)) {
      actions[item.id] = const CareActionResponse();
      _unconfirmedDefaults.add(item.id);
    }
  }
  final String dayKey;
  final List<CareActionCatalogItem> catalog;
  final Map<String, CareActionResponse> actions = {};
  final Set<String> _unconfirmedDefaults = {};
  int revision = 0;
  bool dirty = false;
  bool confirmedSaved = false;
  CareActionMutation? pending;
  String? detailError;
  bool get hasExplicitAnswer =>
      actions.values.any((a) => a.answer != CareActionAnswer.unanswered);
  bool get canSave => dirty && pending == null && detailError == null;
  bool get canConfirmAndSave =>
      (dirty || _unconfirmedDefaults.isNotEmpty) &&
      pending == null &&
      detailError == null;
  bool isUnconfirmed(String id) => _unconfirmedDefaults.contains(id);

  void load(CareActionLoadResult result) {
    revision = result.record?.revision ?? 0;
    confirmedSaved = result.serverConfirmed &&
        result.record != null &&
        result.record!.status == 'active';
    if (result.record?.status == 'active') {
      actions.addAll(result.record!.actions);
      _unconfirmedDefaults.removeAll(result.record!.actions.keys);
    }
    if (result.pending != null) {
      actions.addAll(result.pending!.actions);
      _unconfirmedDefaults.removeAll(result.pending!.actions.keys);
      pending = result.pending;
    }
    dirty = false;
  }

  void select(String id, CareActionAnswer answer) {
    if (pending != null) return;
    actions[id] = (actions[id] ?? const CareActionResponse()).select(answer);
    _unconfirmedDefaults.remove(id);
    dirty = true;
    detailError = null;
  }

  CareActionDetail? definition(String id, String meaning) {
    final item = careActionItem(id, catalog: catalog);
    for (final detail in item?.detailDefinitions ?? <CareActionDetail>[]) {
      if (!detail.legacy && detail.meaning == meaning) return detail;
    }
    return null;
  }

  String? cleaningChoice(String id) {
    if (isUnconfirmed(id) ||
        actions[id]?.answer == CareActionAnswer.notPerformed) {
      return 'none';
    }
    final key = definition(id, 'cleaning_type')?.key;
    return key == null ? null : actions[id]?.details[key] as String?;
  }

  void selectCleaning(String id, String value) {
    if (pending != null) return;
    if (value == 'none') {
      select(id, CareActionAnswer.notPerformed);
      return;
    }
    final primary = definition(id, 'cleaning_type');
    if (primary == null || !primary.values.any((v) => v.id == value)) return;
    final next = <String, dynamic>{primary.key: value};
    // Bedding is independent; retain an explicitly chosen value only while applicable.
    final secondary = definition(id, 'bedding_replacement');
    final oldValue =
        secondary == null ? null : actions[id]?.details[secondary.key];
    if (secondary != null && secondary.isApplicable(next) && oldValue != null) {
      next[secondary.key] = oldValue;
    }
    actions[id] = CareActionResponse(
        answer: CareActionAnswer.performed,
        details: next,
        answerProvenance: 'item_selection');
    _unconfirmedDefaults.remove(id);
    dirty = true;
    detailError = null;
  }

  int? minutes(String id) {
    if (isUnconfirmed(id) ||
        actions[id]?.answer == CareActionAnswer.notPerformed) {
      return 0;
    }
    final key = definition(id, 'daily_total')?.key;
    final value = key == null ? null : actions[id]?.details[key];
    return value is int ? value : null;
  }

  void selectMinutes(String id, int? minutes) {
    if (pending != null) return;
    final detail = definition(id, 'daily_total');
    if (detail == null) return;
    if (minutes != null &&
        (minutes < 0 || (detail.max != null && minutes > detail.max!))) {
      detailError = '${detail.label}は0〜${detail.max?.toInt()}分で入力してください';
      return;
    }
    actions[id] = CareActionResponse(
        answer: minutes == 0
            ? CareActionAnswer.notPerformed
            : CareActionAnswer.performed,
        details:
            minutes == null || minutes == 0 ? const {} : {detail.key: minutes},
        answerProvenance: 'item_selection');
    _unconfirmedDefaults.remove(id);
    dirty = true;
    detailError = null;
  }

  void detail(String id, Object? value, {String? key}) {
    final item = careActionItem(id, catalog: catalog);
    final definitions = item?.detailDefinitions ?? <CareActionDetail>[];
    final matching =
        definitions.where((d) => key == null ? !d.legacy : d.key == key);
    final definition = matching.isEmpty ? null : matching.first;
    final action = actions[id];
    if (pending != null ||
        action?.answer != CareActionAnswer.performed ||
        definition == null) {
      return;
    }
    if (value is int &&
        ((definition.min != null && value < definition.min!) ||
            (definition.max != null && value > definition.max!))) {
      detailError = '${definition.label}を確認してください';
      return;
    }
    if (!definition.isApplicable(action!.details)) return;
    if (value != null &&
        definition.values.isNotEmpty &&
        !definition.values.any((v) => v.id == value)) {
      return;
    }
    final next = <String, dynamic>{...action.details}..remove(definition.key);
    if (value != null) next[definition.key] = value;
    detailError = null;
    actions[id] = CareActionResponse(
        answer: action.answer,
        details: next,
        answerProvenance: 'item_selection');
    _unconfirmedDefaults.remove(id);
    dirty = true;
  }

  /// Only the explicit normal save may turn untouched visual defaults into facts.
  void confirmDefaults() {
    if (pending != null || detailError != null) return;
    for (final item in activeCareActionItems(catalog: catalog)) {
      if (!_unconfirmedDefaults.contains(item.id)) continue;
      if (item.inputType == 'cleaning_choice' ||
          item.inputType == 'duration_minutes') {
        actions[item.id] = const CareActionResponse(
            answer: CareActionAnswer.notPerformed,
            answerProvenance: 'batch_confirmation');
        dirty = true;
      }
    }
    _unconfirmedDefaults.clear();
  }

  String get draftSummary =>
      activeCareActionItems(catalog: catalog).map((item) {
        final answer = actions[item.id]!;
        if (item.inputType == 'cleaning_choice') {
          final choice = cleaningChoice(item.id);
          if (choice == 'none') return '掃除なし';
          final primary = definition(item.id, 'cleaning_type');
          final options = primary?.values.where((v) => v.id == choice) ?? [];
          if (options.isNotEmpty) {
            final bedding = definition(item.id, 'bedding_replacement');
            final beddingValue =
                bedding == null ? null : answer.details[bedding.key];
            final beddingOptions =
                bedding?.values.where((v) => v.id == beddingValue) ?? [];
            return '${options.first.label}${beddingOptions.isEmpty ? '' : '・床材${beddingOptions.first.label}'}';
          }
          return answer.answer == CareActionAnswer.performed
              ? '掃除済み・詳細不明'
              : '掃除未回答';
        }
        if (item.inputType == 'duration_minutes') {
          final value = minutes(item.id);
          return value != null
              ? '散歩$value分'
              : answer.answer == CareActionAnswer.performed
                  ? '散歩時間不明'
                  : '散歩未回答';
        }
        return '${item.label} ${answer.answer.label}';
      }).join('・');

  CareActionMutation mutation({bool cancel = false}) =>
      pending ??
      CareActionMutation(
          dayKey: dayKey,
          expectedRevision: revision,
          mutationId: const Uuid().v4(),
          operation: cancel ? 'cancel' : 'save',
          inputUiVersion: 'care_actions_input_v2',
          actions: cancel
              ? const {}
              : Map.unmodifiable({
                  for (final item in activeCareActionItems(catalog: catalog))
                    item.id: actions[item.id] ??
                        const CareActionResponse(answerProvenance: 'unanswered')
                }));
  void apply(CareActionSaveResult result) {
    if (!result.confirmed) {
      pending = result.mutation;
      dirty = false;
      return;
    }
    pending = null;
    revision = result.revision!;
    dirty = false;
    confirmedSaved = result.mutation.operation == 'save';
    _unconfirmedDefaults.clear();
    if (confirmedSaved) {
      actions.addAll(result.mutation.actions);
    } else {
      for (final id in actions.keys.toList()) {
        actions[id] = const CareActionResponse(answerProvenance: 'unanswered');
      }
    }
  }
}

String careDetailUnit(String? unit) =>
    switch (unit) { 'minutes' => '分', _ => unit ?? '' };
String? careDetailHelper(String? meaning) =>
    switch (meaning) { 'daily_total' => '1回分ではなく、その日の合計です。', _ => null };
