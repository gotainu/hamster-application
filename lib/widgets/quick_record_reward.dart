import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_record_completion.dart';
import '../models/daily_star_progress.dart';
import '../screens/daily_stars.dart';
import '../theme/app_theme.dart';

enum QuickRecordRewardKind {
  activity,
  condition,
  weight,
}

class QuickRecordRewardData {
  final QuickRecordRewardKind kind;
  final String value;
  final String progressLabel;
  final String benefit;

  const QuickRecordRewardData({
    required this.kind,
    required this.value,
    required this.progressLabel,
    required this.benefit,
  });

  factory QuickRecordRewardData.activity({
    required int rotations,
    double? distanceMeters,
  }) {
    return QuickRecordRewardData(
      kind: QuickRecordRewardKind.activity,
      value: _formatDistance(distanceMeters, rotations),
      progressLabel: '活動記録を保存',
      benefit: '活動量の比較データが増えました',
    );
  }

  factory QuickRecordRewardData.condition() {
    return const QuickRecordRewardData(
      kind: QuickRecordRewardKind.condition,
      value: '今日の様子',
      progressLabel: '観察記録を保存',
      benefit: '次回の健康評価に反映されます',
    );
  }

  factory QuickRecordRewardData.weight(double weightGrams) {
    final weight = weightGrams == weightGrams.roundToDouble()
        ? weightGrams.toStringAsFixed(0)
        : weightGrams.toStringAsFixed(1);
    return QuickRecordRewardData(
      kind: QuickRecordRewardKind.weight,
      value: '${weight}g',
      progressLabel: '体重記録を保存',
      benefit: '体重の変化を追うデータが増えました',
    );
  }

  static String _formatDistance(double? meters, int rotations) {
    if (meters == null || meters <= 0) return '$rotations回';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }
}

class QuickRecordRewardView extends StatefulWidget {
  final QuickRecordRewardData reward;
  final VoidCallback onContinue;
  final VoidCallback onClose;
  final ValueListenable<DailyRecordCompletion?>? completionListenable;

  const QuickRecordRewardView({
    super.key,
    required this.reward,
    required this.onContinue,
    required this.onClose,
    this.completionListenable,
  });

  @override
  State<QuickRecordRewardView> createState() => _QuickRecordRewardViewState();
}

class _QuickRecordRewardViewState extends State<QuickRecordRewardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _entrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.62, curve: Curves.elasticOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) return;
    _animationStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _accent(BuildContext context) {
    return switch (widget.reward.kind) {
      QuickRecordRewardKind.activity => AppTheme.quickRecordGlow(context),
      QuickRecordRewardKind.condition => AppTheme.envGood,
      QuickRecordRewardKind.weight => AppTheme.envCaution,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);

    return Semantics(
      liveRegion: true,
      label: '記録が完了しました。${widget.reward.value}。${widget.reward.benefit}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _RewardSparklePainter(
                progress: _controller.value,
                accent: accent,
              ),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _entrance,
                child: Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.42),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.24),
                        blurRadius: 30,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'store_assets/icons/google_play_icon_512.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _entrance,
                child: Text(
                  '記録が育ちました',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.reward.value,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
                ),
                child: Text(
                  widget.reward.progressLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.completionListenable != null) ...[
                ValueListenableBuilder<DailyRecordCompletion?>(
                  valueListenable: widget.completionListenable!,
                  builder: (context, completion, _) {
                    if (completion == null) return const SizedBox.shrink();
                    return DailyStarsStrip(
                      progress: DailyStarProgress.fromCompletion(completion),
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],
              Text(
                widget.reward.benefit,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.secondaryText(context),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: widget.onContinue,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('ほかも記録'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: AppTheme.isDark(context)
                        ? const Color(0xFF071315)
                        : Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onClose,
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardSparklePainter extends CustomPainter {
  final double progress;
  final Color accent;

  const _RewardSparklePainter({
    required this.progress,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const particles = <Offset>[
      Offset(0.14, 0.16),
      Offset(0.28, 0.05),
      Offset(0.72, 0.06),
      Offset(0.87, 0.18),
      Offset(0.08, 0.38),
      Offset(0.92, 0.36),
      Offset(0.19, 0.52),
      Offset(0.81, 0.50),
    ];

    for (var index = 0; index < particles.length; index++) {
      final delay = index * 0.055;
      final localProgress = ((progress - delay) / 0.58).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final pulse = math.sin(localProgress * math.pi);
      final position = Offset(
        particles[index].dx * size.width,
        particles[index].dy * size.height - 18 * localProgress,
      );
      final paint = Paint()
        ..color = accent.withValues(alpha: 0.72 * pulse)
        ..style = PaintingStyle.fill;
      final radius = (index.isEven ? 4.0 : 2.7) * pulse;
      canvas.drawCircle(position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RewardSparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}
