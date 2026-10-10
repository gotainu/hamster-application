import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';

Future<void> _show(WidgetTester tester, MetricComparisonBar bar,
    {bool dark = false, double scale = 1, double width = 360}) async {
  await tester.pumpWidget(MaterialApp(
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
          child:
              SizedBox(width: width, child: SingleChildScrollView(child: bar)),
        ),
      ),
    ),
  ));
}

MetricComparisonBar _bar({
  double? value = 100,
  double? reference = 133,
  double? lower = 100,
  double? upper = 160,
}) =>
    MetricComparisonBar(
      value: value,
      referenceValue: reference,
      valueLabel: 'この子の普段の体重',
      referenceLabel: '同種の研究中央値',
      unit: 'g',
      semanticUnit: 'グラム',
      referenceStart: lower,
      referenceEnd: upper,
      rangeLabel: '研究の中央50%',
    );

void main() {
  MetricComparisonBar compactBar({
    double? value = 100,
    double? reference = 133,
    double? lower = 100,
    double? upper = 160,
  }) =>
      MetricComparisonBar(
        value: value,
        referenceValue: reference,
        valueLabel: 'この子',
        referenceLabel: '参考中央値',
        unit: 'g',
        semanticUnit: 'グラム',
        referenceStart: lower,
        referenceEnd: upper,
        rangeLabel: '中央50%',
        compact: true,
      );

  testWidgets(
      'compact mode shows actual numeric captions without a legend or padded bounds',
      (tester) async {
    await _show(tester, compactBar());
    expect(find.text('100g'), findsOneWidget);
    expect(find.text('中央50%の下限'), findsOneWidget);
    expect(find.text('133g'), findsOneWidget);
    expect(find.text('参考中央値'), findsOneWidget);
    expect(find.text('160g'), findsOneWidget);
    expect(find.text('中央50%の上限'), findsOneWidget);
    expect(find.text('この子: 100g'), findsNothing);
    expect(find.text('92.8g'), findsNothing);
    expect(find.text('167.2g'), findsNothing);
    expect(find.byIcon(Icons.horizontal_rule_rounded), findsNothing);
    expect(find.byKey(const ValueKey('comparison-reference-range')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final value in [20.0, 100.0, 133.0, 160.0, 250.0]) {
    testWidgets('compact value $value keeps true marker and IQR geometry',
        (tester) async {
      await _show(tester, compactBar(value: value));
      final marker = tester
          .getCenter(find.byKey(const ValueKey('comparison-value-marker')));
      final reference = tester
          .getCenter(find.byKey(const ValueKey('comparison-reference-marker')));
      final range = tester
          .getRect(find.byKey(const ValueKey('comparison-reference-range')));
      // Every marker and range edge uses the same linear, stored-value scale.
      final pixelsPerGram = range.width / 60;
      expect(marker.dx - range.left,
          closeTo((value - 100) * pixelsPerGram, 0.001));
      expect(reference.dx - range.left, closeTo(33 * pixelsPerGram, 0.001));
      if (value == 133) {
        expect(marker.dx, closeTo(reference.dx, 0.001));
        expect(marker.dy, isNot(reference.dy));
      }
      final axis =
          tester.getRect(find.byKey(const ValueKey('comparison-axis')));
      expect(marker.dx, inInclusiveRange(axis.left, axis.right));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'compact cohort captions align with true points and outliers retain own value caption',
      (tester) async {
    await _show(tester, compactBar());
    expect(find.byKey(const ValueKey('comparison-positioned-captions')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-wrapped-captions')),
        findsNothing);
    final referenceMarker = tester
        .getCenter(find.byKey(const ValueKey('comparison-reference-marker')));
    final referenceCaption = tester.getCenter(find.text('133g'));
    expect(referenceCaption.dx, closeTo(referenceMarker.dx, 0.01));
    await _show(tester, compactBar(value: 250));
    expect(find.text('250g'), findsOneWidget);
    expect(find.text('この子'), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-wrapped-captions')),
        findsOneWidget);
    expect(find.text('100g'), findsOneWidget);
    expect(find.text('160g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact missing values and invalid ranges do not invent comparison data',
      (tester) async {
    await _show(tester, compactBar(value: null));
    expect(find.byKey(const ValueKey('comparison-axis')), findsNothing);
    expect(find.text('比較に必要な記録がそろっていません。'), findsOneWidget);
    await _show(tester, compactBar(lower: 160, upper: 100));
    expect(find.text('133g'), findsOneWidget);
    expect(find.text('参考中央値'), findsOneWidget);
    expect(find.textContaining('中央50%'), findsNothing);
    expect(
        find.byKey(const ValueKey('comparison-reference-range')), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
        'compact numeric captions stay available at width128 and text scale3, dark=$dark',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _show(tester, compactBar(), width: 128, scale: 3, dark: dark);
        expect(find.text('100g'), findsOneWidget);
        expect(find.text('中央50%の下限'), findsOneWidget);
        expect(find.text('133g'), findsOneWidget);
        expect(find.text('参考中央値'), findsOneWidget);
        expect(find.text('160g'), findsOneWidget);
        expect(find.text('中央50%の上限'), findsOneWidget);
        expect(
            find.bySemanticsLabel(
                'この子、100グラム。塗りつぶしの印。参考中央値、133グラム。縦線の印。中央50%、100〜160グラム。'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('hidden display bounds keep only actual study numbers',
      (tester) async {
    await _show(
        tester,
        const MetricComparisonBar(
            value: 100,
            referenceValue: 133,
            valueLabel: 'この子',
            referenceLabel: '参考中央値',
            unit: 'g',
            referenceStart: 100,
            referenceEnd: 160,
            rangeLabel: '研究の中央50%',
            showAxisLabels: false));
    expect(find.text('92.8g'), findsNothing);
    expect(find.text('167.2g'), findsNothing);
    expect(find.text('研究の中央50%: 100〜160g'), findsOneWidget);
  });
  for (final boundary in [100.0, 160.0]) {
    testWidgets('IQR boundary $boundary is numerically proportional',
        (tester) async {
      await _show(tester, _bar(value: boundary));
      final marker = tester
          .getCenter(find.byKey(const ValueKey('comparison-value-marker')));
      final range = tester
          .getRect(find.byKey(const ValueKey('comparison-reference-range')));
      expect(marker.dx,
          closeTo(boundary == 100 ? range.left : range.right, 0.001));
    });
  }

  testWidgets('saved values, reference IQR, labels and marker lines appear',
      (tester) async {
    await _show(tester, _bar());
    expect(find.text('この子の普段の体重: 100g'), findsOneWidget);
    expect(find.text('同種の研究中央値: 133g'), findsOneWidget);
    expect(find.text('研究の中央50%: 100〜160g'), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-reference-range')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-value-line')), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-reference-line')),
        findsOneWidget);
    expect(find.textContaining('正常'), findsNothing);
    expect(find.textContaining('順位'), findsNothing);
  });
  for (final value in [20.0, 250.0]) {
    testWidgets(
        'outside value $value stays inside axis and outside reference band',
        (tester) async {
      await _show(tester, _bar(value: value));
      final axis =
          tester.getRect(find.byKey(const ValueKey('comparison-axis')));
      final marker =
          tester.getRect(find.byKey(const ValueKey('comparison-value-marker')));
      final band = tester
          .getRect(find.byKey(const ValueKey('comparison-reference-range')));
      expect(marker.left, greaterThanOrEqualTo(axis.left));
      expect(marker.right, lessThanOrEqualTo(axis.right));
      if (value < 100) {
        expect(marker.center.dx, lessThan(band.left));
      } else {
        expect(marker.center.dx, greaterThan(band.right));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('equal values share their true x position with separate markers',
      (tester) async {
    await _show(tester, _bar(value: 133));
    final value =
        tester.getCenter(find.byKey(const ValueKey('comparison-value-marker')));
    final reference = tester
        .getCenter(find.byKey(const ValueKey('comparison-reference-marker')));
    expect(value.dx, closeTo(reference.dx, 0.001));
    expect(value.dy, isNot(reference.dy));
    expect(find.text('この子の普段の体重: 133g'), findsOneWidget);
    expect(find.text('同種の研究中央値: 133g'), findsOneWidget);
  });
  testWidgets('equal zero values use a safe axis without inventing a range',
      (tester) async {
    await _show(tester, _bar(value: 0, reference: 0, lower: null, upper: null));
    expect(find.byKey(const ValueKey('comparison-axis')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('comparison-reference-range')), findsNothing);
    final a =
        tester.getCenter(find.byKey(const ValueKey('comparison-value-marker')));
    final b = tester
        .getCenter(find.byKey(const ValueKey('comparison-reference-marker')));
    expect(a.dx, closeTo(b.dx, 0.001));
    expect(tester.takeException(), isNull);
  });
  for (final invalid in [null, double.nan, double.infinity]) {
    testWidgets(
        'missing or non-finite value $invalid safely withholds the plot',
        (tester) async {
      await _show(tester, _bar(value: invalid));
      expect(find.byKey(const ValueKey('comparison-axis')), findsNothing);
      expect(find.byKey(const ValueKey('comparison-reference-range')),
          findsNothing);
      expect(find.text('比較に必要な記録がそろっていません。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('missing reference also withholds the plot', (tester) async {
    await _show(tester, _bar(reference: null));
    expect(find.byKey(const ValueKey('comparison-axis')), findsNothing);
  });
  for (final ends in <List<double?>>[
    <double?>[null, 160],
    [160, 100],
    [double.nan, 160]
  ]) {
    testWidgets('invalid optional range $ends is not replaced with a fake band',
        (tester) async {
      await _show(tester, _bar(lower: ends[0], upper: ends[1]));
      expect(find.byKey(const ValueKey('comparison-axis')), findsOneWidget);
      expect(find.byKey(const ValueKey('comparison-reference-range')),
          findsNothing);
      expect(find.textContaining('研究の中央50%:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final dark in [false, true]) {
    testWidgets('neutral bar fits narrow width at text scale 3, dark=$dark',
        (tester) async {
      await _show(tester, _bar(), dark: dark, scale: 3, width: 190);
      expect(find.text('同種の研究中央値: 133g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('screen reader receives values, units, marker meanings and range',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _show(tester, _bar());
      expect(
          find.bySemanticsLabel('この子の普段の体重、100グラム。塗りつぶしの印。'
              '同種の研究中央値、133グラム。輪郭の印。'
              '研究の中央50%、100〜160グラム。'),
          findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
