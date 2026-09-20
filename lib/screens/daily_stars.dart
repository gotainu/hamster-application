import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/daily_record_completion.dart';
import '../models/daily_star_progress.dart';
import '../theme/app_theme.dart';

class DailyStarsScreen extends StatelessWidget {
  final ValueListenable<DailyRecordCompletion?> completionListenable;
  final Future<void> Function()? onRecord;

  const DailyStarsScreen({
    super.key,
    required this.completionListenable,
    this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日の星')),
      body: ValueListenableBuilder<DailyRecordCompletion?>(
        valueListenable: completionListenable,
        builder: (context, completion, _) {
          if (completion == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final progress = DailyStarProgress.fromCompletion(completion);
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 32),
            children: [
              Center(
                child: DailyStarsStrip(progress: progress),
              ),
              const SizedBox(height: 32),
              ...progress.slots.map((slot) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StarTaskTile(
                      slot: slot,
                      onTap: slot.kind == DailyStarSlotKind.openApp ||
                              onRecord == null
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              await onRecord!();
                            },
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class DailyStarsStrip extends StatelessWidget {
  final DailyStarProgress progress;
  final VoidCallback? onTap;
  final bool prominent;

  const DailyStarsStrip({
    super.key,
    required this.progress,
    this.onTap,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final stars = prominent
        ? _ProminentStarsRow(progress: progress)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slot in progress.slots)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _AnimatedStar(slot: slot),
                ),
            ],
          );

    return Semantics(
      button: onTap != null,
      label: '今日の星 ${progress.filledCount} / ${progress.slots.length}。詳しく見る',
      child: onTap == null
          ? stars
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(prominent ? 28 : 40),
                child: Padding(
                  padding: EdgeInsets.all(prominent ? 0 : 10),
                  child: stars,
                ),
              ),
            ),
    );
  }
}

class _ProminentStarsRow extends StatelessWidget {
  final DailyStarProgress progress;

  const _ProminentStarsRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final warmGold = const Color(0xFFFFD782);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppTheme.quickRecordObjectSurface(context),
            warmGold.withValues(alpha: 0.11),
            AppTheme.quickRecordObjectSurface(context),
          ],
        ),
        border: Border.all(color: warmGold.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final slot in progress.slots) _AnimatedStar(slot: slot, size: 80),
        ],
      ),
    );
  }
}

class _AnimatedStar extends StatelessWidget {
  final DailyStarSlot slot;
  final double size;

  const _AnimatedStar({required this.slot, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${slot.kind}-${slot.filled}'),
      tween: Tween(begin: slot.filled ? 0.72 : 1, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: _StarGlyph(filled: slot.filled, size: size),
    );
  }
}

class _StarGlyph extends StatelessWidget {
  final bool filled;
  final double size;

  const _StarGlyph({required this.filled, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final color = filled
        ? const Color(0xFFFFD782)
        : AppTheme.secondaryText(context).withValues(alpha: 0.5);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? color.withValues(alpha: 0.15)
            : AppTheme.quickRecordObjectSurface(context),
        border: Border.all(color: color.withValues(alpha: 0.46)),
        boxShadow: filled
            ? [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 20)]
            : null,
      ),
      child: Icon(
        filled ? Icons.star_rounded : Icons.star_border_rounded,
        size: size * 0.62,
        color: color,
      ),
    );
  }
}

class _StarTaskTile extends StatelessWidget {
  final DailyStarSlot slot;
  final VoidCallback? onTap;

  const _StarTaskTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: AppTheme.quickRecordObjectSurface(context),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.quickRecordObjectBorder(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    slot.filled
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFFFD782),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      slot.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(slot.filled
                      ? '記録済み'
                      : slot.optional
                          ? '任意'
                          : '未記録'),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
