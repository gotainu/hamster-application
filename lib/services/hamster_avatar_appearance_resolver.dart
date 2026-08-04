import '../models/hamster_avatar.dart';
import '../models/pet_profile.dart';

class HamsterAvatarAppearanceResolver {
  const HamsterAvatarAppearanceResolver();

  static const selectableSpecies = <String>[
    'シリアン',
    'ジャンガリアン',
    'ロボロフスキー',
    'キャンベル',
  ];

  static const _colorOptions = <String, List<String>>{
    'シリアン': [
      'ゴールデン・茶系',
      'クリーム・淡色系',
      'ホワイト系',
      'ブラック・濃色系',
      '白黒・ダルメシアン系',
    ],
    'ジャンガリアン': [
      'ノーマルグレー系',
      'ブルーサファイア系',
      'パールホワイト系',
      'プディング・クリーム系',
    ],
    'ロボロフスキー': [
      'ノーマルブラウン系',
      'ホワイトフェイス・淡色系',
    ],
    'キャンベル': [
      'ノーマルグレー系',
      'ブルー・オパール系',
      'クリーム・イエロー系',
      'ホワイト系',
    ],
    // 既存ユーザーの読込互換用。新規選択肢には通常表示しない。
    'チャイニーズ': [
      'ノーマル',
      'ホワイト',
      'パイド',
      'アルビノ',
    ],
  };

  List<String> speciesOptionsForCurrent(String? currentSpecies) {
    final result = <String>[...selectableSpecies];
    final current = currentSpecies?.trim();
    if (current != null && current.isNotEmpty && !result.contains(current)) {
      result.add(current);
    }
    return result;
  }

  List<String> colorOptionsFor(String? species) {
    final normalized = species?.trim();
    return _colorOptions[normalized] ?? _colorOptions['ジャンガリアン']!;
  }

  String defaultColorForSpecies(String? species) =>
      colorOptionsFor(species).first;

  String normalizeColorForSelection({
    required String? species,
    required String? color,
  }) {
    final options = colorOptionsFor(species);
    final raw = color?.trim();
    if (raw == null || raw.isEmpty) return options.first;
    if (options.contains(raw)) return raw;

    final appearance = resolveFromValues(
      species: species,
      color: raw,
    );

    final mapped = _selectionLabel(
      species: species,
      variant: appearance.colorVariant,
    );
    return options.contains(mapped) ? mapped : options.first;
  }

  HamsterAvatarAppearance resolve(PetProfile? profile) {
    return resolveFromValues(
      species: profile?.species,
      color: profile?.color,
    );
  }

  HamsterAvatarAppearance resolveFromValues({
    required String? species,
    required String? color,
  }) {
    final sourceSpecies =
        species?.trim().isNotEmpty == true ? species!.trim() : 'ジャンガリアン';
    final sourceColor = color?.trim().isNotEmpty == true ? color!.trim() : null;
    final bodyType = _resolveBodyType(sourceSpecies);
    final colorVariant = _resolveColorVariant(
      bodyType: bodyType,
      species: sourceSpecies,
      color: sourceColor,
    );

    return HamsterAvatarAppearance(
      bodyType: bodyType,
      colorVariant: colorVariant,
      sourceSpecies: sourceSpecies,
      sourceColor: sourceColor,
    );
  }

  HamsterAvatarBodyType _resolveBodyType(String species) {
    if (species.contains('シリアン')) {
      return HamsterAvatarBodyType.syrian;
    }
    if (species.contains('ロボロフスキー')) {
      return HamsterAvatarBodyType.roborovski;
    }

    // キャンベルはジャンガリアン系アセットを共有する。
    // チャイニーズ・未知値も、アセット欠損を避けて同系統へフォールバックする。
    return HamsterAvatarBodyType.djungarian;
  }

