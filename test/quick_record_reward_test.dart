import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/widgets/quick_record_reward.dart';
import 'package:hamster_project/widgets/hamster_avatar_view.dart';
import 'package:hamster_project/models/hamster_avatar.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/theme/app_theme.dart';

class _RewardAssetBundle extends CachingAssetBundle {
  _RewardAssetBundle(this.missing);
  final Set<String> missing;

  @override
  Future<ByteData> load(String key) {
    if (missing.contains(key)) {
      throw FlutterError('Missing reward avatar fixture: $key');
    }
    return rootBundle.load(key);
  }
}

Future<void> _rewardFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('activity reward formats meters and kilometers', () {
    final meters = QuickRecordRewardData.activity(
      rotations: 613,
      distanceMeters: 481,
    );
    final kilometers = QuickRecordRewardData.activity(
      rotations: 2400,
      distanceMeters: 1280,
    );

    expect(meters.value, '481 m');
    expect(kilometers.value, '1.28 km');
    expect(meters.progressLabel, '活動記録を保存');
  });

  test('weight reward preserves one decimal place when needed', () {
    expect(QuickRecordRewardData.weight(105).value, '105g');
    expect(QuickRecordRewardData.weight(105.4).value, '105.4g');
  });

  testWidgets('reward explains value and offers a next action', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickRecordRewardView(
            reward: QuickRecordRewardData.activity(
              rotations: 613,
              distanceMeters: 481,
            ),
            onContinue: () => continued = true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('記録が育ちました'), findsOneWidget);
    expect(find.text('481 m'), findsOneWidget);
    expect(find.text('活動量の比較データが増えました'), findsOneWidget);

    await tester.tap(find.text('ほかも記録'));
    expect(continued, isTrue);
  });
  for (final appearance in [
    (species: 'シリアン', color: 'ブラック・濃色系', directory: 'syrian/dark'),
    (species: 'ジャンガリアン', color: 'ブルーサファイア系', directory: 'djungarian/sapphire'),
    (species: 'ロボロフスキー', color: 'パイド', directory: 'roborovski/pied'),
  ]) {
    testWidgets(
        'reward shows ${appearance.directory} happy with only golden glow',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: QuickRecordRewardView(
          petProfile: PetProfile(
              name: '確認用',
              birthday: null,
              species: appearance.species,
              color: appearance.color,
              imageUrl: null),
          reward: QuickRecordRewardData.condition(),
          onContinue: () {},
          onClose: () {},
        ),
      )));
      await _rewardFrames(tester);
      final avatar = find.byKey(const ValueKey('quick-record-reward-avatar'));
      final view = tester.widget<HamsterAvatarView>(avatar);
      expect(view.presentation.condition, HamsterAvatarCondition.happy);
      expect(view.presentation.assetCandidates, [
        'assets/avatars/${appearance.directory}/happy.png',
        'assets/avatars/${appearance.directory}/stable.png',
      ]);
      expect(view.showBackdrop, isFalse);
      expect(view.showCauseBadge, isFalse);
      expect(view.presentation.animateBreathing, isFalse);
      expect(find.byType(ClipOval), findsNothing);
      final glow = tester.widget<Container>(
          find.byKey(const ValueKey('quick-record-reward-glow')));
      final decoration = glow.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      expect(decoration.color, isNull);
      expect(decoration.boxShadow!.single.color,
          AppTheme.envCaution.withValues(alpha: 0.24));
      expect(decoration.boxShadow!.single.blurRadius, 30);
      final image = tester.widget<Image>(
          find.descendant(of: avatar, matching: find.byType(Image)));
      expect((image.image as AssetImage).assetName,
          'assets/avatars/${appearance.directory}/happy.png');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('reward missing happy uses same appearance stable',
      (tester) async {
    const happy = 'assets/avatars/roborovski/pied/happy.png';
    const stable = 'assets/avatars/roborovski/pied/stable.png';
    await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
      bundle: _RewardAssetBundle({happy}),
      child: Scaffold(
          body: QuickRecordRewardView(
        petProfile: const PetProfile(
            name: '確認用',
            birthday: null,
            species: 'ロボロフスキー',
            color: 'パイド',
            imageUrl: null),
        reward: QuickRecordRewardData.weight(100),
        onContinue: () {},
        onClose: () {},
      )),
    )));
    await _rewardFrames(tester);
    final image = tester.widget<Image>(find.descendant(
        of: find.byKey(const ValueKey('quick-record-reward-avatar')),
        matching: find.byType(Image)));
    expect((image.image as AssetImage).assetName, stable);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
