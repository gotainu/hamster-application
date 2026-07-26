import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ScreenEdgeFade extends StatelessWidget {
  const ScreenEdgeFade({
    super.key,
    this.showBottom = true,
  });

  final bool showBottom;

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);

    // AppBar領域の内側だけでフェードを完結させます。
    final topExtent = mediaPadding.top + kToolbarHeight;

    // 浮遊ナビの領域内だけでフェードを完結させます。
    final bottomExtent = mediaPadding.bottom + 12 + 70;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              height: topExtent,
              child: const _ProgressiveEdgeFade(
                edge: _ScreenEdge.top,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedOpacity(
              opacity: showBottom ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: SizedBox(
                width: double.infinity,
                height: bottomExtent,
                child: const _ProgressiveEdgeFade(
                  edge: _ScreenEdge.bottom,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ScreenEdge {
  top,
  bottom,
}

class _ProgressiveEdgeFade extends StatelessWidget {
  const _ProgressiveEdgeFade({
    required this.edge,
  });

  final _ScreenEdge edge;

  bool get _isTop => edge == _ScreenEdge.top;

  @override
  Widget build(BuildContext context) {
    final outerTint = AppTheme.screenEdgeFadeTint(context);
    final clearFraction = _isTop
        ? AppTheme.screenEdgeTopClearFraction
        : AppTheme.screenEdgeBottomClearFraction;
    final effectEnd = 1 - clearFraction;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 互いに重ならない帯へ分割します。
              // コンテンツ側の端には透明・無ブラーの領域を残すため、
              // AppBar／浮遊ナビへ入る前のコンテンツには影響しません。
              _BlurBand(
                edge: edge,
                totalHeight: height,
                outerStart: 0.00 * effectEnd,
                outerEnd: 0.26 * effectEnd,
                sigma: 3.2,
              ),
              _BlurBand(
                edge: edge,
                totalHeight: height,
                outerStart: 0.26 * effectEnd,
                outerEnd: 0.51 * effectEnd,
                sigma: 2.35,
              ),
              _BlurBand(
                edge: edge,
                totalHeight: height,
                outerStart: 0.51 * effectEnd,
                outerEnd: 0.73 * effectEnd,
                sigma: 1.55,
              ),
              _BlurBand(
                edge: edge,
                totalHeight: height,
                outerStart: 0.73 * effectEnd,
                outerEnd: 0.90 * effectEnd,
                sigma: 0.85,
              ),
              _BlurBand(
                edge: edge,
                totalHeight: height,
                outerStart: 0.90 * effectEnd,
                outerEnd: effectEnd,
                sigma: 0.42,
              ),

              // AppBar側は30%、下側は6%を完全透明・無ブラーにします。
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:
                        _isTop ? Alignment.topCenter : Alignment.bottomCenter,
                    end: _isTop ? Alignment.bottomCenter : Alignment.topCenter,
                    colors: [
                      outerTint,
                      outerTint.withValues(alpha: 0.50),
                      outerTint.withValues(alpha: 0.15),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    stops: [
                      0.0,
                      0.45 * effectEnd,
                      0.78 * effectEnd,
                      effectEnd,
                      1.0,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BlurBand extends StatelessWidget {
  const _BlurBand({
    required this.edge,
    required this.totalHeight,
    required this.outerStart,
    required this.outerEnd,
    required this.sigma,
  });

  final _ScreenEdge edge;
  final double totalHeight;
  final double outerStart;
  final double outerEnd;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final bandHeight = totalHeight * (outerEnd - outerStart);

    final top = edge == _ScreenEdge.top
        ? totalHeight * outerStart
        : totalHeight * (1 - outerEnd);

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: bandHeight,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
          ),
          child: const ColoredBox(
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
