// lib/models/breeding_environment.dart
class BreedingEnvironment {
  final String? cageWidth; // cm（フォームはStringで持ってるので合わせる）
  final String? cageDepth; // cm
  final String? cageHeight; // cm
  final String? beddingThickness; // cm
  final String? wheelDiameter; // cm
  final String temperatureControl; // 'エアコン' etc
  /// 選択式のグッズ。従来の [accessories] は互換表示用にも残す。
  final List<String> accessoryTags;

  /// 候補にないグッズを書ける任意メモ。
  final String? accessoryNote;
  final String? accessories;

  const BreedingEnvironment({
    this.cageWidth,
    this.cageDepth,
    this.cageHeight,
    this.beddingThickness,
    this.wheelDiameter,
    this.temperatureControl = 'エアコン',
    this.accessoryTags = const [],
    this.accessoryNote,
    this.accessories,
  });

  static BreedingEnvironment fromMap(Map<String, dynamic> m) {
    return BreedingEnvironment(
      cageWidth: m['cageWidth']?.toString(),
      cageDepth: m['cageDepth']?.toString(),
      cageHeight: m['cageHeight']?.toString(),
      beddingThickness: m['beddingThickness']?.toString(),
      wheelDiameter: m['wheelDiameter']?.toString(),
      temperatureControl: (m['temperatureControl'] ?? 'エアコン').toString(),
      accessoryTags: (m['accessoryTags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      accessoryNote: m['accessoryNote']?.toString(),
      accessories: m['accessories']?.toString(),
    );
  }

  Map<String, dynamic> toMapForSave() {
    return {
      'cageWidth': cageWidth,
      'cageDepth': cageDepth,
      'cageHeight': cageHeight,
      'beddingThickness': beddingThickness,
      'wheelDiameter': wheelDiameter,
      'temperatureControl': temperatureControl,
      'accessoryTags': accessoryTags,
      'accessoryNote': accessoryNote,
      'accessories': accessories,
    };
  }

  double? wheelDiameterAsDouble() =>
      double.tryParse((wheelDiameter ?? '').trim());
}
