import 'dart:async';
import 'package:flutter/material.dart';
import '../models/care_continuity.dart';
import '../models/daily_star_progress.dart';
import '../services/care_continuity_repo.dart';
import '../viewmodels/care_continuity_view_model.dart';
import '../theme/app_theme.dart';
import '../screens/daily_stars.dart';
import 'collectible_glyph.dart';
import 'status_card.dart';

/// The existing Home record surface and detail share one server-backed display.
class CareContinuityPanel extends StatefulWidget {
  const CareContinuityPanel(
      {super.key,
      required this.source,
      required this.progress,
      this.onOpenDetails,
      this.onRecord,
      this.pastAchievements,
      this.showCalendar = false});
  final CareContinuitySource source;
  final DailyStarProgress progress;
  final VoidCallback? onOpenDetails, onRecord;
  final Widget? pastAchievements;
  final bool showCalendar;
  @override
  State<CareContinuityPanel> createState() => _CareContinuityPanelState();
}

class _CareContinuityPanelState extends State<CareContinuityPanel>
    with WidgetsBindingObserver {
  late Stream<CareContinuityState> _stream;
  Future<List<CareContinuityDay>>? _calendar;
  String? _calendarKey;
  DateTime? _month;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  void _bind() {
    _stream = widget.source.watch();
    _calendar = null;
    _calendarKey = null;
    _month = null;
  }

  @override
  void didUpdateWidget(CareContinuityPanel old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source ||
        old.showCalendar != widget.showCalendar) {
      _bind();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await widget.source.refresh();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _calendar = null;
        _calendarKey = null;
      });
    }
  }

  Future<List<CareContinuityDay>> _readCalendar(CareContinuityViewModel vm) {
    final month = _month ?? vm.currentMonth;
    final start = widget.showCalendar
        ? CareContinuityViewModel.monthStart(month)
        : vm.serverDate.subtract(const Duration(days: 6));
    final end = widget.showCalendar
        ? CareContinuityViewModel.monthEnd(month)
        : vm.serverDate;
    final key =
        '${CareContinuityViewModel.dateKey(start)}:${CareContinuityViewModel.dateKey(end)}:${vm.state.lifetimeAchievementDays}';
    if (_calendarKey != key) {
      _calendarKey = key;
      _calendar = widget.source.calendar(
          startDateKey: CareContinuityViewModel.dateKey(start),
          endDateKey: CareContinuityViewModel.dateKey(end));
    }
    return _calendar!;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<CareContinuityState>(
      stream: _stream,
      builder: (context, snapshot) {
        final state = snapshot.hasError ? null : snapshot.data;
        final vm = state == null ? null : CareContinuityViewModel(state);
        final compact = !widget.showCalendar;
        final content =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (compact)
            Row(children: [
              Expanded(
                  child: Text('たくわえ', style: AppTheme.dataTitleStyle(context))),
              if (widget.onOpenDetails != null)
                TextButton(
                    onPressed: widget.onOpenDetails, child: const Text('カレンダー'))
            ]),
          if (state != null && !state.confirmationPending)
            CareAchievementHero(state: state, compact: compact)
          else
            Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.careContentGap),
                child: Column(children: [
                  Text(
                      state?.confirmationPending == true
                          ? '報酬は再確認待ちです。記録は保存されています。'
                          : 'たくわえは同期後に確認できます。',
                      style: AppTheme.dataCaptionStyle(context),
                      textAlign: TextAlign.center),
                  if (snapshot.hasError || state?.confirmationPending == true)
                    TextButton(onPressed: _refresh, child: const Text('状態を再確認'))
                ])),
          SizedBox(
              height:
                  compact ? AppTheme.careContentGap : AppTheme.careSectionGap),
          if (vm != null)
            FutureBuilder<List<CareContinuityDay>>(
                future: _readCalendar(vm),
                builder: (context, calendar) {
                  if (calendar.hasError) {
                    return TextButton(
                        onPressed: _refresh, child: const Text('カレンダーを再確認'));
                  }
                  if (!calendar.hasData) return const LinearProgressIndicator();
                  final month = _month ?? vm.currentMonth;
                  return CareAchievementCalendar(
                      cells: compact
                          ? vm.weekCells(calendar.data!)
                          : vm.monthCells(calendar.data!, month: month),
                      compact: compact,
                      monthLabel: compact
                          ? null
                          : CareContinuityViewModel.monthLabel(month),
                      onPrevious: compact
                          ? null
                          : () => setState(() => _month =
                              DateTime.utc(month.year, month.month - 1)),
                      onNext: compact || !month.isBefore(vm.currentMonth)
                          ? null
                          : () => setState(() => _month =
                              DateTime.utc(month.year, month.month + 1)));
                }),
          if (state != null &&
              !state.confirmationPending &&
              !state.todayAchieved &&
              widget.onRecord != null) ...[
            const SizedBox(height: AppTheme.careContentGap),
            FilledButton(
                onPressed: widget.onRecord, child: const Text('今日の記録を残す'))
          ],
          SizedBox(
              height:
                  compact ? AppTheme.careContentGap : AppTheme.careSectionGap),
          Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(CollectibleCopy.of(context).dailyTitle,
                    style: AppTheme.dataCaptionStyle(context)),
                const SizedBox(width: AppTheme.careContentGap),
                DailyStarsStrip(
                    progress: widget.progress,
                    glyphSize: compact
                        ? AppTheme.careHomeSlotSize
                        : AppTheme.careDetailSlotSize,
                    onTap: widget.onOpenDetails)
              ]),
          if (!compact && state != null && !state.confirmationPending) ...[
            const SizedBox(height: AppTheme.careSectionGap),
            StatusCard(
                level: StatusCardLevel.neutral,
                dataSurface: true,
                padding: AppTheme.careHomePadding,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.pastAchievements != null) ...[
                        Text('これまでの実績',
                            style: AppTheme.dataTitleStyle(context)),
                        const SizedBox(height: AppTheme.careContentGap),
                      ],
                      Row(children: [
                        Expanded(
                            child: Text('これまで記録した日',
                                style: AppTheme.dataBodyStyle(context))),
                        Text('${state.lifetimeAchievementDays}日',
                            style: AppTheme.dataTitleStyle(context))
                      ]),
                      if (widget.pastAchievements != null) ...[
                        const SizedBox(height: AppTheme.careContentGap),
                        widget.pastAchievements!,
                      ],
                    ])),
          ],
        ]);
        return compact
            ? StatusCard(
                level: StatusCardLevel.neutral,
                dataSurface: true,
                padding: AppTheme.careHomePadding,
                child: content)
            : content;
      });
}

