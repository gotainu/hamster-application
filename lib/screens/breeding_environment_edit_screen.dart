import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BreedingEnvironmentEditScreen extends StatefulWidget {
  const BreedingEnvironmentEditScreen({super.key});

  @override
  State<BreedingEnvironmentEditScreen> createState() =>
      _BreedingEnvironmentEditScreenState();
}

class _BreedingEnvironmentEditScreenState
    extends State<BreedingEnvironmentEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // 入力項目を保持する変数（全て文字列として保持）
  String? _cageWidth;
  String? _cageDepth;
  String? _beddingThickness;
  String? _wheelDiameter;
  String _temperatureControl = 'エアコン'; // 初期値
  String? _accessories;

  bool _isLoading = false; // 保存中フラグ

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  /// Firestoreから既存の飼育環境情報を取得し、フォームの初期値にセットする
  Future<void> _fetchExistingData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!docSnapshot.exists) return;
    final data = docSnapshot.data();
    final envData = data?['breedingEnvironment'] as Map<String, dynamic>?;
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

  /// フォーム保存処理
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
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'breedingEnvironment': envData,
        }, SetOptions(merge: true));

        // 非同期処理後にウィジェットがまだマウントされているか確認
        if (!mounted) return;

        // 保存成功 → SnackBar で完了メッセージ表示
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('飼育環境情報を変更しました！'),
            duration: Duration(seconds: 2),
          ),
        );

        // 2秒後にオーバーレイを解除し、前画面に戻る
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('飼育環境を編集'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ケージの横幅
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
                  // ケージの奥行き
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
                  // 床材の嵩
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
                  // 車輪の直径
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
                  // ケージの温度管理方法
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
                  // その他のグッズ類（自由記述）
                  TextFormField(
                    initialValue: _accessories,
                    decoration: const InputDecoration(
                      labelText: 'その他のグッズ類',
                    ),
                    maxLines: 3,
                    onSaved: (value) => _accessories = value,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('設定を保存'),
                  ),
                ],
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
    );
  }
}
