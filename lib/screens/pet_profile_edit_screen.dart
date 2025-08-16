// lib/screens/pet_profile_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/user_image_picker.dart';

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

  File? _pickedImageFile;
  String? _existingImageUrl; // ← 1回だけ定義（finalにしない）
  DateTime? _birthday;

  String _selectedSpecies = 'シリアン';
  String? _selectedColor;
  bool _isLoading = false;

  final List<String> _speciesList = const [
    'シリアン',
    'ジャンガリアン',
    'ロボロフスキー',
    'チャイニーズ',
    'キャンベル',
  ];

  final Map<String, List<String>> _colorOptionsMap = const {
    'シリアン': ['キンクマ', 'ゴールデン', 'アルビノ'],
    'ジャンガリアン': ['ノーマル', 'ブルーサファイア', 'パールホワイト', 'スノーホワイト', 'プディング', 'アルビノ'],
    'ロボロフスキー': ['ノーマル', 'ホワイト', 'パイド', 'アルビノ'],
    'チャイニーズ': ['ノーマル', 'ホワイト', 'パイド', 'アルビノ'],
    'キャンベル': ['ノーマル', 'オパール', 'イエロー（アルビノイエロー）', '黒目イエロー', 'パイド', 'レッド'],
  };

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // ---------- data load ----------
  Future<void> _fetchExistingData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final petDoc = userDoc.collection('pet_profiles').doc('main_pet');

    String? imageUrl;
    String hamsterName = '';
    DateTime? birthday;
    String species = 'シリアン';
    String? color;

    // ① pet_profiles/main_pet 優先
    final petSnap = await petDoc.get();
    if (petSnap.exists) {
      final d = petSnap.data()!;
      hamsterName = d['name'] ?? '';
      final b = d['birthday'];
      if (b is Timestamp) birthday = b.toDate();
      if (b is String) birthday = DateTime.tryParse(b);
      species = d['species'] ?? 'シリアン';
      color = d['color'];
      imageUrl = d['imageUrl'] as String?;
    }



    setState(() {
      _nameController.text = hamsterName;
      _birthday = birthday;
      if (birthday != null) {
        _birthdayController.text =
            '${birthday.year}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
      } else {
        _birthdayController.clear();
      }
      _selectedSpecies = species;
      _selectedColor = color;
      _existingImageUrl = imageUrl; // ← ピッカーに渡すURL
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

    final petDoc = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('pet_profiles').doc('main_pet');

    final urlToDelete = _existingImageUrl;

    setState(() {
      _pickedImageFile = null;
      _existingImageUrl = null;
    });

    // main_pet のみ更新
    await petDoc.set({
      'imageUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (urlToDelete != null) {
      try { await FirebaseStorage.instance.refFromURL(urlToDelete).delete(); } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('画像を削除しました')));
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    final petDoc = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('pet_profiles').doc('main_pet');

    String? imageUrl = _existingImageUrl;

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像のアップロードに失敗しました')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }

    final petData = {
      'name': _nameController.text.trim(),
      'birthday': _birthday != null ? Timestamp.fromDate(_birthday!) : null,
      'species': _selectedSpecies,
      'color': _selectedColor,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await petDoc.set(petData, SetOptions(merge: true)); // ← main_pet だけ
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ペット情報を変更しました！')));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存に失敗しました…')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorList = _colorOptionsMap[_selectedSpecies]!;
    if (_selectedColor == null || !colorList.contains(_selectedColor)) {
      _selectedColor = null;
    }
    final bgGradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
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
                    color:
                        isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.19),
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
                        // 画像ピッカー（既存URL + 削除対応）
                        UserImagePicker(
                          initialImageUrl: _existingImageUrl,
                          onPickImage: _pickImage, // ← 小文字
                          onDelete: _onDeleteImage,
                        ),
                        const SizedBox(height: 18),

                        TextFormField(
                          controller: _nameController,
                          decoration:
                              const InputDecoration(labelText: 'ハムスターの名前'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? '名前を入力してください' : null,
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
                          validator: (value) =>
                              _birthday == null ? '生年月日を選択してください' : null,
                        ),
                        const SizedBox(height: 18),

                        DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'ハムスターの種類'),
                          value: _selectedSpecies,
                          items: _speciesList
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
                              _selectedColor = null;
                            });
                          },
                        ),
                        const SizedBox(height: 18),

                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: '毛色'),
                          value: _selectedColor,
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
                          validator: (v) =>
                              v == null ? '毛色を選択してください' : null,
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
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}