import '../models/checkin_insight.dart';
import 'insight_display.dart';

/// Formats committed server counts; performs no observation aggregation.
class CheckinInsightsViewModel {
  final List<InsightDisplay> items;
  const CheckinInsightsViewModel._(this.items);
  const CheckinInsightsViewModel.empty() : items = const [];
  String? get primaryDiscoveryText =>
      items.where((item) => item.discovery).firstOrNull?.text;
  factory CheckinInsightsViewModel.fromCurrent(CurrentCheckinAnalysis? current,
      {String? expectedOwnerId,
      String? evaluationDateKey,
      DateTime? generatedAt}) {
    if (current == null ||
        current.ownerId.isEmpty ||
        (expectedOwnerId != null && current.ownerId != expectedOwnerId) ||
        (evaluationDateKey != null &&
            current.evaluationDateKey != evaluationDateKey) ||
        (generatedAt != null &&
            !current.silverGeneratedAt.isAtSameMomentAs(generatedAt))) {
      return const CheckinInsightsViewModel.empty();
    }
    return CheckinInsightsViewModel._(_format(current.insights));
  }
  factory CheckinInsightsViewModel.fromSnapshot(
          CheckinReportInsightSnapshot? value) =>
      value == null
          ? const CheckinInsightsViewModel.empty()
          : CheckinInsightsViewModel._(_format(value));
  static List<InsightDisplay> _format(CheckinInsightSet set) =>
      List.unmodifiable([
        for (final value in set.insights)
          InsightDisplay(
              id: value.id,
              text: switch (value.kind) {
                CheckinInsightKind.itemRepetition =>
                  '確認できた${value.evidence.selectionVerifiedDayCount}日分の記録で、${value.evidence.itemLabel}が${value.evidence.matchingDayCount}日、気になる箇所として選ばれました',
                CheckinInsightKind.concernFrequency =>
                  '${value.evidence.validRecordDayCount}日分の記録中、「少し違う」「心配」は${value.evidence.concernDayCount}日でした',
                CheckinInsightKind.recordContinuity =>
                  '過去14日間に${value.evidence.validRecordDayCount}日、様子を記録しました',
              },
              periodLabel:
                  '${set.windowStartDateKey}〜${set.windowEndDateKey}（14日間）',
              evidenceLabel:
                  '有効記録 ${value.evidence.validRecordDayCount}日 · 未記録 ${value.evidence.missingDayCount}日'
                  '${value.evidence.invalidDayCount > 0 ? ' · 確認できない記録 ${value.evidence.invalidDayCount}日' : ''}',
              discovery: value.discovery),
      ]);
}
