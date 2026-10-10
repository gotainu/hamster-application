import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/owner_profile.dart';
import '../services/owner_profile_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/prefecture_map_preview.dart';
import '../widgets/hamster_feedback_popup.dart';

class OwnerProfileEditScreen extends StatefulWidget {
  const OwnerProfileEditScreen({
    super.key,
    this.closeOnSave = false,
  });

  /// Setup flow needs a result to advance; ordinary profile editing should
  /// remain on this screen so the save confirmation is visible.
  final bool closeOnSave;

  @override
  State<OwnerProfileEditScreen> createState() => _OwnerProfileEditScreenState();
}

class _OwnerProfileEditScreenState extends State<OwnerProfileEditScreen> {
  static const _prefectures = [
    '北海道',
    '青森県',
    '岩手県',
    '宮城県',
    '秋田県',
    '山形県',
    '福島県',
    '茨城県',
    '栃木県',
    '群馬県',
    '埼玉県',
    '千葉県',
    '東京都',
    '神奈川県',
    '新潟県',
    '富山県',
    '石川県',
    '福井県',
    '山梨県',
    '長野県',
    '岐阜県',
    '静岡県',
    '愛知県',
    '三重県',
    '滋賀県',
    '京都府',
    '大阪府',
    '兵庫県',
    '奈良県',
    '和歌山県',
    '鳥取県',
    '島根県',
    '岡山県',
    '広島県',
    '山口県',
    '徳島県',
    '香川県',
    '愛媛県',
    '高知県',
    '福岡県',
    '佐賀県',
    '長崎県',
    '熊本県',
    '大分県',
    '宮崎県',
    '鹿児島県',
    '沖縄県',
  ];
  static const _ageRanges = [
    '回答しない',
    '10代以下',
    '20代',
    '30代',
    '40代',
    '50代',
    '60代以上',
  ];

  final _repo = OwnerProfileRepo();
  final _municipalityController = TextEditingController();
  String? _prefecture;
  String _ageRange = '回答しない';
  int? _careYears;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _municipalityController.addListener(_refreshPreview);
    _load();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final profile = await _repo.fetch();
    if (!mounted) return;
    setState(() {
      _prefecture = profile?.prefecture;
      _municipalityController.text = profile?.municipality ?? '';
      _ageRange = profile?.ageRange ?? '回答しない';
      _careYears = profile?.hamsterCareYears;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.save(OwnerProfile(
        prefecture: _prefecture,
        municipality: _municipalityController.text,
        ageRange: _ageRange == '回答しない' ? null : _ageRange,
        hamsterCareYears: _careYears,
      ));
      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: '飼い主のプロフィールを保存しました。');
      if (widget.closeOnSave) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      HamsterFeedbackPopup.show(
        context,
        message: 'プロフィールを保存できませんでした。もう一度お試しください。',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _municipalityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('飼い主のプロフィール'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 112, 20, 40),
                  children: [
                    Text(
                      '見守りを、あなたの地域へ。',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryText(context),
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '地域の天気や、あなたの経験をこれからの振り返りに活かします。すべて後から変更できます。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.secondaryText(context),
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 20),
                    PrefectureMapPreview(
                      prefecture: _prefecture,
                      municipality: _municipalityController.text,
                    ),
                    const SizedBox(height: 26),
                    _ProfileSection(
                      icon: Icons.location_on_rounded,
                      title: '住んでいる地域',
                      subtitle: '選ぶと日本地図にもすぐ反映されます',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _prefecture,
                            decoration: const InputDecoration(
                              labelText: '都道府県',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            items: _prefectures
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _prefecture = value),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _municipalityController,
                            textInputAction: TextInputAction.next,
                            maxLength: 40,
                            buildCounter: (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) =>
                                null,
                            decoration: const InputDecoration(
                              labelText: '市区町村（任意）',
                              hintText: '例：大津市',
                              prefixIcon: Icon(Icons.location_city_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ProfileSection(
                      icon: Icons.auto_awesome_rounded,
                      title: '飼育のこと',
                      subtitle: '相談や振り返りを、あなたに合わせるための情報です',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _ageRange,
                            decoration: const InputDecoration(
                              labelText: '年齢層',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            items: _ageRanges
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(
                              () => _ageRange = value ?? '回答しない',
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int?>(
                            value: _careYears,
                            decoration: const InputDecoration(
                              labelText: 'ハムスターの飼育経験',
                              prefixIcon:
                                  Icon(Icons.workspace_premium_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: null, child: Text('回答しない')),
                              DropdownMenuItem(value: 0, child: Text('はじめて')),
                              DropdownMenuItem(value: 1, child: Text('1年')),
                              DropdownMenuItem(value: 2, child: Text('2年')),
                              DropdownMenuItem(value: 3, child: Text('3年')),
                              DropdownMenuItem(value: 5, child: Text('5年以上')),
                            ],
                            onChanged: (value) =>
                                setState(() => _careYears = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(_saving ? '保存中…' : 'このプロフィールを保存する'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? AppTheme.cardInnerDark.withValues(alpha: .88)
              : Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.accent.withValues(
              alpha: AppTheme.isDark(context) ? .18 : .12,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.accent),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryText(context),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}
