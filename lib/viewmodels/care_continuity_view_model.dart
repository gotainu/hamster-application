import 'package:intl/intl.dart';
import '../models/care_continuity.dart';

/// Presentation and calendar placement only. Balance/expiry remain server facts.
class CareContinuityViewModel {
  const CareContinuityViewModel(this.state);
  final CareContinuityState state;
  String get amount =>
      NumberFormat.decimalPattern('ja_JP').format(state.periodEarned);
  String get achievementLabel =>
      state.todayAchieved ? '今日も記録できました' : '今日の記録はこれから';
  String? get guidance => switch (state.phase) {
        CareContinuityPhase.grace => '今日の記録でキープ',
        CareContinuityPhase.expired => 'たくわえが空になりました',
        CareContinuityPhase.empty => '今日の記録から、始めましょう',
        CareContinuityPhase.active => null,
      };
  String? get graceDeadline {
    if (state.phase != CareContinuityPhase.grace || state.expiresAt == null) {
      return null;
    }
    final last = state.expiresAt!
        .toUtc()
        .add(const Duration(hours: 9))
        .subtract(const Duration(seconds: 1));
    return '${last.month}月${last.day}日 23:59まで（日本時間）';
  }

  DateTime get serverDate => DateTime.parse('${state.serverDateKey}T00:00:00Z');
  DateTime get currentMonth => DateTime.utc(serverDate.year, serverDate.month);
  static String dateKey(DateTime date) =>
      date.toIso8601String().substring(0, 10);
  static String monthLabel(DateTime month) => '${month.year}年${month.month}月';
  static DateTime monthStart(DateTime month) =>
      DateTime.utc(month.year, month.month);
  static DateTime monthEnd(DateTime month) =>
      DateTime.utc(month.year, month.month + 1, 0);
  List<CareCalendarCell> cells(List<CareContinuityDay> days,
          {int count = 28}) =>
      _range(days, serverDate.subtract(Duration(days: count - 1)), count);
  List<CareCalendarCell> weekCells(List<CareContinuityDay> days) =>
      cells(days, count: 7);
  List<CareCalendarCell> monthCells(List<CareContinuityDay> days,
      {DateTime? month}) {
    final first = monthStart(month ?? currentMonth), last = monthEnd(first);
    final start =
        first.subtract(Duration(days: first.weekday - DateTime.monday));
    final count = ((last.difference(start).inDays + 1) / 7).ceil() * 7;
    return _range(days, start, count, displayedMonth: first);
  }

  List<CareCalendarCell> _range(
      List<CareContinuityDay> days, DateTime start, int count,
      {DateTime? displayedMonth}) {
    final recorded = {
      for (final day in days.where((day) => day.achieved)) day.dayKey: day
    };
    final cells = List.generate(count, (index) {
      final date = start.add(Duration(days: index)), key = dateKey(date);
      final outside = displayedMonth != null &&
          (date.month != displayedMonth.month ||
              date.year != displayedMonth.year);
      return CareCalendarCell(
          dayKey: key,
          day: date.day,
          weekday: date.weekday,
          achieved: !outside &&
              key.compareTo(state.serverDateKey) <= 0 &&
              recorded[key]?.achieved == true,
          isToday: key == state.serverDateKey,
          isFuture: key.compareTo(state.serverDateKey) > 0,
          outsideMonth: outside,
          periodId: recorded[key]?.periodId);
    });
    bool adjacent(int a, int b) =>
        a >= 0 &&
        b < cells.length &&
        cells[a].achieved &&
        cells[b].achieved &&
        cells[a].weekday != DateTime.sunday &&
        cells[a].dayKey.substring(0, 7) == cells[b].dayKey.substring(0, 7) &&
        (cells[a].periodId == null ||
            cells[b].periodId == null ||
            cells[a].periodId == cells[b].periodId);
    return List.generate(
        count,
        (index) => cells[index].withConnections(
            before: index % 7 != 0 && adjacent(index - 1, index),
            after: index % 7 != 6 && adjacent(index, index + 1)));
  }
}

class CareCalendarCell {
  const CareCalendarCell(
      {required this.dayKey,
      required this.day,
      required this.achieved,
      required this.isToday,
      this.weekday = 1,
      this.isFuture = false,
      this.outsideMonth = false,
      this.connectedBefore = false,
      this.connectedAfter = false,
      this.periodId});
  final String dayKey;
  final int day, weekday;
  final bool achieved,
      isToday,
      isFuture,
      outsideMonth,
      connectedBefore,
      connectedAfter;
  final String? periodId;
  String get weekdayLabel =>
      const ['月', '火', '水', '木', '金', '土', '日'][weekday - 1];
  String get semanticLabel =>
      '$dayKey、${achieved ? '記録保存で達成' : isFuture ? 'これからの日' : isToday ? '未達成' : 'お休み'}${isToday ? '、今日' : ''}';
  CareCalendarCell withConnections(
          {required bool before, required bool after}) =>
      CareCalendarCell(
          dayKey: dayKey,
          day: day,
          weekday: weekday,
          achieved: achieved,
          isToday: isToday,
          isFuture: isFuture,
          outsideMonth: outsideMonth,
          connectedBefore: before,
          connectedAfter: after,
          periodId: periodId);
}
