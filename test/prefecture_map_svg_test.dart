import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/widgets/prefecture_map_preview.dart';

void main() {
  const svg = '<svg><path id="area_011" fill="white" stroke="none"/>'
      '<path id="area_012" fill="white" stroke="none"/></svg>';

  test('writes selected prefecture colours as direct SVG attributes', () {
    final result = colorizePrefectureMapSvg(svg, '埼玉県', isDark: true);

    expect(
      result,
      contains(
        '<path id="area_011" fill="#72F5C3" fill-opacity="1" '
        'stroke="#FFFFFF" stroke-width="12" stroke-opacity="1"/>',
      ),
    );
    expect(result, isNot(contains('style=')));
    expect(result, contains('id="area_012" fill="#6E87B0"'));
  });
}
