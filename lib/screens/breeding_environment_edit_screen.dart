import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:flutter/services.dart';

class BreedingEnvironmentEditScreen extends StatefulWidget {
  const BreedingEnvironmentEditScreen({super.key});

  @override
  State<BreedingEnvironmentEditScreen> createState() =>
      _BreedingEnvironmentEditScreenState();
}

class _BreedingEnvironmentEditScreenState
    extends State<BreedingEnvironmentEditScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _cageWidth;
  String? _cageDepth;
  String? _beddingThickness;
  String? _wheelDiameter;
  String _temperatureControl = 'エアコン';
  String? _accessories;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  // Firestoreサブコレクション（ベストプラクティス構造）から取得
  Future<void> _fetchExistingData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // サブコレクション：users/{uid}/breeding_environments/main_env
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('breeding_environments')
        .doc('main_env')
        .get();
    if (!docSnapshot.exists) return;
    final envData = docSnapshot.data();
    if (envData != null) {
      setState(() {
        _cageWidth = envData['cageWidth']?.toString();
        _cageDepth = envData['cageDepth']?.toString();
        _beddingThickness = envData['beddingThickness']?.toString();
        _wheelDiameter = envData['wheelDiameter']?.toString();
        _temperatureControl = envData['temperatureControl'] ?? 'エアコン';
        _accessories = envData['accessories']?.toString();
      });
    }
  }

  // サブコレクション：users/{uid}/breeding_environments/main_env に保存
  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      setState(() {
        _isLoading = true;
      });
      final envData = {
        'cageWidth': _cageWidth,
        'cageDepth': _cageDepth,
        'beddingThickness': _beddingThickness,
        'wheelDiameter': _wheelDiameter,
        'temperatureControl': _temperatureControl,
        'accessories': _accessories,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      try {
        // ① 親ドキュメントが空にならないようにする
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'has_subcollections': true}, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('breeding_environments')
            .doc('main_env')
            .set(envData, SetOptions(merge: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('飼育環境情報を変更しました！'),
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
          title: const Text('飼育環境を編集'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: bgGradient,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 36),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.cardInnerDark
                          : AppTheme.cardInnerLight,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.22),
                          blurRadius: 36,
                          spreadRadius: 0,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Icon(Icons.eco, color: AppTheme.accent, size: 38),
                          const SizedBox(height: 14),
                          Text(
                            '飼育環境フォーム',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            initialValue: _cageWidth,
                            decoration: const InputDecoration(
                              labelText: 'ケージの横幅 (cm)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '横幅を入力してください';
                              }
                              return null;
                            },
                            onSaved: (value) => _cageWidth = value,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _cageDepth,
                            decoration: const InputDecoration(
                              labelText: 'ケージの奥行き (cm)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '奥行きを入力してください';
                              }
                              return null;
                            },
                            onSaved: (value) => _cageDepth = value,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _beddingThickness,
                            decoration: const InputDecoration(
                              labelText: '床材の嵩 (cm)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '床材の嵩を入力してください';
                              }
                              return null;
                            },
                            onSaved: (value) => _beddingThickness = value,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _wheelDiameter,
                            decoration: const InputDecoration(
                              labelText: '車輪の直径 (cm)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '車輪の直径を入力してください';
                              }
                              return null;
                            },
                            onSaved: (value) => _wheelDiameter = value,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'ケージの温度管理方法',
                            ),
                            value: _temperatureControl,
                            items: const [
                              DropdownMenuItem(
                                value: 'エアコン',
                                child: Text('エアコン'),
                              ),
                              DropdownMenuItem(
                                value: 'その他のグッズ',
                                child: Text('その他のグッズ'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _temperatureControl = value!;
                              });
                            },
                            onSaved: (value) => _temperatureControl = value!,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _accessories,
                            decoration: const InputDecoration(
                              labelText: 'その他のグッズ類',
                            ),
                            maxLines: 3,
                            onSaved: (value) => _accessories = value,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save, color: AppTheme.accent),
                              label: const Text('設定を保存'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 1,
                              ),
                              onPressed: _submitForm,
                            ),
                          ),
                        ],
                      ),
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
