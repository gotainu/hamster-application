import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/metric_pair_comparison_bars.dart';

Future<void> showBars(WidgetTester tester, double? value, double? reference,
    {double scale = 1, bool compact = false, double width = 220}) async {
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
          body: Center(
              child: SizedBox(
                  width: width,
                  child: MediaQuery(
                      data:
                          MediaQueryData(textScaler: TextScaler.linear(scale)),
                      child: SingleChildScrollView(
                          child: MetricPairComparisonBars(
                              value: value,
                              referenceValue: reference,
                              valueLabel: compact ? '直近' : '直近の記録',
                              referenceLabel: compact ? '普段' : '普段の基準',
                              unit: 'm',
                              semanticUnit: 'メートル',
                              fractionDigits: 0,
                              compact: compact))))))));
}

void main() {
  testWidgets(
      'compact mode keeps common scale with labels above and numeric values beside tracks',
      (tester) async {
    await showBars(tester, 300, 600, compact: true);
    final recent =
        tester.getSize(find.byKey(const ValueKey('pair-value-fill')));
    final baseline =
        tester.getSize(find.byKey(const ValueKey('pair-reference-fill')));
    expect(recent.width / baseline.width, closeTo(0.5, 0.0001));
    expect(find.text('普段'), findsOneWidget);
    expect(find.text('600m'), findsOneWidget);
    expect(find.text('直近'), findsOneWidget);
    expect(find.text('300m'), findsOneWidget);
    expect(tester.getSize(find.byType(MetricPairComparisonBars)).height,
        lessThanOrEqualTo(100));
    for (final row in [
      ('普段', '600m', 'pair-reference-fill'),
      ('直近', '300m', 'pair-value-fill'),
    ]) {
      final label = tester.getRect(find.text(row.$1));
      final numeric = tester.getRect(find.text(row.$2));
      final track = tester.getRect(find.byKey(ValueKey(row.$3)));
      expect(label.bottom, lessThan(track.top));
      expect(numeric.left, greaterThan(track.right));
      expect(numeric.center.dy, closeTo(track.center.dy, 0.01));
    }
  });

  testWidgets(
      'compact right-hand numbers do not distort common scale when digit counts differ',
      (tester) async {
    await showBars(tester, 50, 600, compact: true);
    final recent =
        tester.getSize(find.byKey(const ValueKey('pair-value-fill')));
    final baseline =
        tester.getSize(find.byKey(const ValueKey('pair-reference-fill')));
    expect(recent.width / baseline.width, closeTo(50 / 600, 0.0001));
    final numeric = tester.getRect(find.text('600m'));
    final referenceTrack =
        tester.getRect(find.byKey(const ValueKey('pair-reference-fill')));
    expect(numeric.left, greaterThan(referenceTrack.right));
    expect(numeric.center.dy, closeTo(referenceTrack.center.dy, 0.01));
  });

  testWidgets('compact equal and zero values retain honest bar lengths',
      (tester) async {
    await showBars(tester, 628.3185, 628.3185, compact: true);
    expect(
        tester.getSize(find.byKey(const ValueKey('pair-value-fill'))).width,
        tester
            .getSize(find.byKey(const ValueKey('pair-reference-fill')))
            .width);
    expect(find.text('普段'), findsOneWidget);
    expect(find.text('直近'), findsOneWidget);
    expect(find.text('628m'), findsNWidgets(2));
    await showBars(tester, 0, 600, compact: true);
    expect(
        tester.getSize(find.byKey(const ValueKey('pair-value-fill'))).width, 0);
    expect(find.text('直近'), findsOneWidget);
    expect(find.text('0m'), findsOneWidget);
  });
  testWidgets('compact narrow large text retains complete values and semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await showBars(tester, 300, 600, compact: true, width: 128, scale: 3);
      expect(find.text('普段'), findsOneWidget);
      expect(find.text('600m'), findsOneWidget);
      expect(find.text('直近'), findsOneWidget);
      expect(find.text('300m'), findsOneWidget);
      expect(find.bySemanticsLabel('普段、600メートル。直近、300メートル。共通のゼロ起点スケール。'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('two measurements use the same zero-origin scale',
      (tester) async {
    await showBars(tester, 300, 600);
    final recent =
        tester.getSize(find.byKey(const ValueKey('pair-value-fill')));
    final baseline =
        tester.getSize(find.byKey(const ValueKey('pair-reference-fill')));
    expect(recent.width / baseline.width, closeTo(0.5, 0.0001));
    expect(find.text('普段の基準：600m'), findsOneWidget);
    expect(find.text('直近の記録：300m'), findsOneWidget);
  });
  testWidgets('equal values produce equal length bars, not an invented range',
      (tester) async {
    await showBars(tester, 628.3185, 628.3185);
    expect(
        tester.getSize(find.byKey(const ValueKey('pair-value-fill'))).width,
        tester
            .getSize(find.byKey(const ValueKey('pair-reference-fill')))
            .width);
    expect(find.text('直近の記録：628m'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('comparison-reference-range')), findsNothing);
  });
  testWidgets('zero remains zero; no minimum-length distortion',
      (tester) async {
    await showBars(tester, 0, 600);
    expect(
        tester.getSize(find.byKey(const ValueKey('pair-value-fill'))).width, 0);
    await showBars(tester, 0, 0);
    expect(
        tester.getSize(find.byKey(const ValueKey('pair-reference-fill'))).width,
        0);
    expect(tester.takeException(), isNull);
  });
  for (final invalid in [null, double.nan, double.infinity, -1.0]) {
    testWidgets('invalid input $invalid withholds comparison', (tester) async {
      await showBars(tester, invalid, 600);
      expect(find.byKey(const ValueKey('pair-value-fill')), findsNothing);
      expect(find.text('比較に必要な記録がそろっていません。'), findsOneWidget);
    });
  }
  testWidgets('narrow large text and accessible values', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await showBars(tester, 300, 600, scale: 3);
      expect(find.bySemanticsLabel('普段の基準、600メートル。直近の記録、300メートル。共通のゼロ起点スケール。'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