/// Shared typography/collectible hero; the amount is never derived on device.
class CareAchievementHero extends StatelessWidget {
  const CareAchievementHero(
      {super.key, required this.state, this.compact = false});
  final CareContinuityState state;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final vm = CareContinuityViewModel(state),
        copy = CollectibleCopy.of(context);
    return Column(children: [
      if (!compact) Text('たくわえ', style: AppTheme.dataCaptionStyle(context)),
      LayoutBuilder(
          builder: (context, constraints) => Semantics(
              liveRegion: true,
              label: '現在のたくわえ ${state.periodEarned}${copy.countUnit}',
              child: ExcludeSemantics(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.dataSmallGap),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CollectibleGlyph(
                                filled: state.periodEarned > 0,
                                size: compact
                                    ? AppTheme.careHomeSymbolSize
                                    : AppTheme.careHeroSymbolSize),
                            const SizedBox(width: AppTheme.careContentGap),
                            Text.rich(
                                TextSpan(
                                    text: vm.amount,
                                    style: AppTheme.careAchievementNumberStyle(
                                        context,
                                        compact: compact,
                                        width: constraints.maxWidth),
                                    children: [
                                      TextSpan(
                                          text: ' ${copy.countUnit}',
                                          style:
                                              AppTheme.careAchievementUnitStyle(
                                                  context,
                                                  compact: compact))
                                    ]),
                                key: const ValueKey('care-achievement-amount')),
                          ])))))),
      Text(vm.guidance ?? vm.achievementLabel,
          style: AppTheme.dataBodyStyle(context), textAlign: TextAlign.center),
      if (state.phase == CareContinuityPhase.grace && vm.graceDeadline != null)
        Padding(
            padding: const EdgeInsets.only(top: AppTheme.dataSmallGap),
            child: Text(vm.graceDeadline!,
                style: AppTheme.dataCaptionStyle(context),
                textAlign: TextAlign.center)),
    ]);
  }
}

