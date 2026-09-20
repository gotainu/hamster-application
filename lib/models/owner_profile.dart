import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerProfile {
  const OwnerProfile({
    required this.prefecture,
    required this.municipality,
    required this.ageRange,
    required this.hamsterCareYears,
  });

  final String? prefecture;
  final String? municipality;
  final String? ageRange;
  final int? hamsterCareYears;

  factory OwnerProfile.fromMap(Map<String, dynamic> map) => OwnerProfile(
        prefecture: map['prefecture'] as String?,
        municipality: map['municipality'] as String?,
        ageRange: map['ageRange'] as String?,
        hamsterCareYears: (map['hamsterCareYears'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMapForSave() => {
        'prefecture': prefecture?.trim(),
        'municipality': municipality?.trim(),
        'ageRange': ageRange,
        'hamsterCareYears': hamsterCareYears,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
