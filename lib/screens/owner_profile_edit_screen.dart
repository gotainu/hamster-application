import 'package:flutter/material.dart';

import '../models/owner_profile.dart';
import '../services/owner_profile_repo.dart';
import '../theme/app_theme.dart';

class OwnerProfileEditScreen extends StatefulWidget {
  const OwnerProfileEditScreen({super.key});

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
    '60代以上'
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
    _load();
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
    await _repo.save(OwnerProfile(
      prefecture: _prefecture,
      municipality: _municipalityController.text,
      ageRange: _ageRange == '回答しない' ? null : _ageRange,
      hamsterCareYears: _careYears,
    ));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _municipalityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('飼い主のプロフィール'), centerTitle: true),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('あなたに合った見守りのために',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('すべて任意です。後から変更できます。',
                      style: TextStyle(color: AppTheme.secondaryText(context))),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _prefecture,
                    decoration: const InputDecoration(labelText: '都道府県'),
                    items: _prefectures
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _prefecture = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _municipalityController,
                      decoration: const InputDecoration(labelText: '市区町村')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _ageRange,
                    decoration: const InputDecoration(labelText: '年齢層'),
                    items: _ageRanges
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _ageRange = value ?? '回答しない'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: _careYears,
                    decoration: const InputDecoration(labelText: 'ハムスターの飼育経験'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('回答しない')),
                      DropdownMenuItem(value: 0, child: Text('はじめて')),
                      DropdownMenuItem(value: 1, child: Text('1年')),
                      DropdownMenuItem(value: 2, child: Text('2年')),
                      DropdownMenuItem(value: 3, child: Text('3年')),
                      DropdownMenuItem(value: 5, child: Text('5年以上')),
                    ],
                    onChanged: (value) => setState(() => _careYears = value),
                  ),
                  const SizedBox(height: 30),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存する'),
                  ),
                ],
              ),
      );
}