/// True recorded days form bands. Rest days and the today ring remain distinct.
class CareAchievementCalendar extends StatelessWidget {
  const CareAchievementCalendar(
      {super.key,
      required this.cells,
      this.compact = false,
      this.monthLabel,
      this.onPrevious,
      this.onNext});
  final List<CareCalendarCell> cells;
  final bool compact;
  final String? monthLabel;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) {
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (compact)
        Text('直近7日', style: AppTheme.dataCaptionStyle(context))
      else
        Row(children: [
          IconButton(
              onPressed: onPrevious,
              tooltip: '前の月',
              icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(monthLabel ?? '',
                      style: AppTheme.dataTitleStyle(context),
                      textAlign: TextAlign.center))),
          IconButton(
              onPressed: onNext,
              tooltip: '次の月',
              icon: const Icon(Icons.chevron_right_rounded))
        ]),
      const SizedBox(height: AppTheme.dataSmallGap),
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.dataSmallGap / 2),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                          compact && cells.length > i
                              ? cells[i].weekdayLabel
                              : const ['月', '火', '水', '木', '金', '土', '日'][i],
                          textAlign: TextAlign.center,
                          style: AppTheme.dataCaptionStyle(context)))))
      ]),
      const SizedBox(height: AppTheme.dataSmallGap),
      for (var row = 0; row < (cells.length / 7).ceil(); row++)
        Row(children: [
          for (var column = 0; column < 7; column++)
            Expanded(
                child: row * 7 + column < cells.length
                    ? _CalendarDay(cell: cells[row * 7 + column])
                    : const SizedBox(height: AppTheme.careCalendarRowHeight))
        ]),
      if (!compact) ...[
        const SizedBox(height: AppTheme.careContentGap),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: AppTheme.careContentGap,
            runSpacing: AppTheme.dataSmallGap,
            children: [
              for (final label in const ['● 記録した日', '○ 今日', '− お休み'])
                Text(label, style: AppTheme.dataCaptionStyle(context))
            ])
      ],
    ]);
    return compact
        ? content
        : StatusCard(
            level: StatusCardLevel.neutral,
            dataSurface: true,
            padding: AppTheme.careHomePadding,
            child: content);
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.cell});
  final CareCalendarCell cell;
  @override
  Widget build(BuildContext context) {
    if (cell.outsideMonth) {
      return const SizedBox(height: AppTheme.careCalendarRowHeight);
    }
    return Semantics(
        label: cell.semanticLabel,
        child: ExcludeSemantics(
            child: SizedBox(
                height: AppTheme.careCalendarRowHeight,
                child: LayoutBuilder(builder: (context, constraints) {
                  final inset =
                      ((constraints.maxWidth - AppTheme.careCalendarDaySize) /
                              2)
                          .clamp(0.0, double.infinity);
                  return Stack(alignment: Alignment.center, children: [
                    if (cell.achieved)
                      Positioned(
                          top: (AppTheme.careCalendarRowHeight -
                                  AppTheme.careCalendarDaySize) /
                              2,
                          left: cell.connectedBefore ? 0 : inset,
                          right: cell.connectedAfter ? 0 : inset,
                          height: AppTheme.careCalendarDaySize,
                          child: DecoratedBox(
                              key: ValueKey(
                                  'care-achievement-band-${cell.dayKey}'),
                              decoration: BoxDecoration(
                                  color: AppTheme.careCalendarBand(context),
                                  borderRadius: BorderRadius.horizontal(
                                      left: Radius.circular(cell.connectedBefore
                                          ? 0
                                          : AppTheme.careCalendarBandRadius),
                                      right: Radius.circular(cell.connectedAfter
                                          ? 0
                                          : AppTheme
                                              .careCalendarBandRadius))))),
                    Container(
                        key: cell.isToday
                            ? const ValueKey('care-calendar-today-ring')
                            : null,
                        width: constraints.maxWidth
                            .clamp(0, AppTheme.careCalendarDaySize),
                        height: AppTheme.careCalendarDaySize,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.dataSmallGap / 2),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: cell.isToday
                                ? Border.all(
                                    color:
                                        AppTheme.careCalendarTodayRing(context),
                                    width: AppTheme.careTodayRingWidth)
                                : null),
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('${cell.day}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        fontWeight: cell.achieved
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: cell.achieved
                                            ? AppTheme.careCalendarOnBand(
                                                context)
                                            : cell.isFuture
                                                ? AppTheme.weakText(context)
                                                : AppTheme.careRestText(
                                                    context))))),
                    if (!cell.achieved && !cell.isToday && !cell.isFuture)
                      Positioned(
                          bottom: AppTheme.dataSmallGap / 2,
                          child: SizedBox(
                              width: AppTheme.careCalendarRestMarkWidth,
                              height: AppTheme.careCalendarRestMarkHeight,
                              child: ColoredBox(
                                  color: AppTheme.careRestText(context)))),
                  ]);
                }))));
  }
}
