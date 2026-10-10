import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Positions two saved measurements and an optional, explicitly supplied range.
/// This component does not infer health, percentiles, or a range from dispersion.
class MetricComparisonBar extends StatelessWidget {
  const MetricComparisonBar({
    super.key,
    required this.value,
    required this.referenceValue,
    required this.valueLabel,
    required this.referenceLabel,
    required this.unit,
    this.referenceStart,
    this.referenceEnd,
    this.rangeLabel = '参考範囲',
    this.fractionDigits = 1,
    this.semanticUnit,
    this.showAxisLabels = true,
    this.compact = false,
  });

  final double? value;
  final double? referenceValue;
  final String valueLabel;
  final String referenceLabel;
  final String unit;
  final double? referenceStart;
  final double? referenceEnd;
  final String rangeLabel;
  final int fractionDigits;
  final String? semanticUnit;

  /// Display-axis endpoints are layout values, not research boundaries.
  /// Hide them when the actual cohort numbers provide a sufficient legend.
  final bool showAxisLabels;

  /// Opt-in numeric caption layout. Existing plot coordinates and full legend
  /// remain unchanged when false. Compact mode never shows padded axis bounds.
  final bool compact;

  bool get _hasValues =>
      value != null &&
      value!.isFinite &&
      referenceValue != null &&
      referenceValue!.isFinite;

  bool get _hasRange =>
      referenceStart != null &&
      referenceStart!.isFinite &&
      referenceEnd != null &&
      referenceEnd!.isFinite &&
      referenceStart! <= referenceEnd!;

  String _format(double number) {
    final digits = fractionDigits.clamp(0, 3);
    final pattern = digits == 0 ? '0' : '0.${List.filled(digits, '#').join()}';
    return NumberFormat(pattern).format(number);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValues) {
      return Text(
        '比較に必要な記録がそろっていません。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryText(context),
            ),
      );
    }
    final numbers = [
      value!,
      referenceValue!,
      if (_hasRange) referenceStart!,
      if (_hasRange) referenceEnd!
    ];
    final lower = numbers.reduce(math.min);
    final upper = numbers.reduce(math.max);
    final span = upper - lower;
    // Expanding the display axis for equal values is purely layout. It never
    // creates a reference band or assigns any meaning to the surrounding values.
    final padding = span > 0 ? span * 0.12 : math.max(lower.abs() * 0.12, 1.0);
    final minimum =
        lower >= 0 ? math.max(0.0, lower - padding) : lower - padding;
    final maximum = upper + padding;
    final extent = maximum - minimum;
    if (!minimum.isFinite ||
        !maximum.isFinite ||
        !extent.isFinite ||
        extent <= 0) {
      return Text('比較に必要な記録がそろっていません。',
          style: Theme.of(context).textTheme.bodyMedium);
    }
    final spokenUnit = semanticUnit ?? unit;
    final spoken = '$valueLabel、${_format(value!)}$spokenUnit。塗りつぶしの印。'
        '$referenceLabel、${_format(referenceValue!)}$spokenUnit。${compact ? '縦線の印' : '輪郭の印'}。'
        '${_hasRange ? '$rangeLabel、${_format(referenceStart!)}〜${_format(referenceEnd!)}$spokenUnit。' : ''}';
    final markerColor = AppTheme.accent;
    final referenceColor = AppTheme.primaryText(context);

    return Semantics(
      container: true,
      label: spoken,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              _CompactComparisonPlot(
                value: value!,
                reference: referenceValue!,
                lower: _hasRange ? referenceStart : null,
                upper: _hasRange ? referenceEnd : null,
                minimum: minimum,
                extent: extent,
                valueLabel: valueLabel,
                referenceLabel: referenceLabel,
                rangeLabel: rangeLabel,
                unit: unit,
                format: _format,
                markerColor: markerColor,
                referenceColor: referenceColor,
              )
            else
              LayoutBuilder(builder: (context, constraints) {
                if (!constraints.maxWidth.isFinite ||
                    constraints.maxWidth < 32) {
                  return const SizedBox.shrink();
                }
                const inset = AppTheme.comparisonInset;
                final width = constraints.maxWidth;
                final usable = width - inset * 2;
                double x(double number) =>
                    inset +
                    ((number - minimum) / extent).clamp(0.0, 1.0) * usable;
                final valueX = x(value!);
                final referenceX = x(referenceValue!);
                final rangeX = _hasRange ? x(referenceStart!) : 0.0;
                final rangeWidth =
                    _hasRange ? math.max(1.0, x(referenceEnd!) - rangeX) : 0.0;

                return SizedBox(
                  key: const ValueKey('comparison-axis'),
                  height: 64,
                  child: Stack(
                    children: [
                      if (_hasRange)
                        Positioned(
                          left: rangeX,
                          top: 26,
                          width: rangeWidth,
                          height: 14,
                          child: DecoratedBox(
                            key: const ValueKey('comparison-reference-range'),
                            decoration: BoxDecoration(
                              color: AppTheme.chipFill(referenceColor, context,
                                  opacity: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      Positioned(
                        left: inset,
                        right: inset,
                        top: 32,
                        height: 2,
                        child: ColoredBox(color: AppTheme.chartAxis(context)),
                      ),
                      Positioned(
                        left: valueX - 1,
                        top: 19,
                        width: 2,
                        height: 14,
                        child: ColoredBox(
                            key: const ValueKey('comparison-value-line'),
                            color: markerColor),
                      ),
                      Positioned(
                        left: valueX - 7,
                        top: 6,
                        width: 14,
                        height: 14,
                        child: Icon(Icons.circle,
                            key: const ValueKey('comparison-value-marker'),
                            size: 14,
                            color: markerColor),
                      ),
                      Positioned(
                        left: referenceX - 1,
                        top: 33,
                        width: 2,
                        height: 14,
                        child: ColoredBox(
                            key: const ValueKey('comparison-reference-line'),
                            color: referenceColor),
                      ),
                      Positioned(
                        left: referenceX - 7,
                        top: 47,
                        width: 14,
                        height: 14,
                        child: Icon(Icons.radio_button_unchecked,
                            key: const ValueKey('comparison-reference-marker'),
                            size: 14,
                            color: referenceColor),
                      ),
                    ],
                  ),
                );
              }),
            if (showAxisLabels && !compact)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Text('${_format(minimum)}$unit',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppTheme.secondaryText(context)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('${_format(maximum)}$unit',
                          textAlign: TextAlign.end,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppTheme.secondaryText(context)))),
                ],
              ),
            if (!compact) ...[
              const SizedBox(height: 14),
              _Legend(
                  icon: Icons.circle,
                  color: markerColor,
                  text: '$valueLabel: ${_format(value!)}$unit'),
              const SizedBox(height: 8),
              _Legend(
                  icon: Icons.radio_button_unchecked,
                  color: referenceColor,
                  text: '$referenceLabel: ${_format(referenceValue!)}$unit'),
              if (_hasRange) ...[
                const SizedBox(height: 8),
                _Legend(
                    icon: Icons.horizontal_rule_rounded,
                    color: referenceColor,
                    text:
                        '$rangeLabel: ${_format(referenceStart!)}〜${_format(referenceEnd!)}$unit'),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.secondaryText(context), height: 1.5))),
        ],
      );
}

