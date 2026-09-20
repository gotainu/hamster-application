import 'daily_record_completion.dart';

enum DailyStarSlotKind { openApp, wheel, condition }

class DailyStarSlot {
  final DailyStarSlotKind kind;
  final String label;
  final bool filled;
  final bool optional;

  const DailyStarSlot({
    required this.kind,
    required this.label,
    required this.filled,
    this.optional = false,
  });
}

class DailyStarProgress {
  final List<DailyStarSlot> slots;

  const DailyStarProgress(this.slots);

  factory DailyStarProgress.fromCompletion(DailyRecordCompletion completion) {
    return DailyStarProgress([
      const DailyStarSlot(
        kind: DailyStarSlotKind.openApp,
        label: 'アプリを開く',
        filled: true,
      ),
      DailyStarSlot(
        kind: DailyStarSlotKind.wheel,
        label: '昨日の走った記録',
        filled: completion.wheelCompleted,
      ),
      DailyStarSlot(
        kind: DailyStarSlotKind.condition,
        label: '今日の様子',
        filled: completion.conditionCompleted,
      ),
    ]);
  }

  int get filledCount => slots.where((slot) => slot.filled).length;
}
