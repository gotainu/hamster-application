import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/breeding_environment.dart';

void main() {
  group('BreedingEnvironment', () {
    test('keeps legacy accessories while saving selected tags and a note', () {
      const environment = BreedingEnvironment(
        cageWidth: '60',
        cageDepth: '35',
        cageHeight: '35',
        beddingThickness: '8',
        wheelDiameter: '21',
        accessoryTags: ['隠れ家', '砂場'],
        accessoryNote: 'コルクマット',
        accessories: '隠れ家・砂場・コルクマット',
      );

      expect(environment.toMapForSave(),
          containsPair('accessoryTags', ['隠れ家', '砂場']));
      expect(environment.toMapForSave(), containsPair('cageHeight', '35'));
      expect(
          environment.toMapForSave(), containsPair('accessoryNote', 'コルクマット'));
      expect(environment.toMapForSave(),
          containsPair('accessories', '隠れ家・砂場・コルクマット'));
    });

    test('loads existing documents that do not yet contain selected tags', () {
      final environment = BreedingEnvironment.fromMap(const {
        'cageWidth': '60',
        'temperatureControl': 'エアコン',
        'accessories': '隠れ家',
      });

      expect(environment.accessoryTags, isEmpty);
      expect(environment.accessoryNote, isNull);
      expect(environment.accessories, '隠れ家');
    });
  });
}
