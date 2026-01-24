// lib/models/breeding_environment.dart
class BreedingEnvironment {
  final String? cageWidth; // cm（フォームはStringで持ってるので合わせる）
  final String? cageDepth; // cm
  final String? beddingThickness; // cm
  final String? wheelDiameter; // cm
  final String temperatureControl; // 'エアコン' etc
  final String? accessories;

  const BreedingEnvironment({
    this.cageWidth,
    this.cageDepth,
    this.beddingThickness,
    this.wheelDiameter,
    this.temperatureControl = 'エアコン',
    this.accessories,
  });

  static BreedingEnvironment fromMap(Map<String, dynamic> m) {
    return BreedingEnvironment(
      cageWidth: m['cageWidth']?.toString(),
      cageDepth: m['cageDepth']?.toString(),
      beddingThickness: m['beddingThickness']?.toString(),
      wheelDiameter: m['wheelDiameter']?.toString(),
      temperatureControl: (m['temperatureControl'] ?? 'エアコン').toString(),
      accessories: m['accessories']?.toString(),
    );
  }

  Map<String, dynamic> toMapForSave() {
    return {
      'cageWidth': cageWidth,
      'cageDepth': cageDepth,
      'beddingThickness': beddingThickness,
      'wheelDiameter': wheelDiameter,
      'temperatureControl': temperatureControl,
      'accessories': accessories,
    };
  }

  double? wheelDiameterAsDouble() =>
      double.tryParse((wheelDiameter ?? '').trim());
}
