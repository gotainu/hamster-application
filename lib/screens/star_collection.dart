import 'package:flutter/material.dart';

import '../models/star_rewards_progress.dart';
import '../services/star_rewards_repo.dart';
import '../theme/app_theme.dart';

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
    final rewardsRepo = repo ??
        (progressStream == null || milestoneStream == null
            ? StarRewardsRepo()
            : null);
    return Scaffold(
      appBar: AppBar(title: const Text('星の累計')),
      body: StreamBuilder<StarRewardsProgress?>(
        stream: progressStream ?? rewardsRepo!.watchProgress(),
        builder: (context, progressSnapshot) {
          if (progressSnapshot.hasError) {
            return const Center(child: Text('累計を読み込めませんでした'));
          }
          final progress = progressSnapshot.data;
          if (progress == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 86,
                    color: Color(0xFFFFD782),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${progress.total}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.overallConditionForeground(context),
                        ),
                  ),
                  const Text('集めた星'),
                  const SizedBox(height: 28),
                  StreamBuilder<bool>(
                    stream: milestoneStream ??
                        rewardsRepo!.watchFiftyStarMilestone(),
                    builder: (context, milestoneSnapshot) {
                      if (milestoneSnapshot.data != true) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFD782).withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                const Color(0xFFFFD782).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '星が合計50個貯まりました！',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
