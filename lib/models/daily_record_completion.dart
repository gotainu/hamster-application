import 'weight_record.dart';

class DailyRecordCompletion {
  final bool conditionCompleted;
  final bool wheelCompleted;
  final WeightRecord? latestWeight;
  final int weightReminderDays;
  final DateTime referenceDate;

  const DailyRecordCompletion({
    required this.conditionCompleted,
    required this.wheelCompleted,
    required this.latestWeight,
    required this.weightReminderDays,
    required this.referenceDate,
  });

  bool get dailyComplete => conditionCompleted && wheelCompleted;

  int get remainingDailyCount {
    var count = 0;
    if (!wheelCompleted) count += 1;
    if (!conditionCompleted) count += 1;
    return count;
  }

  int? get daysSinceWeight {
    final latest = latestWeight;
    if (latest == null) return null;

    final reference = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final recorded = DateTime(
      latest.date.year,
      latest.date.month,
      latest.date.day,
    );

    return reference.difference(recorded).inDays;
  }

  bool get weightDue {
    final days = daysSinceWeight;
    return days == null || days >= weightReminderDays;
  }

  bool get shouldShowPrompt => !dailyComplete || weightDue;

  List<String> get incompleteDailyLabels {
    return [
      if (!wheelCompleted) '昨日の走った記録',
      if (!conditionCompleted) '今日の様子',
    ];
  }

  String get weightPromptLabel {
    final days = daysSinceWeight;
    if (days == null) return '最初の体重記録';
    return '体重記録（前回から$days日）';
  }
}
