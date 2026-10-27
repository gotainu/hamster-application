// lib/models/pet_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PetProfile {
  final String name;
  final DateTime? birthday;
  final String species;
  final String? color;
  final String? imageUrl;
  final String? subjectId;
  final int revision;
  final String birthdayPrecision;
  final int profileHistoryRevision;

  const PetProfile({
    required this.name,
    required this.birthday,
    required this.species,
    required this.color,
    required this.imageUrl,
    this.subjectId,
    this.revision = 0,
    String? birthdayPrecision,
    this.profileHistoryRevision = 0,
  }) : birthdayPrecision = birthdayPrecision ??
            (birthday == null ? 'unknown' : 'legacy_unspecified');

  static PetProfile fromMap(Map<String, dynamic> m) {
    final b = m['birthday'];
    DateTime? birthday;
    if (b is Timestamp) birthday = b.toDate();
    if (b is String) birthday = DateTime.tryParse(b);

    return PetProfile(
      name: (m['name'] ?? '') as String,
      birthday: birthday,
      species: (m['species'] ?? '') as String,
      color: m['color'] as String?,
      imageUrl: m['imageUrl'] as String?,
      subjectId: m['subjectId'] as String?,
      revision: m['revision'] is int ? m['revision'] as int : 0,
      birthdayPrecision: m['birthdayPrecision'] as String?,
      profileHistoryRevision: m['profileHistoryRevision'] is int
          ? m['profileHistoryRevision'] as int
          : 0,
    );
  }

  String get displayName => name.trim().isEmpty ? 'ハムスター' : name.trim();

  bool get hasImage => imageUrl?.trim().isNotEmpty == true;

  bool get hasAvatarIdentity =>
      species.trim().isNotEmpty && color?.trim().isNotEmpty == true;

  Map<String, dynamic> toMapForSave() => {
        'name': name.trim(),
        'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
        'birthdayPrecision': birthdayPrecision,
        'species': species,
        'color': color,
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
