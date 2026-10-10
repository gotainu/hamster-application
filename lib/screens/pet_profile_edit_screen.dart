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
  const PetProfileEditScreen({super.key});
  @override
  State<PetProfileEditScreen> createState() => _PetProfileEditScreenState();
}

class _PetProfileEditScreenState extends State<PetProfileEditScreen> {
  // ---------- state ----------
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();

  final _repo = PetProfileRepo();

  File? _pickedImageFile;
  String? _existingImageUrl; // 既存URL（プレビュー用）
  DateTime? _birthday;

  String _selectedSpecies = 'シリアン';
  String? _selectedColor;
  bool _isLoading = false;

  static const _avatarAppearanceResolver = HamsterAvatarAppearanceResolver();
  static const _avatarAssetResolver = HamsterAvatarAssetResolver();

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
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
    final p = await _repo.fetchMainPet(); // ★ Firestore直叩き禁止：Repo経由
    if (!mounted) return;

    if (p == null) {
      // 未登録の場合は初期値のまま
      setState(() {
        _nameController.text = '';
        _birthday = null;
        _birthdayController.clear();
        _selectedSpecies = 'シリアン';
        _selectedColor =
            _avatarAppearanceResolver.defaultColorForSpecies(_selectedSpecies);
        _existingImageUrl = null;
      });
      return;
    }

    setState(() {
      _nameController.text = p.name;
      _birthday = p.birthday;
      if (p.birthday != null) {
        final d = p.birthday!;
        _birthdayController.text =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      } else {
        _birthdayController.clear();
      }
      _selectedSpecies = p.species.trim().isEmpty ? 'シリアン' : p.species;
      _selectedColor = _avatarAppearanceResolver.normalizeColorForSelection(
        species: _selectedSpecies,
        color: p.color,
      );
      _existingImageUrl = p.imageUrl;
    });
  }

  // ---------- helpers ----------
  Future<void> _pickBirthday() async {
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
      _birthdayController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  // UserImagePicker から受け取る
  void _pickImage(File image) {
    setState(() {
      _pickedImageFile = image;
      // 新規選択時は既存URLをクリア（プレビューがローカル優先になる）
      _existingImageUrl = null;
    });
  }

  Future<void> _onDeleteImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final urlToDelete = _existingImageUrl;

    setState(() {
      _pickedImageFile = null;
      _existingImageUrl = null;
    });

    try {
      // ★ Firestore直叩き禁止：Repo経由で imageUrl を消す
      await _repo.deleteImageUrl();

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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

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
      await _repo.saveMainPet(
        PetProfile(
          name: _nameController.text.trim(),
          birthday: _birthday,
          species: _selectedSpecies,
          color: _selectedColor,
          imageUrl: imageUrl,
        ),
      );

      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: 'ペット情報を変更しました！');
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: '保存に失敗しました…');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final speciesList =
        _avatarAppearanceResolver.speciesOptionsForCurrent(_selectedSpecies);
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
                          validator: (_) =>
                              _birthday == null ? '生年月日を選択してください' : null,
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'ハムスターの種類'),
                          value: _selectedSpecies,
                          items: speciesList
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedSpecies = v!;
                              _selectedColor = _avatarAppearanceResolver
                                  .defaultColorForSpecies(_selectedSpecies);
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
                          onChanged: (v) => setState(() => _selectedColor = v),
                          validator: (v) => v == null ? '毛色を選択してください' : null,
                        ),
                        const SizedBox(height: 24),
                        _PetIdentityPreview(
                          name: _nameController.text.trim(),
                          birthday: _birthday,
                          species: _selectedSpecies,
                          color: selectedColor ?? '未選択',
                          presentation: avatarPreview,
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 36, vertical: 16),
                            backgroundColor: AppTheme.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            '設定を保存',
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
