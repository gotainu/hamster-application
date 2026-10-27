import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/models/hamster_avatar.dart';
import 'package:hamster_project/services/hamster_avatar_appearance_resolver.dart';
import 'package:hamster_project/viewmodels/measurement_input_view_model.dart';

void main() {
  const resolver = HamsterAvatarAppearanceResolver();
  test(
      'unknown profile uses existing avatar fallback without inventing recorded species',
      () {
    final profile = PetProfile.fromMap({'name': 'ハム'});
    expect(profile.species, '');
    expect(profile.hasAvatarIdentity, false);
    expect(
        resolver.resolve(profile).bodyType, HamsterAvatarBodyType.djungarian);
    expect(profile.species, '');
    expect(profile.birthday, isNull);
    expect(profile.birthdayPrecision, 'unknown');
  });
  test('explicit registered species keep their established avatar appearance',
      () {
    for (final entry in {
      'シリアン': HamsterAvatarBodyType.syrian,
      'ジャンガリアン': HamsterAvatarBodyType.djungarian,
      'ロボロフスキー': HamsterAvatarBodyType.roborovski
    }.entries) {
      final profile = PetProfile.fromMap({'name': 'ハム', 'species': entry.key});
      expect(resolver.resolve(profile).bodyType, entry.value);
      expect(profile.species, entry.key);
    }
  });
  test('legacy birthday certainty is preserved through avatar presentation',
      () {
    final profile = PetProfile.fromMap(
        {'name': 'ハム', 'birthday': '2026-01-01T00:00:00+09:00'});
    resolver.resolve(profile);
    expect(profile.birthdayPrecision, 'legacy_unspecified');
    expect(profile.subjectId, isNull);
  });
  test(
      'view model separates measured zero from missing and preserves saved precise timing choice',
      () {
    expect(MeasurementInputViewModel.formatDistance(0), '0 m');
    expect(MeasurementInputViewModel.formatDistance(null), '-');
    expect(
        MeasurementInputViewModel.timingChoice(
            {'timePrecision': 'instant', 'observedAt': '2026-10-12T03:00:00Z'}),
        'instant');
    expect(
        MeasurementInputViewModel.timingChoice({
          'timePrecision': 'unknown',
          'windowMeaning': 'selected_night_to_next_morning'
        }, activity: true),
        'night');
  });
}
