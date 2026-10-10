import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Two observed measurements on a shared zero-origin scale. No reference band,
/// health classification, or statistical calculation is inferred by this widget.
class MetricPairComparisonBars extends StatelessWidget {
  const MetricPairComparisonBars(
      {super.key,
      required this.value,
      required this.referenceValue,
      required this.valueLabel,
      required this.referenceLabel,
      required this.unit,
      this.semanticUnit,
      this.fractionDigits = 0,
      this.compact = false});
  final double? value;
  final double? referenceValue;
  final String valueLabel;
  final String referenceLabel;
  final String unit;
  final String? semanticUnit;
  final int fractionDigits;

  /// Compact labels and spacing are opt-in; the existing layout is preserved.
  final bool compact;
  bool get _valid =>
      [value, referenceValue].every((n) => n != null && n.isFinite && n >= 0);
  String _number(double n) {
    final digits = fractionDigits.clamp(0, 3);
    return NumberFormat(
            digits == 0 ? '0' : '0.${List.filled(digits, '#').join()}')
        .format(n);
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) {
      return Text('比較に必要な記録がそろっていません。',
          style: AppTheme.dataCaptionStyle(context));
    }
    final maximum = math.max(math.max(value!, referenceValue!), 1.0);
    final spoken = semanticUnit ?? unit;
    return Semantics(
      container: true,
      label: '$referenceLabel、${_number(referenceValue!)}$spoken。'
          '$valueLabel、${_number(value!)}$spoken。共通のゼロ起点スケール。',
      child: ExcludeSemantics(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          (compact ? _compactRow : _row)(
              context,
              referenceLabel,
              referenceValue!,
              maximum,
              AppTheme.comparisonReferenceColor(context),
              'pair-reference-fill'),
          SizedBox(
              height:
                  compact ? AppTheme.dataContentGap : AppTheme.dataSectionGap),
          (compact ? _compactRow : _row)(context, valueLabel, value!, maximum,
              AppTheme.comparisonValueColor(context), 'pair-value-fill'),
        ],
      )),
    );
  }

  Widget _row(BuildContext context, String label, double number, double maximum,
          Color color, String key) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$label：${_number(number)}$unit',
              style: AppTheme.dataBodyStyle(context)),
          const SizedBox(height: AppTheme.dataSmallGap),
          _track(context, number, maximum, color, key),
        ],
      );

  double _compactValueWidth(BuildContext context) {
    var width = 0.0;
    for (final number in [value!, referenceValue!]) {
      final painter = TextPainter(
          text: TextSpan(
              text: '${_number(number)}$unit',
              style: AppTheme.dataCaptionStyle(context)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context))
        ..layout();
      width = math.max(width, painter.width);
      painter.dispose();
    }
    return width;
  }

  Widget _compactRow(BuildContext context, String label, double number,
          double maximum, Color color, String key) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTheme.dataCaptionStyle(context)),
          const SizedBox(height: AppTheme.dataValueGap),
          LayoutBuilder(builder: (context, constraints) {
            final valueWidth = _compactValueWidth(context);
            final minimumWidth = valueWidth +
                AppTheme.dataContentGap +
                AppTheme.comparisonInset * 2;
            final valueText = Text('${_number(number)}$unit',
                textAlign: TextAlign.end,
                style: AppTheme.dataCaptionStyle(context));
            // Both rows use the same numeric slot width, so their tracks keep
            // the same scale even when the number of digits differs.
            if (constraints.maxWidth.isFinite &&
                constraints.maxWidth >= minimumWidth) {
              return Row(children: [
                Expanded(child: _track(context, number, maximum, color, key)),
                const SizedBox(width: AppTheme.dataContentGap),
                SizedBox(width: valueWidth, child: valueText),
              ]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _track(context, number, maximum, color, key),
                const SizedBox(height: AppTheme.dataValueGap),
                valueText,
              ],
            );
          }),
        ],
      );

  Widget _track(BuildContext context, double number, double maximum,
          Color color, String key) =>
      LayoutBuilder(builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        return Container(
          height: AppTheme.comparisonTrackHeight,
          decoration: BoxDecoration(
              color: AppTheme.comparisonTrackColor(context),
              borderRadius:
                  BorderRadius.circular(AppTheme.comparisonTrackRadius)),
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: ValueKey(key),
            width: width * (number / maximum),
            height: AppTheme.comparisonTrackHeight,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        BorderRadius.circular(AppTheme.comparisonTrackRadius))),
          ),
        );
      });
}
