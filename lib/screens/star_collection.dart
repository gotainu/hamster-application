import 'package:flutter/material.dart';

import '../models/star_rewards_progress.dart';
import '../services/star_rewards_repo.dart';
import '../widgets/collectible_glyph.dart';

class StarCollectionScreen extends StatelessWidget {
  final StarRewardsRepo? repo;
  final Stream<StarRewardsProgress?>? progressStream;
  final Stream<bool>? milestoneStream;

  const StarCollectionScreen({
    super.key,
    this.repo,
    this.progressStream,
    this.milestoneStream,
  });

  @override
  Widget build(BuildContext context) {
    final collectible = CollectibleCopy.of(context);
    final isSeed = collectible.isSeed;
    final foreground = isSeed ? const Color(0xFF2A211B) : Colors.white;
    final backgroundAsset = isSeed
        ? 'assets/images/theme/bg_default_day.webp'
        : 'assets/images/theme/bg_default_night.webp';
    final rewardsRepo = repo ??
        (progressStream == null || milestoneStream == null
            ? StarRewardsRepo()
            : null);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(collectible.collectionTitle),
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
            key: ValueKey('collection-background-${isSeed ? 'day' : 'night'}'),
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isSeed
                    ? [
                        const Color(0xFFF6FAFF).withValues(alpha: .34),
                        const Color(0xFFF6FAFF).withValues(alpha: .62),
                      ]
                    : [
                        const Color(0xFF070B14).withValues(alpha: .30),
                        const Color(0xFF070B14).withValues(alpha: .62),
                      ],
              ),
            ),
          ),
          StreamBuilder<StarRewardsProgress?>(
            stream: progressStream ?? rewardsRepo!.watchProgress(),
            builder: (context, progressSnapshot) {
              if (progressSnapshot.hasError) {
                return Center(
                  child: Text(
                    '累計を読み込めませんでした',
                    style: TextStyle(color: foreground),
                  ),
                );
              }
              final progress = progressSnapshot.data;
              if (progress == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _CollectionField(
                progress: progress,
                collectible: collectible,
                foreground: foreground,
                milestoneStream:
                    milestoneStream ?? rewardsRepo!.watchFiftyStarMilestone(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CollectionField extends StatelessWidget {
  const _CollectionField({
    required this.progress,
    required this.collectible,
    required this.foreground,
    required this.milestoneStream,
  });

  final StarRewardsProgress progress;
  final CollectibleCopy collectible;
  final Color foreground;
  final Stream<bool> milestoneStream;

  @override
  Widget build(BuildContext context) {
    final isSeed = collectible.isSeed;
    final collectedCount = progress.lifetimeEarned;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + kToolbarHeight + 18,
        20,
        32,
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          decoration: BoxDecoration(
            color: isSeed
                ? Colors.white.withValues(alpha: .83)
                : const Color(0xFF111A2B).withValues(alpha: .76),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSeed
                  ? const Color(0xFF493527).withValues(alpha: .22)
                  : Colors.white.withValues(alpha: .22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .20),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '$collectedCount${collectible.countUnit}',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                collectible.collectedLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground.withValues(alpha: .80),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (collectedCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 52),
            child: Text(
              '今日の記録で最初の${collectible.name}を集めましょう。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1,
            ),
            itemCount: collectedCount,
            itemBuilder: (context, index) => _CollectionItem(
              key: ValueKey('collected-item-$index'),
              index: index,
              isSeed: isSeed,
            ),
          ),
        const SizedBox(height: 24),
        StreamBuilder<bool>(
          stream: milestoneStream,
          builder: (context, milestoneSnapshot) {
            if (milestoneSnapshot.data != true) {
              return const SizedBox.shrink();
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: collectible.highlight(context).withValues(alpha: .20),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: collectible.highlight(context).withValues(alpha: .78),
                ),
              ),
              child: Text(
                collectible.milestoneLabel(50),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CollectionItem extends StatelessWidget {
  const _CollectionItem({
    super.key,
    required this.index,
    required this.isSeed,
  });

  final int index;
  final bool isSeed;

  @override
  Widget build(BuildContext context) {
    final rotation = ((index % 5) - 2) * .055;
    return Transform.rotate(
      angle: rotation,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSeed
              ? Colors.white.withValues(alpha: .60)
              : const Color(0xFF091426).withValues(alpha: .48),
          border: Border.all(
            color: isSeed
                ? const Color(0xFF65452D).withValues(alpha: .20)
                : Colors.white.withValues(alpha: .26),
          ),
        ),
        child: Center(
          child: CollectibleGlyph(filled: true, size: 42),
        ),
      ),
    );
  }
}
