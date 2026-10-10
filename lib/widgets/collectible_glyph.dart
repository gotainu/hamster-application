import 'package:flutter/material.dart';

/// 昼夜の世界観にあわせて、記録で集めるものを表す部品。
/// 保存済みの報酬データは共通のまま、表示だけを切り替える。
class CollectibleCopy {
  const CollectibleCopy._({required this.isSeed});

  final bool isSeed;

  factory CollectibleCopy.of(BuildContext context) {
    return CollectibleCopy._(
      isSeed: Theme.of(context).brightness == Brightness.light,
    );
  }

  String get name => isSeed ? 'ひまわりの種' : '星';
  String get collectionTitle => '$nameの累計';
  String get dailyTitle => '今日の$name';
  String get collectedLabel => '集めた$name';
  String get countUnit => isSeed ? '粒' : '個';
  String milestoneLabel(int count) => '$nameが合計$count$countUnit貯まりました！';

  Color accent(BuildContext context) =>
      isSeed ? const Color(0xFF5B351C) : const Color(0xFFFFD782);

  Color highlight(BuildContext context) =>
      isSeed ? const Color(0xFFE8BD52) : const Color(0xFFFFD782);
}

class CollectibleGlyph extends StatelessWidget {
  const CollectibleGlyph({
    super.key,
    required this.filled,
    this.size = 52,
  });

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final collectible = CollectibleCopy.of(context);
    if (!collectible.isSeed) {
      return Icon(
        filled ? Icons.star_rounded : Icons.star_border_rounded,
        size: size,
        color: filled
            ? collectible.highlight(context)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: .48),
      );
    }

    return CustomPaint(
      size: Size.square(size),
      painter: _SunflowerSeedPainter(filled: filled),
    );
  }
}

class _SunflowerSeedPainter extends CustomPainter {
  const _SunflowerSeedPainter({required this.filled});

  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final seed = Path()
      ..moveTo(width * .5, height * .035)
      ..cubicTo(width * .80, height * .16, width * .91, height * .53,
          width * .64, height * .89)
      ..cubicTo(width * .57, height * .98, width * .43, height * .98,
          width * .36, height * .89)
      ..cubicTo(width * .09, height * .53, width * .20, height * .16,
          width * .5, height * .035)
      ..close();

    final shellColor = filled
        ? const Color(0xFF4A2D1A)
        : const Color(0xFF765942).withValues(alpha: .20);
    canvas.drawPath(
      seed,
      Paint()
        ..style = PaintingStyle.fill
        ..color = shellColor,
    );
    canvas.drawPath(
      seed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .065
        ..color = filled
            ? const Color(0xFF2C180F)
            : const Color(0xFF765942).withValues(alpha: .72),
    );

    if (!filled) return;

    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.shortestSide * .075
      ..color = const Color(0xFFE4C26E);
    final stripeHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.shortestSide * .020
      ..color = const Color(0xFFFFF0B3).withValues(alpha: .90);
    final stripes = [
      Path()
        ..moveTo(width * .39, height * .20)
        ..cubicTo(width * .31, height * .40, width * .34, height * .61,
            width * .43, height * .84),
      Path()
        ..moveTo(width * .51, height * .14)
        ..cubicTo(width * .45, height * .39, width * .49, height * .63,
            width * .51, height * .89),
      Path()
        ..moveTo(width * .63, height * .23)
        ..cubicTo(width * .70, height * .42, width * .66, height * .64,
            width * .57, height * .84),
    ];
    for (final stripe in stripes) {
      canvas.drawPath(stripe, stripePaint);
      canvas.drawPath(stripe, stripeHighlight);
    }
    canvas.drawCircle(
      Offset(width * .39, height * .28),
      size.shortestSide * .052,
      Paint()..color = Colors.white.withValues(alpha: .40),
    );
  }

  @override
  bool shouldRepaint(covariant _SunflowerSeedPainter oldDelegate) =>
      oldDelegate.filled != filled;
}
