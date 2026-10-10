import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 入力中の飼育環境を、保存前から確認できる2.5D模型。
///
/// 実寸の比率を保ちつつ、描画領域内へ必ず収める。床材と車輪も
/// ケージの実寸から求めた上限で扱うため、保存済みの旧データでも
/// 模型が領域外へはみ出さない。
class HabitatModelPreview extends StatefulWidget {
  const HabitatModelPreview({
    super.key,
    required this.cageWidthCm,
    required this.cageDepthCm,
    required this.cageHeightCm,
    required this.beddingCm,
    required this.wheelDiameterCm,
    required this.accessoryTags,
  });

  final double? cageWidthCm;
  final double? cageDepthCm;
  final double? cageHeightCm;
  final double? beddingCm;
  final double? wheelDiameterCm;
  final Set<String> accessoryTags;

  @override
  State<HabitatModelPreview> createState() => _HabitatModelPreviewState();
}

class _HabitatModelPreviewState extends State<HabitatModelPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late _HabitatShape _from;
  late _HabitatShape _to;

  @override
  void initState() {
    super.initState();
    _to = _HabitatShape.fromWidget(widget);
    _from = _to;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant HabitatModelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _HabitatShape.fromWidget(widget);
    if (next != _to) {
      _from = _HabitatShape.lerp(
        _from,
        _to,
        Curves.easeOutCubic.transform(_controller.value),
      );
      _to = next;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Semantics(
      label: '入力中の飼育環境の模型プレビュー',
      child: Container(
        height: 256,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF182E4C), Color(0xFF101827)]
                : const [Color(0xFFE7F4FF), Color(0xFFF7FAFF)],
          ),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: isDark ? .35 : .18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: isDark ? .16 : .10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'うちの子の住まい',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryText(context),
                  ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _HabitatModelPainter(
                    shape: _HabitatShape.lerp(
                      _from,
                      _to,
                      Curves.easeOutCubic.transform(_controller.value),
                    ),
                    isDark: isDark,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitatShape {
  const _HabitatShape({
    required this.widthCm,
    required this.depthCm,
    required this.heightCm,
    required this.beddingCm,
    required this.wheelDiameterCm,
    required this.accessoryTags,
  });

  factory _HabitatShape.fromWidget(HabitatModelPreview widget) {
    final width = _bounded(widget.cageWidthCm, fallback: 60, min: 10, max: 200);
    final depth = _bounded(widget.cageDepthCm, fallback: 35, min: 10, max: 150);
    final height =
        _bounded(widget.cageHeightCm, fallback: 35, min: 10, max: 150);
    final maxBedding = height * .60;
    final maxWheel = math.min(math.min(width, depth), height) * .78;

    return _HabitatShape(
      widthCm: width,
      depthCm: depth,
      heightCm: height,
      beddingCm: _bounded(
        widget.beddingCm,
        fallback: math.min(5, maxBedding),
        min: 0,
        max: maxBedding,
      ),
      wheelDiameterCm: _bounded(
        widget.wheelDiameterCm,
        fallback: math.min(20, maxWheel),
        min: 0,
        max: maxWheel,
      ),
      accessoryTags: widget.accessoryTags,
    );
  }

  static double _bounded(
    double? value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    final candidate = value != null && value.isFinite ? value : fallback;
    return candidate.clamp(min, max).toDouble();
  }

  final double widthCm;
  final double depthCm;
  final double heightCm;
  final double beddingCm;
  final double wheelDiameterCm;
  final Set<String> accessoryTags;

  static _HabitatShape lerp(_HabitatShape a, _HabitatShape b, double t) =>
      _HabitatShape(
        widthCm: _lerp(a.widthCm, b.widthCm, t),
        depthCm: _lerp(a.depthCm, b.depthCm, t),
        heightCm: _lerp(a.heightCm, b.heightCm, t),
        beddingCm: _lerp(a.beddingCm, b.beddingCm, t),
        wheelDiameterCm: _lerp(a.wheelDiameterCm, b.wheelDiameterCm, t),
        accessoryTags: t < .5 ? a.accessoryTags : b.accessoryTags,
      );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) =>
      other is _HabitatShape &&
      widthCm == other.widthCm &&
      depthCm == other.depthCm &&
      heightCm == other.heightCm &&
      beddingCm == other.beddingCm &&
      wheelDiameterCm == other.wheelDiameterCm &&
      _sameTags(accessoryTags, other.accessoryTags);

  @override
  int get hashCode => Object.hash(
        widthCm,
        depthCm,
        heightCm,
        beddingCm,
        wheelDiameterCm,
        Object.hashAll(accessoryTags),
      );

  static bool _sameTags(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

class _HabitatModelPainter extends CustomPainter {
  const _HabitatModelPainter({required this.shape, required this.isDark});

  final _HabitatShape shape;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    const horizontalMargin = 10.0;
    const verticalMargin = 6.0;
    const labelHeight = 16.0;
    final usableWidth = math.max(1, size.width - horizontalMargin * 2);
    final usableHeight =
        math.max(1, size.height - verticalMargin * 2 - labelHeight);

    // 奥行きを(0.8, -0.6)へ投影することで、横幅と奥行きが同じとき
    // 底面の二辺が同じ表示長になる、等角投影に近い形を作る。
    final horizontalScale = usableWidth / (shape.widthCm + shape.depthCm * .8);
    final verticalScale = usableHeight / (shape.heightCm + shape.depthCm * .6);
    final scale = math.min(horizontalScale, verticalScale);
    final frontWidth = shape.widthCm * scale;
    final frontHeight = shape.heightCm * scale;
    final depthVector = Offset(
      shape.depthCm * scale * .8,
      -shape.depthCm * scale * .6,
    );
    final front = Rect.fromLTWH(
      (size.width - frontWidth - depthVector.dx) / 2,
      verticalMargin - depthVector.dy,
      frontWidth,
      frontHeight,
    );

    final top = Path()
      ..moveTo(front.left, front.top)
      ..lineTo(front.left + depthVector.dx, front.top + depthVector.dy)
      ..lineTo(front.right + depthVector.dx, front.top + depthVector.dy)
      ..lineTo(front.right, front.top)
      ..close();
    final side = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right + depthVector.dx, front.top + depthVector.dy)
      ..lineTo(front.right + depthVector.dx, front.bottom + depthVector.dy)
      ..lineTo(front.right, front.bottom)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFFBFE9FF).withValues(alpha: .19),
                const Color(0xFF4F89CF).withValues(alpha: .08),
              ]
            : [
                Colors.white.withValues(alpha: .72),
                const Color(0xFF77B2E6).withValues(alpha: .16),
              ],
      ).createShader(front);
    final line = Paint()
      ..color = const Color(0xFF94D9FF).withValues(alpha: isDark ? .80 : .68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRect(front, fill);
    canvas.drawPath(top, fill);
    canvas.drawPath(side, fill);
    canvas.drawRect(front, line);
    canvas.drawPath(top, line);
    canvas.drawPath(side, line);

    final beddingHeight =
        (shape.beddingCm * scale).clamp(0, front.height * .60).toDouble();
    final bedding = Rect.fromLTWH(
      front.left + 4,
      front.bottom - beddingHeight - 4,
      math.max(1, front.width - 8),
      beddingHeight,
    );
    if (beddingHeight > 1) {
      final beddingPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFEAC47A), Color(0xFFB67A38)],
        ).createShader(bedding);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bedding, const Radius.circular(8)),
        beddingPaint,
      );
      _drawBeddingSpecks(canvas, bedding);
    }

    _drawWheel(canvas, front, beddingHeight, scale);
    _drawAccessories(canvas, front, bedding, shape.accessoryTags);
    _drawDimensionLabel(
      canvas,
      Offset(front.left, math.min(size.height - labelHeight, front.bottom + 5)),
      'W ${_format(shape.widthCm)} × D ${_format(shape.depthCm)} × H ${_format(shape.heightCm)} cm',
    );
    canvas.restore();
  }

  void _drawWheel(
      Canvas canvas, Rect front, double beddingHeight, double scale) {
    final openHeight = math.max(0, front.height - beddingHeight - 14);
    final displayDiameter = math.min(
      shape.wheelDiameterCm * scale * .86,
      math.min(front.width * .46, openHeight),
    );
    if (displayDiameter < 8) return;

    final radius = displayDiameter / 2;
    final center = Offset(
      front.right - radius - 10,
      front.bottom - beddingHeight - radius - 6,
    );
    final wheelPaint = Paint()
      ..color = AppTheme.accent.withValues(alpha: isDark ? .84 : .70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawCircle(center, radius, wheelPaint);
    canvas.drawCircle(center, radius * .20, wheelPaint);
    for (var index = 0; index < 6; index++) {
      final angle = index * math.pi / 3;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        wheelPaint..strokeWidth = 1.1,
      );
    }
  }

  void _drawBeddingSpecks(Canvas canvas, Rect bedding) {
    final paint = Paint()
      ..color = const Color(0xFF7B512E).withValues(alpha: .45);
    for (var index = 0; index < 18; index++) {
      final dx =
          bedding.left + 7 + ((index * 23) % math.max(1, bedding.width - 14));
      final dy =
          bedding.top + 5 + ((index * 11) % math.max(4, bedding.height - 9));
      canvas.drawCircle(Offset(dx, dy), 1.1, paint);
    }
  }

  void _drawAccessories(
    Canvas canvas,
    Rect front,
    Rect bedding,
    Set<String> tags,
  ) {
    final unit = math.min(front.width, front.height).clamp(12, 28).toDouble();
    final solid = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? .76 : .86);
    final outline = Paint()
      ..color = AppTheme.accent.withValues(alpha: .86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final floor = bedding.height > 1 ? bedding.top : front.bottom - 6;
    final top = front.top + 7;

    if (tags.contains('隠れ家')) {
      final house = Rect.fromLTWH(
          front.left + unit, floor - unit * 1.15, unit * 1.5, unit);
      final roof = Path()
        ..moveTo(house.left - 3, house.top + unit * .35)
        ..lineTo(house.center.dx, house.top - unit * .28)
        ..lineTo(house.right + 3, house.top + unit * .35)
        ..close();
      canvas.drawRect(house, solid);
      canvas.drawPath(roof, solid);
      canvas.drawCircle(
        Offset(house.center.dx, house.bottom - unit * .28),
        unit * .20,
        Paint()..color = const Color(0xFF26364E),
      );
    }
    if (tags.contains('砂場')) {
      final sandbox = Rect.fromLTWH(
        front.left + front.width * .42,
        floor - unit * .50,
        unit * 1.45,
        unit * .48,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(sandbox, Radius.circular(unit * .20)),
        solid,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(sandbox, Radius.circular(unit * .20)),
        outline,
      );
    }
    if (tags.contains('給水器')) {
      final x = front.right - unit * .78;
      canvas.drawLine(Offset(x, top), Offset(x, top + unit * 1.25),
          outline..strokeWidth = 2.2);
      canvas.drawCircle(Offset(x, top + unit * 1.42), unit * .15, solid);
    }
    if (tags.contains('トンネル')) {
      final tunnel = Rect.fromLTWH(
        front.left + front.width * .25,
        floor - unit * .70,
        unit * 1.45,
        unit * .86,
      );
      canvas.drawArc(tunnel, math.pi, math.pi, false, outline..strokeWidth = 3);
    }
    if (tags.contains('かじり木')) {
      canvas.drawLine(
        Offset(front.left + unit * .72, floor - unit * .18),
        Offset(front.left + unit * 2.0, floor - unit * .50),
        Paint()
          ..color = const Color(0xFFB97A46)
          ..strokeWidth = math.max(3, unit * .20)
          ..strokeCap = StrokeCap.round,
      );
    }
    if (tags.contains('登り台')) {
      final start = Offset(front.right - unit * 2.25, floor - unit * .12);
      final steps = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx + unit * .42, start.dy)
        ..lineTo(start.dx + unit * .42, start.dy - unit * .32)
        ..lineTo(start.dx + unit * .84, start.dy - unit * .32)
        ..lineTo(start.dx + unit * .84, start.dy - unit * .64)
        ..lineTo(start.dx + unit * 1.28, start.dy - unit * .64)
        ..lineTo(start.dx + unit * 1.28, start.dy)
        ..close();
      canvas.drawPath(steps, solid);
      canvas.drawPath(steps, outline);
    }
    if (tags.contains('温湿度計')) {
      final meter =
          Rect.fromLTWH(front.left + unit * .45, top, unit * .62, unit * .86);
      canvas.drawRRect(
        RRect.fromRectAndRadius(meter, Radius.circular(unit * .12)),
        solid,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(meter, Radius.circular(unit * .12)),
        outline,
      );
      canvas.drawCircle(
        Offset(meter.center.dx, meter.bottom - unit * .20),
        unit * .09,
        outline,
      );
    }
  }

  void _drawDimensionLabel(Canvas canvas, Offset offset, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF38506F),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    painter.paint(canvas, offset);
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  @override
  bool shouldRepaint(covariant _HabitatModelPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.isDark != isDark;
}
