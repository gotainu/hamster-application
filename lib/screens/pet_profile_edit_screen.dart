// lib/screens/pet_profile_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/user_image_picker.dart';

import '../models/hamster_avatar.dart';
import '../models/pet_profile.dart';
import '../services/hamster_avatar_appearance_resolver.dart';
import '../services/hamster_avatar_asset_resolver.dart';
import '../services/pet_profile_repo.dart';
import '../widgets/hamster_avatar_view.dart';
import '../widgets/hamster_feedback_popup.dart';

class PetProfileEditScreen extends StatefulWidget {
  const PetProfileEditScreen({super.key, this.repo});
  final PetProfileRepo? repo;
  @override
  State<PetProfileEditScreen> createState() => _PetProfileEditScreenState();
}

class _PetProfileEditScreenState extends State<PetProfileEditScreen> {
  // ---------- state ----------
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();

  late final PetProfileRepo _repo;

  File? _pickedImageFile;
  String? _existingImageUrl; // 既存URL（プレビュー用）
  DateTime? _birthday;
  String _birthdayPrecision = 'unknown';
  PetProfile? _loadedProfile;

  String _selectedSpecies = 'シリアン';
  String? _selectedColor;
  bool _isLoading = false;
  bool _profileLoadFailed = false;
  bool _profilePending = false;

  static const _avatarAppearanceResolver = HamsterAvatarAppearanceResolver();
  static const _avatarAssetResolver = HamsterAvatarAssetResolver();

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? PetProfileRepo();
    _nameController.addListener(_refreshPreview);
    _fetchExistingData();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // ---------- data load ----------
  Future<void> _fetchExistingData() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _repo.fetchPendingProfile();
      final p = pending ?? await _repo.fetchMainPet();
      _profilePending = pending != null;
      _profileLoadFailed = false;
      if (!mounted) return;

      if (p == null) {
        // 未登録の場合は初期値のまま
        setState(() {
          _nameController.text = '';
          _birthday = null;
          _birthdayController.clear();
          _selectedSpecies = 'シリアン';
          _selectedColor = _avatarAppearanceResolver
              .defaultColorForSpecies(_selectedSpecies);
          _existingImageUrl = null;
        });
        return;
      }

