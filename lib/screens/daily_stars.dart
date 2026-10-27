import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/daily_record_completion.dart';
import '../services/care_continuity_repo.dart';
import '../services/star_rewards_repo.dart';
import '../models/star_rewards_progress.dart';
import '../widgets/care_continuity_panel.dart';
import '../models/daily_star_progress.dart';
import '../theme/app_theme.dart';
import '../widgets/collectible_glyph.dart';

class DailyStarsScreen extends StatefulWidget {
  final ValueListenable<DailyRecordCompletion?> completionListenable;
  final Future<void> Function()? onRecord;
  final CareContinuitySource? continuitySource;
  final StarRewardsRepo? rewardsRepo;
  final Stream<StarRewardsProgress?>? rewardsProgressStream;

  const DailyStarsScreen({
    super.key,
    required this.completionListenable,
    this.onRecord,
    this.continuitySource,
    this.rewardsRepo,
    this.rewardsProgressStream,
  });

  @override
  State<DailyStarsScreen> createState() => _DailyStarsScreenState();
}

class _DailyStarsScreenState extends State<DailyStarsScreen> {
  late final CareContinuitySource _source;
  late final Stream<StarRewardsProgress?> _rewardsProgress;
  @override
  void initState() {
    super.initState();
    _source = widget.continuitySource ?? CareContinuityRepo();
    _rewardsProgress = widget.rewardsProgressStream ??
        (widget.rewardsRepo ?? StarRewardsRepo()).watchProgress();
  }

  void _showHelp(BuildContext context) {
    final copy = CollectibleCopy.of(context);
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('たくわえについて'),
                content: SingleChildScrollView(
                    child: Text(
                        '有効な記録を1回保存すると、その日の達成になります。アプリを開くだけでは達成になりません。\n\n'
                        'たくわえは、この期間に集めた${copy.name}の分です。2日続けて記録を休むと、翌日0時（日本時間）に空になります。\n\n'
                        '飼育記録、過去の達成、これまでに集めた${copy.name}は残ります。カレンダーは記録を受け付けた日で表示します。')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('閉じる'))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    final collectible = CollectibleCopy.of(context);
    final isSeed = collectible.isSeed;
    final foreground = AppTheme.primaryText(context);
    final backgroundAsset = isSeed
        ? 'assets/images/theme/bg_default_day.webp'
        : 'assets/images/theme/bg_default_night.webp';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('記録カレンダー'),
        actions: [
          IconButton(
              tooltip: 'たくわえについて',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => _showHelp(context))
        ],
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            backgroundAsset,
            key: ValueKey(
                'daily-collectible-background-${isSeed ? 'day' : 'night'}'),
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.careDetailOverlay(context),
            ),
          ),
          ValueListenableBuilder<DailyRecordCompletion?>(
            valueListenable: widget.completionListenable,
            builder: (context, completion, _) {
              if (completion == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final progress = DailyStarProgress.fromCompletion(completion);
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.careDetailPadding.left,
                  MediaQuery.paddingOf(context).top +
                      kToolbarHeight +
                      AppTheme.careDetailPadding.top,
                  AppTheme.careDetailPadding.right,
                  MediaQuery.paddingOf(context).bottom +
                      AppTheme.careDetailPadding.bottom,
                ),
                children: [
                  CareContinuityPanel(
                      source: _source,
                      progress: progress,
                      showCalendar: true,
                      pastAchievements: StreamBuilder<StarRewardsProgress?>(
                        stream: _rewardsProgress,
                        builder: (context, snapshot) => _CollectedRewards(
                            progress: snapshot.hasError ? null : snapshot.data),
                      ),
                      onRecord: widget.onRecord == null
                          ? null
                          : () => widget.onRecord!()),
                  const SizedBox(height: AppTheme.careSectionGap),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('今日の記録の内訳'),
                      children: progress.slots
                          .map((slot) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppTheme.careContentGap),
                                child: _StarTaskTile(
                                  slot: slot,
                                  onTap:
                                      slot.kind == DailyStarSlotKind.openApp ||
                                              widget.onRecord == null
                                          ? null
                                          : () async {
                                              Navigator.of(context).pop();
                                              await widget.onRecord!();
                                            },
                                ),
                              ))
                          .toList()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Displays saved permanent totals; continuity remains a separate server view.
class _CollectedRewards extends StatelessWidget {
  const _CollectedRewards({required this.progress});
  final StarRewardsProgress? progress;

  @override
  Widget build(BuildContext context) {
    final copy = CollectibleCopy.of(context);
    final saved = progress;
    if (saved == null) {
      return Text('累計は同期後に確認できます', style: AppTheme.dataCaptionStyle(context));
    }
    return Column(children: [
      for (final row in [
        ('これまで${copy.collectedLabel}', saved.lifetimeEarned),
        ('保有している${copy.name}', saved.total),
      ])
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.careContentGap),
          child: Row(children: [
            Expanded(
                child: Text(row.$1, style: AppTheme.dataBodyStyle(context))),
            Text('${row.$2}${copy.countUnit}',
                style: AppTheme.dataTitleStyle(context)),
          ]),
        ),
    ]);
  }
}

class DailyStarsStrip extends StatelessWidget {
  final DailyStarProgress progress;
  final VoidCallback? onTap;
  final bool prominent;
  final double glyphSize;

  const DailyStarsStrip({
    super.key,
    required this.progress,
    this.onTap,
    this.prominent = false,
    this.glyphSize = 52,
  });

  @override
  Widget build(BuildContext context) {
    final collectible = CollectibleCopy.of(context);
    final stars = prominent
        ? _ProminentStarsRow(progress: progress)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slot in progress.slots)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _AnimatedStar(slot: slot, size: glyphSize),
                ),
            ],
          );

    return Semantics(
      button: onTap != null,
      label:
          '${collectible.dailyTitle} ${progress.filledCount} / ${progress.slots.length}。詳しく見る',
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
    final collectible = CollectibleCopy.of(context);
    final warmGold = collectible.highlight(context);
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
          for (final slot in progress.slots)
            _AnimatedStar(slot: slot, size: 80),
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
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
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
    final collectible = CollectibleCopy.of(context);
    final color = filled
        ? collectible.accent(context)
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
      child: Center(
        child: CollectibleGlyph(
          filled: filled,
          size: size * .62,
        ),
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
                  CollectibleGlyph(
                    filled: slot.filled,
                    size: 25,
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
