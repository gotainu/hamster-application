import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/hamster_avatar.dart';
import '../models/health_assessment.dart';
import '../services/hamster_avatar_condition_resolver.dart';
import '../services/health_assessment_repo.dart';
import '../theme/app_theme.dart';

/// ライト／ダークテーマと最新の総合コンディションに応じて、
/// ハムスターの生息環境を感じる背景画像を共通描画します。
///
/// 背景の原因判定には、アバターと同じ
/// [HamsterAvatarConditionResolver] を使用します。
/// そのため、アバターの表情・原因バッジ・背景画像の意味が一致します。
///
/// 画像の読込に失敗した場合でも、背面の既存グラデーションが残るため、
/// 画面が空白になりません。
class AppHabitatBackground extends StatelessWidget {
  // 背景画像確認用の一時設定です。
  //
  // null:
  //   実際の健康評価に応じて自動選択
  //
  // 値を指定:
  //   デバッグビルド中だけ、その背景へ強制切替
  // 背景を確認するときだけ、nullを任意のHamsterAvatarCauseへ変更します。
  static const HamsterAvatarCause? _debugBackgroundCause = null;

  const AppHabitatBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  static final HealthAssessmentRepo _healthAssessmentRepo =
      HealthAssessmentRepo();
  static const HamsterAvatarConditionResolver _conditionResolver =
      HamsterAvatarConditionResolver();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HealthAssessment?>(
      stream: _healthAssessmentRepo.watchLatest(),
      builder: (context, snapshot) {
        final resolvedCause = _resolveCause(snapshot);

        final cause = kDebugMode && _debugBackgroundCause != null
            ? _debugBackgroundCause!
            : resolvedCause;
        final isDark = AppTheme.isDark(context);
        final assetPath = AppTheme.habitatBackgroundAsset(
          context,
          cause: cause,
        );
        final blurSigma = AppTheme.habitatBackgroundBlurSigma(context);

        final imageLayer = Transform.scale(
          scale: AppTheme.habitatBackgroundScale,
          child: Opacity(
            opacity: AppTheme.habitatBackgroundOpacity(context),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: AppTheme.habitatBackgroundAlignment(context),
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                  'Habitat background load failed: '
                  '$assetPath, $error',
                );
                return const SizedBox.expand();
              },
            ),
          ),
        );

        final processedImage = blurSigma <= 0.01
            ? imageLayer
            : ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: imageLayer,
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            // 画像が未配置・読込失敗でも維持される安全な背景です。
            DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
              ),
            ),
            RepaintBoundary(
              child: AnimatedSwitcher(
                duration: AppTheme.habitatBackgroundTransitionDuration,
                switchInCurve: AppTheme.habitatBackgroundTransitionCurve,
                switchOutCurve: AppTheme.habitatBackgroundTransitionCurve,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<String>(assetPath),
                  child: processedImage,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.habitatReadabilityOverlay(context),
              ),
            ),
            child,
          ],
        );
      },
    );
  }

  HamsterAvatarCause _resolveCause(
    AsyncSnapshot<HealthAssessment?> snapshot,
  ) {
    // 初回読込中に「データ不足」の画像が一瞬表示されるのを防ぎます。
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return HamsterAvatarCause.none;
    }

    // 通信エラー時は意味の異なる警告画像へ切り替えず、標準背景を保ちます。
    if (snapshot.hasError) {
      debugPrint(
        'Health assessment background stream failed: ${snapshot.error}',
      );
      return HamsterAvatarCause.none;
    }

    return _conditionResolver
        .resolve(
          assessment: snapshot.data,
        )
        .cause;
  }
}