      setState(() {
        _loadedProfile = p;
        _nameController.text = p.name;
        _birthday = p.birthday;
        _birthdayPrecision = p.birthdayPrecision;
        if (p.birthday != null) {
          final d = p.birthday!;
          _birthdayController.text =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        } else {
          _birthdayController.clear();
        }
        _selectedSpecies = p.species;
        _selectedColor = _avatarAppearanceResolver.normalizeColorForSelection(
          species: _selectedSpecies,
          color: p.color,
        );
        _existingImageUrl = p.imageUrl;
      });
    } catch (_) {
      if (mounted) setState(() => _profileLoadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- helpers ----------
  Future<void> _pickBirthday() async {
    if (_isLoading || _profilePending) return;
    final now = DateTime.now();
    final initialDate = _birthday ?? DateTime(now.year - 1);
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (!mounted) return;
    if (picked == null) return;

    setState(() {
      _birthday = picked;
      if (_birthdayPrecision == 'unknown') {
        _birthdayPrecision = 'legacy_unspecified';
      }
      _birthdayController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  // UserImagePicker から受け取る
  void _pickImage(File image) {
    if (_isLoading || _profilePending) return;
    setState(() {
      _pickedImageFile = image;
      // 新規選択時は既存URLをクリア（プレビューがローカル優先になる）
      _existingImageUrl = null;
    });
  }

  Future<void> _onDeleteImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isLoading || _profilePending) return;

    final urlToDelete = _existingImageUrl;

    try {
      // ★ Firestore直叩き禁止：Repo経由で imageUrl を消す
      _loadedProfile =
          await _repo.deleteImageUrl(expectedProfile: _loadedProfile);
      if (mounted) {
        setState(() {
          _pickedImageFile = null;
          _existingImageUrl = null;
        });
      }

      // Storage 側の実体も削除（任意：失敗しても握りつぶす）
      if (urlToDelete != null) {
        try {
          await FirebaseStorage.instance.refFromURL(urlToDelete).delete();
        } catch (_) {}
      }

      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: '画像を削除しました');
    } catch (_) {
      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: '画像の削除に失敗しました…');
    }
  }

  HamsterAvatarPresentation _avatarPreviewPresentation() {
    final appearance = _avatarAppearanceResolver.resolveFromValues(
      species: _selectedSpecies,
      color: _selectedColor,
    );

    return _avatarAssetResolver.resolve(
      appearance: appearance,
      conditionResult: const HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.stable,
        cause: HamsterAvatarCause.none,
        message: 'Homeでは、コンディションに応じて表情とポーズが変わります。',
        animateBreathing: true,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_isLoading || _profileLoadFailed) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    if (_profilePending) {
      try {
        await _repo.retryPending();
        if (mounted) {
          HamsterFeedbackPopup.show(context, message: '保存を確認しました');
          Navigator.pop(context, true);
        }
      } catch (_) {
        if (mounted) {
          HamsterFeedbackPopup.show(context,
              message: '保存を確認できませんでした。同じ内容で再送できます。');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    String? imageUrl = _existingImageUrl;

    // 画像アップロード（FirestoreではなくStorageなのでOK）
    if (_pickedImageFile != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('hamster_images')
            .child('$uid-main_pet.jpg');

        await ref.putFile(_pickedImageFile!);
        imageUrl = await ref.getDownloadURL();
      } catch (_) {
        if (mounted) {
          HamsterFeedbackPopup.show(context, message: '画像のアップロードに失敗しました');
          setState(() => _isLoading = false);
        }
        return;
      }
    }

    try {
      // ★ Firestore直叩き禁止：Repo経由で保存
      _loadedProfile = await _repo.saveMainPet(
        PetProfile(
          name: _nameController.text.trim(),
          birthday: _birthday,
          birthdayPrecision: _birthdayPrecision,
          species: _selectedSpecies,
          color: _selectedColor,
          imageUrl: imageUrl,
          subjectId: _loadedProfile?.subjectId,
          revision: _loadedProfile?.revision ?? 0,
          profileHistoryRevision: _loadedProfile?.profileHistoryRevision ?? 0,
        ),
      );

      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: 'ペット情報を変更しました！');
      Navigator.pop(context, true);
    } catch (_) {
      _profilePending = await _repo.pendingMutation() != null;
      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: '保存を確認できませんでした。入力は残しています。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelAttributeCorrection() async {
    final profile = _loadedProfile;
    if (profile?.subjectId == null || _isLoading || _profilePending) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final history = await _repo.readHistoryAt(
          subjectId: profile!.subjectId!, evaluationDateKey: day);
      final entries = history['revisions'] is List
          ? history['revisions'] as List
          : const [];
      final corrections = entries
          .whereType<Map>()
          .where((e) => e['kind'] == 'correction' && e['cancelled'] != true)
          .toList()
        ..sort(
            (a, b) => (b['revision'] as int).compareTo(a['revision'] as int));
      if (!mounted) return;
      if (corrections.isEmpty) {
        HamsterFeedbackPopup.show(context, message: '取り消せる属性の訂正はありません');
        return;
      }
      final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('直前の属性訂正を取り消しますか？'),
                  content: const Text('種類・生年月日の訂正を取り消します。後の訂正と履歴は残ります。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('戻る')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('取り消す'))
                  ]));
      if (yes != true) return;
      await _repo.cancelAttributeCorrection(profile,
          targetHistoryRevision: corrections.first['revision'] as int);
      if (mounted) await _fetchExistingData();
    } catch (_) {
      _profilePending = await _repo.pendingMutation() != null;
      if (mounted) {
        HamsterFeedbackPopup.show(context, message: '取消を確認できませんでした。入力は残しています。');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final speciesList = [
      if (_selectedSpecies.trim().isEmpty) '',
      ..._avatarAppearanceResolver.speciesOptionsForCurrent(_selectedSpecies),
    ];
    final colorList =
        _avatarAppearanceResolver.colorOptionsFor(_selectedSpecies);
    final selectedColor =
        colorList.contains(_selectedColor) ? _selectedColor : null;
    final avatarPreview = _avatarPreviewPresentation();
    final bgGradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

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
          title: Text('ペットプロフィール編集',
              style: Theme.of(context).textTheme.titleLarge),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Container(decoration: BoxDecoration(gradient: bgGradient)),
            Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 38),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.cardInnerDark
                        : AppTheme.cardInnerLight,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.19),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserImagePicker(
                          initialImageUrl: _existingImageUrl,
                          onPickImage: _pickImage,
                          onDelete: _onDeleteImage,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _nameController,
                          enabled: !_isLoading && !_profilePending,
                          decoration:
                              const InputDecoration(labelText: 'ハムスターの名前'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? '名前を入力してください'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _birthdayController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: '生年月日',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: _pickBirthday,
                          validator: (_) => _birthday == null &&
                                  _birthdayPrecision != 'unknown'
                              ? '生年月日を選択してください'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _birthdayPrecision,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: '生年月日の確かさ'),
                          items: const [
                            DropdownMenuItem(
                                value: 'date_only', child: Text('生年月日を確認している')),
                            DropdownMenuItem(
                                value: 'approximate_date',
                                child: Text('およその生年月日')),
                            DropdownMenuItem(
                                value: 'unknown', child: Text('生年月日は不明')),
                            DropdownMenuItem(
                                value: 'legacy_unspecified',
                                child: Text('以前の記録（確かさ未確認）'))
                          ],
                          onChanged: _isLoading || _profilePending
                              ? null
                              : (value) => setState(() {
                                    _birthdayPrecision = value!;
                                    if (value == 'unknown') {
                                      _birthday = null;
                                      _birthdayController.clear();
                                    }
                                  }),
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'ハムスターの種類'),
                          value: _selectedSpecies,
                          items: speciesList
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.isEmpty ? '種類は不明（未確認）' : s,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ))
                              .toList(),
                          onChanged: _isLoading || _profilePending
                              ? null
                              : (v) {
                                  setState(() {
                                    _selectedSpecies = v!;
                                    _selectedColor = _avatarAppearanceResolver
                                        .defaultColorForSpecies(
                                            _selectedSpecies);
                                  });
                                },
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: '毛色'),
                          value: selectedColor,
                          items: colorList
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ))
                              .toList(),
                          onChanged: _isLoading || _profilePending
                              ? null
                              : (v) => setState(() => _selectedColor = v),
                          validator: (v) => v == null ? '毛色を選択してください' : null,
                        ),
                        const SizedBox(height: 24),
                        _PetIdentityPreview(
                          name: _nameController.text.trim(),
                          birthday: _birthday,
                          species: _selectedSpecies.isEmpty
                              ? '不明'
                              : _selectedSpecies,
                          color: selectedColor ?? '未選択',
                          presentation: avatarPreview,
                        ),
                        const SizedBox(height: 22),
                        if (_profileLoadFailed)
                          TextButton(
                              onPressed: _fetchExistingData,
                              child: const Text('プロフィールを再読み込み')),
                        if (_profilePending)
                          const Text('プロフィールは同期待ちです。同じ内容で再送できます。'),
                        if (_loadedProfile?.subjectId != null &&
                            !_profilePending)
                          TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _cancelAttributeCorrection,
                              child: const Text('直前の属性訂正を取り消す')),
                        ElevatedButton(
                          onPressed: _profileLoadFailed ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 36, vertical: 16),
                            backgroundColor: AppTheme.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            _profilePending
                                ? '同じ内容を再送'
                                : _isLoading
                                    ? '保存中…'
                                    : '設定を保存',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PetIdentityPreview extends StatelessWidget {
  const _PetIdentityPreview({
    required this.name,
    required this.birthday,
    required this.species,
    required this.color,
    required this.presentation,
  });

  final String name;
  final DateTime? birthday;
  final String species;
  final String color;
  final HamsterAvatarPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final displayName = name.isEmpty ? 'これから名前をつける子' : name;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF23385A), Color(0xFF18243A)]
              : const [Color(0xFFDCEEFF), Color(0xFFF6FAFF)],
        ),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: isDark ? .38 : .20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: isDark ? .14 : .08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Homeでの姿',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryText(context),
                  ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 154,
            height: 154,
            child: HamsterAvatarView(
              presentation: presentation,
              size: 142,
              showDebugLabel: false,
              showBackdrop: false,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryText(context),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_ageLabel(birthday)} ・ コンディションにあわせて表情も変わります',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _PreviewMetric(label: '種類', value: species)),
              const SizedBox(width: 8),
              Expanded(child: _PreviewMetric(label: '毛色', value: color)),
            ],
          ),
        ],
      ),
    );
  }

  String _ageLabel(DateTime? birthday) {
    if (birthday == null) return '誕生日を選ぶと年齢が表示されます';
    final now = DateTime.now();
    var months = (now.year - birthday.year) * 12 + now.month - birthday.month;
    if (now.day < birthday.day) months--;
    if (months < 12) return '${months.clamp(0, 11)}か月';
    return '${months ~/ 12}歳${months % 12}か月';
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: AppTheme.isDark(context) ? .08 : .56,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryText(context),
                  ),
            ),
          ],
        ),
      );
}
