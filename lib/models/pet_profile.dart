// lib/models/pet_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PetProfile {
  final String name;
  final DateTime? birthday;
  final String species;
  final String? color;
  final String? imageUrl;

  const PetProfile({
    required this.name,
    required this.birthday,
    required this.species,
    required this.color,
    required this.imageUrl,
  });

  static PetProfile fromMap(Map<String, dynamic> m) {
    final b = m['birthday'];
    DateTime? birthday;
    if (b is Timestamp) birthday = b.toDate();
    if (b is String) birthday = DateTime.tryParse(b);

    return PetProfile(
      name: (m['name'] ?? '') as String,
      birthday: birthday,
      species: (m['species'] ?? 'シリアン') as String,
      color: m['color'] as String?,
      imageUrl: m['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMapForSave() => {
        'name': name.trim(),
        'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
        'species': species,
        'color': color,
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
