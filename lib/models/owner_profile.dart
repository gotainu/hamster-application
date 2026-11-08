import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerProfile {
  const OwnerProfile({
    required this.prefecture,
    required this.municipality,
    required this.ageRange,
    required this.hamsterCareYears,
    String? displayName,
  }) : _displayName = displayName;

  final String? _displayName;

  String? get displayName {
    final value = _displayName?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  final String? prefecture;
  final String? municipality;
  final String? ageRange;
  final int? hamsterCareYears;

  factory OwnerProfile.fromMap(Map<String, dynamic> map) => OwnerProfile(
        displayName: map['displayName'] is String
            ? map['displayName'] as String
            : null,
        prefecture: map['prefecture'] as String?,
        municipality: map['municipality'] as String?,
        ageRange: map['ageRange'] as String?,
        hamsterCareYears: (map['hamsterCareYears'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMapForSave() => {
        'displayName': displayName,
        'prefecture': prefecture?.trim(),
        'municipality': municipality?.trim(),
        'ageRange': ageRange,
        'hamsterCareYears': hamsterCareYears,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
