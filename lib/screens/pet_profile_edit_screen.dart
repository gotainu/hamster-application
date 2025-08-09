import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hamster_project/widgets/user_image_picker.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:flutter/services.dart';

class PetProfileEditScreen extends StatefulWidget {
  const PetProfileEditScreen({super.key});
  @override
  State<PetProfileEditScreen> createState() => _PetProfileEditScreenState();
}

class _PetProfileEditScreenState extends State<PetProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _pickedImageFile;
  String _hamsterName = '';
  DateTime? _birthday;
  String _selectedSpecies = 'シリアン';
  String? _selectedColor;
  bool _isLoading = false;

  final List<String> _speciesList = [
    'シリアン',
    'ジャンガリアン',
    'ロボロフスキー',
    'チャイニーズ',
    'キャンベル',
  ];
  final Map<String, List<String>> _colorOptionsMap = {
    'シリアン': ['キンクマ', 'ゴールデン', 'アルビノ'],
    'ジャンガリアン': ['ノーマル', 'ブルーサファイア', 'パールホワイト', 'スノーホワイト', 'プディング', 'アルビノ'],
    'ロボロフスキー': ['ノーマル', 'ホワイト', 'パイド', 'アルビノ'],
    'チャイニーズ': ['ノーマル', 'ホワイト', 'パイド', 'アルビノ'],
    'キャンベル': ['ノーマル', 'オパール', 'イエロー（アルビノイエロー）', '黒目イエロー', 'パイド', 'レッド'],
  };

  final _birthdayController = TextEditingController();

  @override
  void dispose() {
    _birthdayController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  // Firestoreベストプラクティス: users/{uid}/pet_profiles/{petId} で取得
  Future<void> _fetchExistingData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1匹運用なら petId = 'main_pet' でOK。複数対応は要ID設計
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pet_profiles')
        .doc('main_pet')
        .get();
    if (!docSnapshot.exists) return;
    final data = docSnapshot.data()!;
    setState(() {
      _hamsterName = data['name'] ?? '';
      if (data['birthday'] != null) {
        final ts = data['birthday'];
        if (ts is Timestamp) {
          _birthday = ts.toDate();
          _birthdayController.text =
              _birthday!.toIso8601String().split('T').first;
        } else if (ts is String) {
          _birthday = DateTime.tryParse(ts);
          if (_birthday != null) {
            _birthdayController.text =
                _birthday!.toIso8601String().split('T').first;
          }
        }
      }
      _selectedSpecies = data['species'] ?? 'シリアン';
      _selectedColor = data['color'];
      // ※画像表示実装があれば、imageUrl もここで拾える
    });
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initialDate = _birthday ?? DateTime(now.year - 1);
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 1);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate == null) return;

    setState(() {
      _birthday = pickedDate;
      _birthdayController.text =
          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
    });
  }

  void _pickImage(File image) {
    setState(() {
      _pickedImageFile = image;
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      setState(() {
        _isLoading = true;
      });

      final petData = {
        'name': _hamsterName,
        'birthday': _birthday != null ? Timestamp.fromDate(_birthday!) : null,
        'species': _selectedSpecies,
        'color': _selectedColor,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_pickedImageFile != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('hamster_images')
              .child('$uid-main_pet.jpg');
          await ref.putFile(_pickedImageFile!);
          final imageUrl = await ref.getDownloadURL();
          petData['imageUrl'] = imageUrl;
        } catch (e) {
          debugPrint('画像のアップロード失敗: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像のアップロードに失敗しました')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      try {
        // ① 親ドキュメントが空にならないようにする
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'has_subcollections': true}, SetOptions(merge: true));
        // Firestoreベストプラクティス: users/{uid}/pet_profiles/main_pet
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('pet_profiles')
            .doc('main_pet')
            .set(petData, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ペット情報を変更しました！'),
            duration: Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          Navigator.pop(context);
        });
      } catch (e) {
        debugPrint('データの保存に失敗: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました…')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
        statusBarColor: Colors.transparent, // ステータスバーを透明化
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark, // アイコン色
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true, // ←AppBarの後ろまで背景を広げる
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'ペットプロフィール編集',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
                        UserImagePicker(onPickImage: _pickImage),
                        const SizedBox(height: 18),
                        TextFormField(
                          initialValue: _hamsterName,
                          decoration:
                              const InputDecoration(labelText: 'ハムスターの名前'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '名前を入力してください';
                            }
                            return null;
                          },
                          onSaved: (value) => _hamsterName = value!,
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
                          validator: (value) {
                            if (_birthday == null) {
                              return '生年月日を選択してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'ハムスターの種類'),
                          value: _selectedSpecies,
                          items: _speciesList.map((species) {
                            return DropdownMenuItem(
                              value: species,
                              child: Text(
                                species,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSpecies = value!;
                              _selectedColor = null;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: '毛色'),
                          value: _selectedColor,
                          items: colorList.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedColor = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return '毛色を選択してください';
                            }
                            return null;
                          },
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
                                  fontSize: 17,
                                ),
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
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
