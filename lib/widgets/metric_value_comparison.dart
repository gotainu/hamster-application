import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'metric_value_display.dart';

/// A measured value and its saved comparison. The comparison is meaningful
/// information, not a health-status badge; no baseline is calculated here.
class MetricValueComparison extends StatelessWidget {
  const MetricValueComparison(
      {super.key,
      required this.value,
      required this.unit,
      required this.semanticLabel,
      this.differenceKey,
      this.differenceValue,
      this.differenceCaption,
      this.differenceContext,
      this.inlineDifferenceCaption = false});
  final String value;
  final String unit;
  final String semanticLabel;
  final Key? differenceKey;
  final String? differenceValue;
  final String? differenceCaption;
  final String? differenceContext;
  final bool inlineDifferenceCaption;

  @override
  Widget build(BuildContext context) {
    final valueWidget = MetricValueDisplay(
        value: value, unit: unit, semanticLabel: semanticLabel);
    if (differenceValue == null || differenceCaption == null) {
      return valueWidget;
    }
    final textScaler = MediaQuery.textScalerOf(context);
    double width(TextSpan text) {
      final painter = TextPainter(
          text: text,
          textDirection: Directionality.of(context),
          textScaler: textScaler)
        ..layout();
      final measured = painter.width;
      painter.dispose();
      return measured;
    }

    final valueWidth = width(TextSpan(children: [
          TextSpan(text: value, style: AppTheme.dataValueStyle(context)),
          TextSpan(text: ' $unit', style: AppTheme.dataTitleStyle(context)),
        ])) +
        AppTheme.dataSmallGap;
    final differenceWidth = [
          width(TextSpan(
                  text: differenceValue,
                  style: AppTheme.dataDifferenceValueStyle(context))) +
              (inlineDifferenceCaption
                  ? AppTheme.dataValueGap +
                      width(TextSpan(
                          text: differenceCaption,
                          style: AppTheme.dataCaptionStyle(context)))
                  : 0),
          width(TextSpan(
              text: differenceCaption,
              style: AppTheme.dataCaptionStyle(context))),
          if (differenceContext != null)
            width(TextSpan(
                text: differenceContext,
                style: AppTheme.dataCaptionStyle(context))),
        ].reduce(math.max) +
        AppTheme.dataDifferencePadding.horizontal +
        AppTheme.dataDifferenceBorderWidth * 2;
    final differenceWidget = Semantics(
      container: true,
      label: '${differenceContext ?? ''}$differenceValue、$differenceCaption',
      child: ExcludeSemantics(
          child: Container(
        key: differenceKey,
        padding: AppTheme.dataDifferencePadding,
        decoration: AppTheme.dataDifferenceDecoration(context),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (differenceContext != null)
            Text(differenceContext!,
                style: AppTheme.dataCaptionStyle(context),
                textAlign: TextAlign.center),
          if (inlineDifferenceCaption)
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppTheme.dataValueGap,
                children: [
                  Text(differenceValue!,
                      style: AppTheme.dataDifferenceValueStyle(context)),
                  Text(differenceCaption!,
                      style: AppTheme.dataCaptionStyle(context)),
                ])
          else ...[
            Text(differenceValue!,
                style: AppTheme.dataDifferenceValueStyle(context),
                textAlign: TextAlign.center),
            Text(differenceCaption!,
                style: AppTheme.dataCaptionStyle(context),
                textAlign: TextAlign.center),
          ],
        ]),
      )),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (valueWidth + differenceWidth + AppTheme.dataContentGap >
          constraints.maxWidth) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          valueWidget,
          const SizedBox(height: AppTheme.dataSmallGap),
          differenceWidget,
        ]);
      }
      return Row(children: [
        Expanded(child: valueWidget),
        const SizedBox(width: AppTheme.dataContentGap),
        SizedBox(width: differenceWidth, child: differenceWidget)
      ]);
    });
  }
}
