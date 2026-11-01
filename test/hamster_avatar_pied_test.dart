import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/hamster_avatar.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/services/hamster_avatar_appearance_resolver.dart';
import 'package:hamster_project/services/hamster_avatar_asset_resolver.dart';
import 'package:hamster_project/services/pet_profile_repo.dart';
import 'package:hamster_project/widgets/hamster_avatar_view.dart';

class _MemoryPending implements ProfilePendingStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String owner) async => values[owner];
  @override
  Future<void> write(String owner, Map<String, dynamic> mutation) async {
    values[owner] = mutation;
  }

  @override
  Future<void> remove(String owner) async => values.remove(owner);
}

class _MissingAvatarBundle extends CachingAssetBundle {
  final requested = <String>[];
  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    throw FlutterError('No test avatar asset: $key');
  }
}

void main() {
  const resolver = HamsterAvatarAppearanceResolver();
  const assets = HamsterAvatarAssetResolver();

  test('roborovski options keep established colors and add independent pied',
      () {
    expect(resolver.colorOptionsFor('ロボロフスキー'),
        ['ノーマルブラウン系', 'ホワイトフェイス・淡色系', 'パイド']);
    expect(resolver.defaultColorForSpecies('ロボロフスキー'), 'ノーマルブラウン系');
    expect(HamsterAvatarColorVariant.whiteFace.assetKey, 'white_face');
    expect(HamsterAvatarColorVariant.pied.assetKey, 'pied');
  });

  test('explicit pied labels precede broad white-face matching', () {
    for (final color in [
      'パイド',
      'ホワイトパイド',
      '白顔・パイド',
      'pied',
      'white pied',
      'piebald'
    ]) {
      final appearance =
          resolver.resolveFromValues(species: 'ロボロフスキー', color: color);
      expect(appearance.colorVariant, HamsterAvatarColorVariant.pied,
          reason: color);
      expect(appearance.assetDirectory, 'roborovski/pied');
      expect(appearance.sourceColor, color);
      expect(
          resolver.normalizeColorForSelection(species: 'ロボロフスキー', color: color),
          'パイド');
    }
  });

  test(
      'ambiguous saved white-face values are neither inferred nor rewritten to pied',
      () {
    for (final color in [
      'ホワイトフェイス・淡色系',
      'ホワイト',
      '白顔',
      '淡色',
      'アルビノ',
      'white_face'
    ]) {
      final saved = <String, dynamic>{
        'name': 'ロボ',
        'species': 'ロボロフスキー',
        'color': color,
        'subjectId': 'existing_pet',
        'revision': 4
      };
      final profile = PetProfile.fromMap(saved);
      final appearance = resolver.resolve(profile);
      expect(appearance.colorVariant, HamsterAvatarColorVariant.whiteFace,
          reason: color);
      expect(appearance.assetDirectory, 'roborovski/white_face');
      expect(profile.color, color);
      expect(profile.toMapForSave()['color'], color);
      expect(saved['color'], color);
      expect(profile.subjectId, 'existing_pet');
      expect(profile.revision, 4);
    }
    expect(
        resolver
            .resolveFromValues(species: 'ロボロフスキー', color: 'ノーマルブラウン系')
            .colorVariant,
        HamsterAvatarColorVariant.normal);
  });

  test(
      'pied handling does not change other species color resolution or options',
      () {
    expect(
        resolver.resolveFromValues(species: 'シリアン', color: 'パイド').colorVariant,
        HamsterAvatarColorVariant.dalmatian);
    expect(
        resolver
            .resolveFromValues(species: 'シリアン', color: 'ブラック・濃色系')
            .assetDirectory,
        'syrian/dark');
    expect(
        resolver
            .resolveFromValues(species: 'ジャンガリアン', color: 'パイド')
            .colorVariant,
        HamsterAvatarColorVariant.normal);
    expect(
        resolver
            .resolveFromValues(species: 'キャンベル', color: 'ホワイト')
            .colorVariant,
        HamsterAvatarColorVariant.pearl);
    expect(
        resolver
            .resolveFromValues(species: 'チャイニーズ', color: 'パイド')
            .colorVariant,
        HamsterAvatarColorVariant.normal);
    expect(resolver.colorOptionsFor('シリアン'), isNot(contains('パイド')));
    expect(resolver.colorOptionsFor('ジャンガリアン'), isNot(contains('パイド')));
    expect(resolver.colorOptionsFor('キャンベル'), isNot(contains('パイド')));
  });

  test(
      'all pied states resolve to pied assets with same-appearance stable fallback',
      () {
    final appearance =
        resolver.resolveFromValues(species: 'ロボロフスキー', color: 'パイド');
    for (final state in HamsterAvatarCondition.values) {
      final presentation = assets.resolve(
          appearance: appearance,
          conditionResult: HamsterAvatarConditionResult(
              condition: state,
              cause: HamsterAvatarCause.none,
              message: '',
              animateBreathing: false));
      expect(presentation.assetCandidates, [
        'assets/avatars/roborovski/pied/${state.assetKey}.png',
        if (state != HamsterAvatarCondition.stable)
          'assets/avatars/roborovski/pied/stable.png',
      ]);
      expect(presentation.assetCandidates.any((p) => p.contains('white_face')),
          false);
    }
  });

  test(
      'selected pied saves through existing profile request and reads back unchanged',
      () async {
    final pending = _MemoryPending();
    final sent = <Map<String, dynamic>>[];
    Map<String, dynamic>? stored;
    final repo = PetProfileRepo(
        owner: () => 'local_fixture_owner',
        pendingStore: pending,
        read: () async => stored,
        submit: (request) async {
          sent.add(request);
          stored = {
            ...request['values'] as Map<String, dynamic>,
            'subjectId': 'same_pet',
            'revision': 8
          };
          return {
            'subjectId': 'same_pet',
            'revision': 8,
            'acceptedAt': '2026-10-31T08:00:00Z',
            'mutationId': request['mutationId']
          };
        });
    final selected =
        resolver.normalizeColorForSelection(species: 'ロボロフスキー', color: 'パイド');
    final saved = await repo.saveMainPet(PetProfile(
        name: 'ロボ',
        birthday: null,
        species: 'ロボロフスキー',
        color: selected,
        imageUrl: null,
        subjectId: 'same_pet',
        revision: 7));
    final reloaded = await repo.fetchMainPet();
    expect(sent.single['values']['color'], 'パイド');
    expect(sent.single['expectedSubjectId'], 'same_pet');
    expect(sent.single['expectedRevision'], 7);
    expect(saved.color, 'パイド');
    expect(reloaded!.color, 'パイド');
    expect(reloaded.subjectId, 'same_pet');
    expect(
        resolver.normalizeColorForSelection(
            species: reloaded.species, color: reloaded.color),
        'パイド');
    expect(resolver.resolve(reloaded).assetDirectory, 'roborovski/pied');
    expect(pending.values, isEmpty);
  });

  test(
      'legacy white-face remains white-face through existing save and reload path',
      () async {
    Map<String, dynamic>? stored;
    final repo = PetProfileRepo(
        owner: () => 'legacy_fixture_owner',
        pendingStore: _MemoryPending(),
        read: () async => stored,
        submit: (request) async {
          stored = {
            ...request['values'] as Map<String, dynamic>,
            'subjectId': 'existing_white_face',
            'revision': 4
          };
          return {
            'subjectId': 'existing_white_face',
            'revision': 4,
            'acceptedAt': '2026-10-31T08:00:00Z',
            'mutationId': request['mutationId']
          };
        });
    final profile = PetProfile.fromMap({
      'name': '白顔',
      'species': 'ロボロフスキー',
      'color': 'ホワイトフェイス・淡色系',
      'subjectId': 'existing_white_face',
      'revision': 3
    });
    await repo.saveMainPet(profile);
    final reloaded = await repo.fetchMainPet();
    expect(reloaded!.color, 'ホワイトフェイス・淡色系');
    expect(resolver.resolve(reloaded).assetDirectory, 'roborovski/white_face');
    expect(profile.color, 'ホワイトフェイス・淡色系');
  });

  testWidgets(
      'missing pied artwork keeps existing pets-icon fallback without white-face substitution',
      (tester) async {
    final bundle = _MissingAvatarBundle();
    final presentation = assets.resolve(
        appearance:
            resolver.resolveFromValues(species: 'ロボロフスキー', color: 'パイド'),
        conditionResult: const HamsterAvatarConditionResult(
            condition: HamsterAvatarCondition.happy,
            cause: HamsterAvatarCause.none,
            message: '',
            animateBreathing: false));
    await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
            bundle: bundle,
            child: HamsterAvatarView(
                presentation: presentation, showBackdrop: false))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    expect(
        bundle.requested,
        containsAllInOrder([
          'assets/avatars/roborovski/pied/happy.png',
          'assets/avatars/roborovski/pied/stable.png',
        ]));
    expect(bundle.requested.any((p) => p.contains('white_face')), false);
    expect(tester.takeException(), isNull);
  });
}