  HamsterAvatarColorVariant _resolveColorVariant({
    required HamsterAvatarBodyType bodyType,
    required String species,
    required String? color,
  }) {
    final value = (color ?? '').toLowerCase();

    switch (bodyType) {
      case HamsterAvatarBodyType.syrian:
        // 「白」を含むため、ホワイト判定より先に白黒系を判定する。
        if (_containsAny(value, [
          'ダルメシアン',
          '白黒',
          'パンダ',
          'パイド',
          'dalmatian',
          'spotted',
          'piebald',
        ])) {
          return HamsterAvatarColorVariant.dalmatian;
        }
        if (_containsAny(value, ['ブラック', 'ダーク', '濃色', 'black'])) {
          return HamsterAvatarColorVariant.dark;
        }
        if (_containsAny(value, ['アルビノ', 'ホワイト', '白', 'white'])) {
          return HamsterAvatarColorVariant.white;
        }
        if (_containsAny(value, ['クリーム', '淡色', 'イエロー', 'cream'])) {
          return HamsterAvatarColorVariant.cream;
        }
        return HamsterAvatarColorVariant.golden;

      case HamsterAvatarBodyType.djungarian:
        if (_containsAny(value, [
          'ブルー',
          'サファイア',
          'オパール',
          'sapphire',
          'blue',
        ])) {
          return HamsterAvatarColorVariant.sapphire;
        }
        if (_containsAny(value, [
          'パール',
          'スノー',
          'アルビノ',
          'ホワイト',
          '白',
          'pearl',
          'white',
        ])) {
          return HamsterAvatarColorVariant.pearl;
        }
        if (_containsAny(value, [
          'プディング',
          'クリーム',
          'イエロー',
          'レッド',
          'cream',
          'yellow',
        ])) {
          return HamsterAvatarColorVariant.cream;
        }
        return HamsterAvatarColorVariant.normal;

      case HamsterAvatarBodyType.roborovski:
        if (_containsAny(value, [
          'ホワイト',
          '白顔',
          '淡色',
          'パイド',
          'アルビノ',
          'white',
        ])) {
          return HamsterAvatarColorVariant.whiteFace;
        }
        return HamsterAvatarColorVariant.normal;
    }
  }

  String _selectionLabel({
    required String? species,
    required HamsterAvatarColorVariant variant,
  }) {
    final value = species?.trim();

    if (value == 'シリアン') {
      switch (variant) {
        case HamsterAvatarColorVariant.cream:
          return 'クリーム・淡色系';
        case HamsterAvatarColorVariant.white:
          return 'ホワイト系';
        case HamsterAvatarColorVariant.dark:
          return 'ブラック・濃色系';
        case HamsterAvatarColorVariant.dalmatian:
          return '白黒・ダルメシアン系';
        default:
          return 'ゴールデン・茶系';
      }
    }

    if (value == 'ロボロフスキー') {
      return variant == HamsterAvatarColorVariant.whiteFace
          ? 'ホワイトフェイス・淡色系'
          : 'ノーマルブラウン系';
    }

    if (value == 'キャンベル') {
      switch (variant) {
        case HamsterAvatarColorVariant.sapphire:
          return 'ブルー・オパール系';
        case HamsterAvatarColorVariant.cream:
          return 'クリーム・イエロー系';
        case HamsterAvatarColorVariant.pearl:
        case HamsterAvatarColorVariant.white:
          return 'ホワイト系';
        default:
          return 'ノーマルグレー系';
      }
    }

    if (value == 'チャイニーズ') {
      switch (variant) {
        case HamsterAvatarColorVariant.pearl:
        case HamsterAvatarColorVariant.white:
        case HamsterAvatarColorVariant.whiteFace:
          return 'ホワイト';
        default:
          return 'ノーマル';
      }
    }

    switch (variant) {
      case HamsterAvatarColorVariant.sapphire:
        return 'ブルーサファイア系';
      case HamsterAvatarColorVariant.pearl:
      case HamsterAvatarColorVariant.white:
        return 'パールホワイト系';
      case HamsterAvatarColorVariant.cream:
        return 'プディング・クリーム系';
      default:
        return 'ノーマルグレー系';
    }
  }

  bool _containsAny(String value, List<String> candidates) {
    return candidates.any((candidate) => value.contains(candidate));
  }
}
