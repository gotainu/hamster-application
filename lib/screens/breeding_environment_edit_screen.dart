import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/breeding_environment.dart';
import '../services/breeding_environment_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/habitat_model_preview.dart';
import '../widgets/hamster_feedback_popup.dart';

class BreedingEnvironmentEditScreen extends StatefulWidget {
  const BreedingEnvironmentEditScreen({super.key});

  @override
  State<BreedingEnvironmentEditScreen> createState() =>
      _BreedingEnvironmentEditScreenState();
}

class _BreedingEnvironmentEditScreenState
    extends State<BreedingEnvironmentEditScreen> {
  static const _accessoryOptions = <String>[
    '隠れ家',
    '砂場',
    '給水器',
    'トンネル',
    'かじり木',
    '登り台',
    '温湿度計',
  ];
  static const _temperatureOptions = <String>[
    'エアコン',
    'ヒーター',
    '保温球',
    '冷却グッズ',
    'その他',
  ];

  final _formKey = GlobalKey<FormState>();
  final _repo = BreedingEnvironmentRepo();
  final _cageWidthController = TextEditingController();
  final _cageDepthController = TextEditingController();
  final _cageHeightController = TextEditingController();
  final _beddingController = TextEditingController();
  final _wheelController = TextEditingController();
  final _accessoryNoteController = TextEditingController();

  final Set<String> _accessoryTags = <String>{};
  String _temperatureControl = 'エアコン';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _cageWidthController,
      _cageDepthController,
      _cageHeightController,
      _beddingController,
      _wheelController,
    ]) {
      controller.addListener(_refreshPreview);
    }
    _fetchExistingData();
  }

  @override
  void dispose() {
    _cageWidthController.dispose();
    _cageDepthController.dispose();
    _cageHeightController.dispose();
    _beddingController.dispose();
    _wheelController.dispose();
    _accessoryNoteController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  double? _positiveValue(TextEditingController controller) {
    final value = _numberOf(controller);
    return value != null && value > 0 ? value : null;
  }

  double? get _maxBeddingCm {
    final height = _positiveValue(_cageHeightController);
    return height == null ? null : height * .60;
  }

  double? get _maxWheelCm {
    final width = _positiveValue(_cageWidthController);
    final depth = _positiveValue(_cageDepthController);
    final height = _positiveValue(_cageHeightController);
    if (width == null || depth == null || height == null) return null;
    return math.min(math.min(width, depth), height) * .78;
  }

  String _formatCm(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  void _capController(TextEditingController controller, double? maxValue) {
    final value = _numberOf(controller);
    if (value == null || maxValue == null || value <= maxValue) return;
    final text = _formatCm(maxValue);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onCageDimensionChanged(
    TextEditingController changedController,
    double maxValue,
  ) {
    _capController(changedController, maxValue);
    _capController(_beddingController, _maxBeddingCm);
    _capController(_wheelController, _maxWheelCm);
    _refreshPreview();
  }

  void _onDependentValueChanged(
    TextEditingController controller,
    double? maxValue,
  ) {
    _capController(controller, maxValue);
    _refreshPreview();
  }

  Future<void> _fetchExistingData() async {
    try {
      final env = await _repo.fetchMainEnv();
      if (!mounted || env == null) return;
      _cageWidthController.text = env.cageWidth ?? '';
      _cageDepthController.text = env.cageDepth ?? '';
      // 既存データには高さがないため、一般的な35cmを初期値にして
      // 新しい床材・車輪の上限計算をすぐに有効にする。
      _cageHeightController.text = env.cageHeight ?? '35';
      _beddingController.text = env.beddingThickness ?? '';
      _wheelController.text = env.wheelDiameter ?? '';
      _onCageDimensionChanged(_cageWidthController, 200);
      _temperatureControl = _temperatureOptions.contains(env.temperatureControl)
          ? env.temperatureControl
          : 'その他';
      _accessoryTags.addAll(env.accessoryTags);
      _accessoryNoteController.text = env.accessoryNote ??
          (env.accessoryTags.isEmpty ? env.accessories ?? '' : '');
    } catch (_) {
      // 保存前の下書きは空のまま表示し、入力を妨げない。
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? _numberOf(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  String? _validateNumber(String? value, String label, {double? maxValue}) {
    final number = double.tryParse((value ?? '').trim());
    if (number == null || number <= 0) return '$labelを入力してください';
    if (maxValue != null && number > maxValue) {
      return '$labelは最大${_formatCm(maxValue)} cmです';
    }
    return null;
  }

  String? _legacyAccessoriesValue() {
    final values = <String>[
      ..._accessoryTags,
      if (_accessoryNoteController.text.trim().isNotEmpty)
        _accessoryNoteController.text.trim(),
    ];
    return values.isEmpty ? null : values.join('・');
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final env = BreedingEnvironment(
      cageWidth: _cageWidthController.text.trim(),
      cageDepth: _cageDepthController.text.trim(),
      cageHeight: _cageHeightController.text.trim(),
      beddingThickness: _beddingController.text.trim(),
      wheelDiameter: _wheelController.text.trim(),
      temperatureControl: _temperatureControl,
      accessoryTags: _accessoryTags.toList()..sort(),
      accessoryNote: _accessoryNoteController.text.trim().isEmpty
          ? null
          : _accessoryNoteController.text.trim(),
      accessories: _legacyAccessoriesValue(),
    );

    try {
      await _repo.saveMainEnv(env);
      await OnboardingStateRepo().markProfileCompleted('environment');
      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: '飼育環境を保存しました');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      HamsterFeedbackPopup.show(context, message: '保存に失敗しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        appBar: AppBar(title: const Text('飼育環境を編集')),
        body: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: SafeArea(
            top: false,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 102, 20, 40),
                      children: [
                        Text(
                          '住まいを、見えるかたちに。',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryText(context),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'サイズやグッズを入力すると、下の模型がすぐに変わります。',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.secondaryText(context),
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 18),
                        HabitatModelPreview(
                          cageWidthCm: _numberOf(_cageWidthController),
                          cageDepthCm: _numberOf(_cageDepthController),
                          cageHeightCm: _numberOf(_cageHeightController),
                          beddingCm: _numberOf(_beddingController),
                          wheelDiameterCm: _numberOf(_wheelController),
                          accessoryTags: _accessoryTags,
                        ),
                        const SizedBox(height: 26),
                        _SectionHeader(
                          icon: Icons.straighten_rounded,
                          title: 'ケージのサイズ',
                          subtitle: '模型の比率に反映されます',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricField(
                                controller: _cageWidthController,
                                label: '横幅',
                                icon: Icons.width_normal_rounded,
                                validator: (value) =>
                                    _validateNumber(value, '横幅', maxValue: 200),
                                maxValue: 200,
                                onChanged: (_) => _onCageDimensionChanged(
                                  _cageWidthController,
                                  200,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricField(
                                controller: _cageDepthController,
                                label: '奥行き',
                                icon: Icons.height_rounded,
                                validator: (value) => _validateNumber(
                                    value, '奥行き',
                                    maxValue: 150),
                                maxValue: 150,
                                onChanged: (_) => _onCageDimensionChanged(
                                  _cageDepthController,
                                  150,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricField(
                                controller: _cageHeightController,
                                label: '高さ',
                                icon: Icons.height_rounded,
                                validator: (value) =>
                                    _validateNumber(value, '高さ', maxValue: 150),
                                maxValue: 150,
                                onChanged: (_) => _onCageDimensionChanged(
                                  _cageHeightController,
                                  150,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricField(
                                controller: _wheelController,
                                label: '車輪の直径',
                                icon: Icons.tire_repair_rounded,
                                validator: (value) => _validateNumber(
                                  value,
                                  '車輪の直径',
                                  maxValue: _maxWheelCm,
                                ),
                                maxValue: _maxWheelCm,
                                onChanged: (_) => _onDependentValueChanged(
                                  _wheelController,
                                  _maxWheelCm,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MetricField(
                          controller: _beddingController,
                          label: '床材の深さ',
                          icon: Icons.layers_rounded,
                          validator: (value) => _validateNumber(
                            value,
                            '床材の深さ',
                            maxValue: _maxBeddingCm,
                          ),
                          maxValue: _maxBeddingCm,
                          onChanged: (_) => _onDependentValueChanged(
                            _beddingController,
                            _maxBeddingCm,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _SectionHeader(
                          icon: Icons.thermostat_rounded,
                          title: '温度の管理',
                          subtitle: '主に使っている方法をひとつ選んでください',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _temperatureOptions
                              .map(
                                (option) => ChoiceChip(
                                  label: Text(option),
                                  selected: _temperatureControl == option,
                                  onSelected: (_) => setState(
                                    () => _temperatureControl = option,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 28),
                        _SectionHeader(
                          icon: Icons.inventory_2_rounded,
                          title: 'ケージの中にあるもの',
                          subtitle: '選んだグッズは模型にも現れます',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _accessoryOptions
                              .map(
                                (option) => FilterChip(
                                  label: Text(option),
                                  selected: _accessoryTags.contains(option),
                                  onSelected: (selected) => setState(() {
                                    if (selected) {
                                      _accessoryTags.add(option);
                                    } else {
                                      _accessoryTags.remove(option);
                                    }
                                  }),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _accessoryNoteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'そのほかのグッズ（任意）',
                            hintText: '例：見守りカメラ、コルクマット',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        const SizedBox(height: 30),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _submitForm,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(_isSaving ? '保存中…' : 'この環境を保存する'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryText(context),
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _MetricField extends StatelessWidget {
  const _MetricField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.maxValue,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final double? maxValue;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
        ],
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'cm',
          prefixIcon: Icon(icon),
          helperText: maxValue == null
              ? 'ケージの寸法を入力すると上限が決まります'
              : '上限 ${maxValue == maxValue!.roundToDouble() ? maxValue!.toStringAsFixed(0) : maxValue!.toStringAsFixed(1)} cm',
        ),
      );
}
