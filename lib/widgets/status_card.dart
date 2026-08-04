import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'shine_border.dart';

enum StatusCardLevel {
  neutral,
  good,
  caution,
  danger,
  unavailable,
}

/// 状態表現を「背景色・境界線・必要時のエフェクト」に集約する共通カード。
///
/// 状態名のチップや警告アイコンは、このWidgetでは表示しない。
/// 各画面は、ユーザーが次に理解・実行すべき内容だけをchildに渡す。
class StatusCard extends StatelessWidget {
  final StatusCardLevel level;
  final Widget child;
  final VoidCallback? onTap;
  final bool emphasize;
  final bool transparentBackground;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? strength;

  const StatusCard({
    super.key,
    required this.level,
    required this.child,
    this.onTap,
    this.emphasize = false,
    this.transparentBackground = false,
    this.radius = 26,
    this.padding = const EdgeInsets.all(20),
    this.strength,
  });

  Color _accent(BuildContext context) {
    switch (level) {
      case StatusCardLevel.good:
        return AppTheme.envGood;
      case StatusCardLevel.caution:
        return AppTheme.envCaution;
      case StatusCardLevel.danger:
        return AppTheme.envDanger;
      case StatusCardLevel.unavailable:
        return AppTheme.secondaryText(context);
      case StatusCardLevel.neutral:
        return AppTheme.tertiaryText(context);
    }
  }

  double get _defaultStrength {
    switch (level) {
      case StatusCardLevel.good:
        return 0.58;
      case StatusCardLevel.caution:
        return 0.78;
      case StatusCardLevel.danger:
        return 0.95;
      case StatusCardLevel.unavailable:
      case StatusCardLevel.neutral:
        return 0.42;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);

    Widget content = Container(
      width: double.infinity,
      padding: padding,
      decoration: transparentBackground
          ? AppTheme.transparentStatusCardDecoration(
              context,
              radius: radius,
            )
          : AppTheme.statusCardDecoration(
              context,
              accent: accent,
              strength: strength ?? _defaultStrength,
              radius: radius,
            ),
      child: child,
    );

    if (emphasize) {
      content = AnimatedShiningBorder(
        active: true,
        borderRadius: radius,
        borderWidth: 2,
        duration: const Duration(milliseconds: 2800),
        colors: [
          accent.withValues(alpha: 0.40),
          accent,
          Colors.white.withValues(alpha: 0.90),
          accent,
        ],
        child: content,
      );
    }

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
