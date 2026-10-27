import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/personality_report_entry.dart';
import 'personality_report_v2_ui_fixtures.dart';

class _Unread implements PersonalityUnreadReportsSource {
  final changes =
      StreamController<PersonalityReportState>.broadcast(sync: true);
  @override
  Stream<PersonalityReportState> watchUnreadLatest() => changes.stream;
}

void main() {
  late _Unread source;
  setUp(() => source = _Unread());
  tearDown(() => source.changes.close());
  Future<void> show(WidgetTester tester,
      {void Function(PersonalityReport)? onOpen, ThemeData? theme}) async {
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
            body: PersonalityReportEntry(
                source: source, onOpen: onOpen ?? (_) {}))));
  }

  PersonalityReport daily(String day) =>
      PersonalityReport.fromMap(personalityV2UiFixture(reportId: 'daily_$day'));
  for (final dark in [false, true]) {
    testWidgets(
        'unread report link uses readable ${dark ? 'dark' : 'light'} token',
        (tester) async {
      await show(tester,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme);
      source.changes
          .add(PersonalityReportState.available('owner', daily('2026-10-10')));
      await tester.pump();
      final buttonFinder = find.ancestor(
          of: find.text('うちの子レポートを見る'),
          matching: find.byWidgetPredicate((widget) => widget is TextButton));
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<TextButton>(buttonFinder);
      final context = tester.element(buttonFinder);
      final foreground = button.style!.foregroundColor!.resolve({});
      expect(foreground,
          dark ? AppTheme.quickRecordGlow(context) : AppTheme.accent);
      if (dark) {
        expect(foreground!.computeLuminance(),
            greaterThan(AppTheme.accent.computeLuminance()));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'only server-confirmed latest unread appears and opens its exact ID',
      (tester) async {
    String? opened;
    await show(tester, onOpen: (r) => opened = r.reportId);
    expect(find.text('うちの子レポートを見る'), findsNothing);
    source.changes
        .add(PersonalityReportState.available('owner', daily('2026-10-10')));
    await tester.pump();
    expect(find.text('新しいうちの子レポートが届きました'), findsOneWidget);
    expect(opened, isNull);
    await tester.tap(find.text('うちの子レポートを見る'));
    expect(opened, 'daily_2026-10-10');
  });
  testWidgets(
      'read latest disappears completely and next daily report reappears',
      (tester) async {
    await show(tester);
    source.changes
        .add(PersonalityReportState.available('owner', daily('2026-10-10')));
    await tester.pump();
    expect(find.text('うちの子レポートを見る'), findsOneWidget);
    source.changes.add(const PersonalityReportState.learning('owner'));
    await tester.pump();
    expect(find.byType(Card), findsNothing);
    source.changes
        .add(PersonalityReportState.available('owner', daily('2026-10-11')));
    await tester.pump();
    expect(find.text('新しいうちの子レポートが届きました'), findsOneWidget);
  });
  testWidgets(
      'no latest, loading, unavailable and errors never invent a report',
      (tester) async {
    await show(tester);
    for (final state in [
      const PersonalityReportState.loading('owner'),
      const PersonalityReportState.learning('owner'),
      const PersonalityReportState.unavailable('owner')
    ]) {
      source.changes.add(state);
      await tester.pump();
      expect(find.byType(Card), findsNothing);
    }
    source.changes.addError(StateError('offline'));
    await tester.pump();
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('account switch loading removes previous account card',
      (tester) async {
    await show(tester);
    source.changes
        .add(PersonalityReportState.available('a', daily('2026-10-10')));
    await tester.pump();
    source.changes.add(const PersonalityReportState.loading('b'));
    await tester.pump();
    expect(find.text('うちの子レポートを見る'), findsNothing);
  });
}
