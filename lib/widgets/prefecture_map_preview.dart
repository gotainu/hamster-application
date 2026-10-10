import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// CC0の都道府県SVGを用い、選択された地域を地図上で光らせる部品。
class PrefectureMapPreview extends StatefulWidget {
  const PrefectureMapPreview({
    super.key,
    required this.prefecture,
    required this.municipality,
  });

  final String? prefecture;
  final String municipality;

  @override
  State<PrefectureMapPreview> createState() => _PrefectureMapPreviewState();
}

class _PrefectureMapPreviewState extends State<PrefectureMapPreview> {
  late final Future<String> _svgFuture;

  @override
  void initState() {
    super.initState();
    _svgFuture =
        rootBundle.loadString('assets/maps/deformed-japan-prefecture-map.svg');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final prefecture = widget.prefecture;
    final municipality = widget.municipality.trim();
    return Container(
      height: 286,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1B2940), Color(0xFF101725)]
              : const [Color(0xFFE8F2FF), Color(0xFFF9FBFF)],
        ),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: isDark ? .34 : .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prefecture ?? 'あなたの地域',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryText(context),
                      ),
                ),
              ),
              if (municipality.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.envGood.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      municipality,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.envGood,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            prefecture == null
                ? '都道府県を選ぶと、この地図に地域が現れます。'
                : municipality.isEmpty
                    ? '選択した都道府県をハイライトしています。'
                    : '市区町村は天気連携に保存されます。地図は都道府県を表示中です。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<String>(
              future: _svgFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Semantics(
                  label: prefecture == null ? '日本地図' : '$prefectureが選択された日本地図',
                  child: SvgPicture.string(
                    colorizePrefectureMapSvg(
                      snapshot.data!,
                      prefecture,
                      isDark: isDark,
                    ),
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// SVGのstyle属性はflutter_svgの描画処理で常に優先されるとは限らない。
/// 対象のpathから既存の色指定を取り除き、直接属性として差し替える。
String colorizePrefectureMapSvg(
  String source,
  String? prefecture, {
  required bool isDark,
}) {
  final defaultFill = isDark ? '#6E87B0' : '#5275A8';
  final base = source
      .replaceAll('fill="white"', 'fill="$defaultFill" fill-opacity="0.43"')
      .replaceAll('stroke="black"', 'stroke="#A9C8F6" stroke-opacity="0.56"');
  final code = _prefectureCodes[prefecture];
  if (code == null) return base;

  final id = 'area_${code.toString().padLeft(3, '0')}';
  final selectedPath = RegExp('<path[^>]*id="$id"[^>]*/>');
  return base.replaceFirstMapped(selectedPath, (match) {
    var path = match.group(0)!;
    for (final attribute in const [
      'fill',
      'fill-opacity',
      'stroke',
      'stroke-opacity',
      'stroke-width',
      'style',
    ]) {
      path = path.replaceAll(RegExp('\\s$attribute="[^"]*"'), '');
    }
    return path.replaceFirst(
      '/>',
      ' fill="#72F5C3" fill-opacity="1" stroke="#FFFFFF" '
          'stroke-width="12" stroke-opacity="1"/>',
    );
  });
}

const Map<String, int> _prefectureCodes = {
  '北海道': 1,
  '青森県': 2,
  '岩手県': 3,
  '宮城県': 4,
  '秋田県': 5,
  '山形県': 6,
  '福島県': 7,
  '茨城県': 8,
  '栃木県': 9,
  '群馬県': 10,
  '埼玉県': 11,
  '千葉県': 12,
  '東京都': 13,
  '神奈川県': 14,
  '新潟県': 15,
  '富山県': 16,
  '石川県': 17,
  '福井県': 18,
  '山梨県': 19,
  '長野県': 20,
  '岐阜県': 21,
  '静岡県': 22,
  '愛知県': 23,
  '三重県': 24,
  '滋賀県': 25,
  '京都府': 26,
  '大阪府': 27,
  '兵庫県': 28,
  '奈良県': 29,
  '和歌山県': 30,
  '鳥取県': 31,
  '島根県': 32,
  '岡山県': 33,
  '広島県': 34,
  '山口県': 35,
  '徳島県': 36,
  '香川県': 37,
  '愛媛県': 38,
  '高知県': 39,
  '福岡県': 40,
  '佐賀県': 41,
  '長崎県': 42,
  '熊本県': 43,
  '大分県': 44,
  '宮崎県': 45,
  '鹿児島県': 46,
  '沖縄県': 47,
};
