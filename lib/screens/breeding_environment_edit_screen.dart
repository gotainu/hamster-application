import 'package:flutter/material.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:flutter/services.dart';

import '../models/breeding_environment.dart';
import '../services/breeding_environment_repo.dart';

class BreedingEnvironmentEditScreen extends StatefulWidget {
  const BreedingEnvironmentEditScreen({super.key});

  @override
  State<BreedingEnvironmentEditScreen> createState() =>
      _BreedingEnvironmentEditScreenState();
}

class _BreedingEnvironmentEditScreenState
    extends State<BreedingEnvironmentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = BreedingEnvironmentRepo();

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

  Future<void> _fetchExistingData() async {
    setState(() => _isLoading = true);

    try {
      final env = await _repo.fetchMainEnv();
      if (!mounted) return;

      if (env != null) {
        setState(() {
          _cageWidth = env.cageWidth;
          _cageDepth = env.cageDepth;
          _beddingThickness = env.beddingThickness;
          _wheelDiameter = env.wheelDiameter;
          _temperatureControl = env.temperatureControl;
          _accessories = env.accessories;
        });
      }
    } catch (_) {
      // ここは握りつぶしてOK（必要ならSnackBar出しても良い）
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    setState(() => _isLoading = true);

    final env = BreedingEnvironment(
      cageWidth: _cageWidth,
      cageDepth: _cageDepth,
      beddingThickness: _beddingThickness,
      wheelDiameter: _wheelDiameter,
      temperatureControl: _temperatureControl,
      accessories: _accessories,
    );

    try {
      await _repo.saveMainEnv(env);
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('飼育環境情報を変更しました！'),
          duration: Duration(seconds: 2),
        ),
      );

      // 2秒後に戻る（mounted確認はここで）
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました…')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          title: const Text('飼育環境を編集'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Container(decoration: BoxDecoration(gradient: bgGradient)),
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
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Icon(Icons.eco,
                              color: AppTheme.accent, size: 38),
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
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? '横幅を入力してください'
                                    : null,
                            onSaved: (value) => _cageWidth = value,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _cageDepth,
                            decoration: const InputDecoration(
                              labelText: 'ケージの奥行き (cm)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? '奥行きを入力してください'
                                    : null,
                            onSaved: (value) => _cageDepth = value,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _beddingThickness,
                            decoration: const InputDecoration(
                              labelText: '床材の嵩 (cm)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? '床材の嵩を入力してください'
                                    : null,
                            onSaved: (value) => _beddingThickness = value,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _wheelDiameter,
                            decoration: const InputDecoration(
                              labelText: '車輪の直径 (cm)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? '車輪の直径を入力してください'
                                    : null,
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
                            onChanged: (value) =>
                                setState(() => _temperatureControl = value!),
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
                              icon: const Icon(Icons.save, color: Colors.white),
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
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