class _ComparisonCaption {
  const _ComparisonCaption(this.value, this.role, this.color);
  final double value;
  final String role;
  final Color color;
}

/// Labels name only saved cohort values. Display-axis padding has no label.
/// Colliding annotations switch to a wrapping layout rather than moving data.
class _CompactComparisonPlot extends StatelessWidget {
  const _CompactComparisonPlot({
    required this.value,
    required this.reference,
    required this.lower,
    required this.upper,
    required this.minimum,
    required this.extent,
    required this.valueLabel,
    required this.referenceLabel,
    required this.rangeLabel,
    required this.unit,
    required this.format,
    required this.markerColor,
    required this.referenceColor,
  });
  final double value;
  final double reference;
  final double? lower;
  final double? upper;
  final double minimum;
  final double extent;
  final String valueLabel;
  final String referenceLabel;
  final String rangeLabel;
  final String unit;
  final String Function(double) format;
  final Color markerColor;
  final Color referenceColor;

  List<_ComparisonCaption> get _captions {
    final items = <_ComparisonCaption>[
      if (lower != null)
        _ComparisonCaption(lower!, '$rangeLabelの下限', referenceColor),
      _ComparisonCaption(reference, referenceLabel, referenceColor),
      if (upper != null)
        _ComparisonCaption(upper!, '$rangeLabelの上限', referenceColor),
      // A value equal to the lower quartile is already visibly labeled there.
      // Other values retain their own caption, including equal reference values.
      if (value != lower) _ComparisonCaption(value, valueLabel, markerColor),
    ];
    items.sort((a, b) => a.value.compareTo(b.value));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.dataCaptionStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (!width.isFinite || width < AppTheme.comparisonInset * 2) {
        return const SizedBox.shrink();
      }
      final inset = AppTheme.comparisonInset;
      final usable = width - inset * 2;
      double x(double number) =>
          inset + ((number - minimum) / extent).clamp(0.0, 1.0) * usable;
      final plotHeight = AppTheme.comparisonCompactPlotHeight;
      final bandHeight = AppTheme.comparisonCompactBandHeight;
      final bandTop = (plotHeight - bandHeight) / 2;
      final markerSize = AppTheme.comparisonCompactMarkerSize;
      final lineWidth = AppTheme.comparisonCompactLineWidth;
      final valueX = x(value);
      final referenceX = x(reference);
      final captions = _captions;
      Size measure(String text, double maxWidth) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: maxWidth);
        final size = Size(painter.width, painter.height);
        painter.dispose();
        return size;
      }

      final widths = <double>[];
      final heights = <double>[];
      final lefts = <double>[];
      var fits = true;
      var priorRight = -double.infinity;
      for (final caption in captions) {
        final number =
            measure('${format(caption.value)}$unit', double.infinity);
        final role = measure(caption.role, double.infinity);
        final desired = math.max(number.width,
            math.min(role.width, AppTheme.comparisonCompactLabelMaxWidth));
        final captionWidth = math.min(width, desired);
        final captionLeft = (x(caption.value) - captionWidth / 2)
            .clamp(0.0, width - captionWidth)
            .toDouble();
        if (desired > width ||
            captionLeft < priorRight + AppTheme.dataSmallGap) {
          fits = false;
        }
        priorRight = captionLeft + captionWidth;
        widths.add(captionWidth);
        lefts.add(captionLeft);
        heights.add(
            measure('${format(caption.value)}$unit', captionWidth).height +
                AppTheme.comparisonCompactLabelGap +
                measure(caption.role, captionWidth).height);
      }
      Widget caption(_ComparisonCaption item) => Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${format(item.value)}$unit',
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: item.color)),
              const SizedBox(height: AppTheme.comparisonCompactLabelGap),
              Text(item.role, textAlign: TextAlign.center, style: style),
            ],
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('comparison-axis'),
            height: plotHeight,
            child: Stack(children: [
              Positioned(
                left: inset,
                right: inset,
                top: bandTop,
                height: bandHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.comparisonTrackColor(context),
                    borderRadius:
                        BorderRadius.circular(AppTheme.comparisonTrackRadius),
                  ),
                ),
              ),
              if (lower != null && upper != null)
                Positioned(
                  left: x(lower!),
                  width: math.max(lineWidth, x(upper!) - x(lower!)),
                  top: bandTop,
                  height: bandHeight,
                  child: DecoratedBox(
                    key: const ValueKey('comparison-reference-range'),
                    decoration: BoxDecoration(
                      gradient:
                          AppTheme.comparisonCompactRangeGradient(context),
                      borderRadius:
                          BorderRadius.circular(AppTheme.comparisonTrackRadius),
                    ),
                  ),
                ),
              Positioned(
                left: referenceX - lineWidth / 2,
                top: bandTop / 2,
                width: lineWidth,
                height: plotHeight - bandTop,
                child: ColoredBox(
                    key: const ValueKey('comparison-reference-marker'),
                    color: referenceColor),
              ),
              Positioned(
                left: valueX - lineWidth / 2,
                top: bandTop,
                width: lineWidth,
                height: plotHeight - bandTop,
                child: ColoredBox(
                    key: const ValueKey('comparison-value-line'),
                    color: markerColor),
              ),
              Positioned(
                left: valueX - markerSize / 2,
                top: math.max(0, bandTop - markerSize / 2),
                width: markerSize,
                height: markerSize,
                child: DecoratedBox(
                  key: const ValueKey('comparison-value-marker'),
                  decoration:
                      BoxDecoration(color: markerColor, shape: BoxShape.circle),
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppTheme.dataValueGap),
          if (fits)
            SizedBox(
              key: const ValueKey('comparison-positioned-captions'),
              height: heights.reduce(math.max),
              child: Stack(children: [
                for (var i = 0; i < captions.length; i++)
                  Positioned(
                      left: lefts[i],
                      width: widths[i],
                      top: 0,
                      child: caption(captions[i])),
              ]),
            )
          else
            Wrap(
              key: const ValueKey('comparison-wrapped-captions'),
              alignment: WrapAlignment.spaceBetween,
              spacing: AppTheme.dataSmallGap,
              runSpacing: AppTheme.dataSmallGap,
              children: [
                for (var i = 0; i < captions.length; i++)
                  SizedBox(width: widths[i], child: caption(captions[i])),
              ],
            ),
        ],
      );
    });
  }
}
