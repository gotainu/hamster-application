import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Value and unit remain separate. Numeric digits stay on one line and fit
/// only when space is insufficient; unit and captions may wrap normally.
class MetricValueDisplay extends StatelessWidget {
  const MetricValueDisplay(
      {super.key,
      required this.value,
      required this.unit,
      required this.semanticLabel});
  final String value;
  final String unit;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppTheme.dataSmallGap,
                    children: [
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth),
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(value,
                                maxLines: 1,
                                softWrap: false,
                                style: AppTheme.dataValueStyle(context))),
                      ),
                      Text(unit, style: AppTheme.dataTitleStyle(context)),
                    ],
                  )),
        ),
      );
}
