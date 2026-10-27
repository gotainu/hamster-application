// lib/models/breeding_environment.dart
class BreedingEnvironment {
  final String? cageWidth; // cm（フォームはStringで持ってるので合わせる）
  final String? cageDepth; // cm
  final String? cageHeight; // cm
  final String? beddingThickness; // cm
  final String? wheelDiameter; // cm
  final String temperatureControl; // 'エアコン' etc
  /// The legacy display fallback is not evidence that a method was recorded.
  final bool temperatureControlRecorded;
  final int revision;
  final bool historyInitialized;

  /// 選択式のグッズ。従来の [accessories] は互換表示用にも残す。
  final List<String> accessoryTags;
  final bool accessoryTagsRecorded;

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
    this.temperatureControlRecorded = true,
    this.revision = 0,
    this.historyInitialized = false,
    this.accessoryTags = const [],
    this.accessoryTagsRecorded = true,
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
      temperatureControlRecorded: m['temperatureControl'] is String &&
          (m['temperatureControl'] as String).trim().isNotEmpty,
      revision: m['revision'] is int ? m['revision'] as int : 0,
      historyInitialized: m['environmentHistorySchemaVersion'] == 1,
      accessoryTags:
          (m['accessoryTags'] is List ? m['accessoryTags'] as List : const [])
              .whereType<String>()
              .toList(growable: false),
      accessoryTagsRecorded: m['accessoryTags'] is List &&
          (m['accessoryTags'] as List).every((value) => value is String),
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
      'temperatureControl':
          temperatureControlRecorded ? temperatureControl : null,
      if (accessoryTagsRecorded) 'accessoryTags': accessoryTags,
      'accessoryNote': accessoryNote,
      'accessories': accessories,
    };
  }

  double? wheelDiameterAsDouble() {
    final value = double.tryParse((wheelDiameter ?? '').trim());
    return value != null && value.isFinite && value > 0 ? value : null;
  }
}
