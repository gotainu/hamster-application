import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../models/breeding_environment.dart';
import '../models/environment_history.dart';
import '../services/breeding_environment_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/habitat_model_preview.dart';
import '../widgets/hamster_feedback_popup.dart';
import '../widgets/environment_effective_input.dart';
import '../widgets/shine_border.dart';
import '../viewmodels/environment_history_view_model.dart';
import 'environment_history_screen.dart';

class BreedingEnvironmentEditScreen extends StatefulWidget {
  const BreedingEnvironmentEditScreen(
      {super.key,
      this.store,
      this.onSaved,
      this.now,
      this.focusWheelDiameter = false});
  final EnvironmentStore? store;
  final Future<void> Function()? onSaved;
  final DateTime Function()? now;
  final bool focusWheelDiameter;

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
  late final EnvironmentStore _repo;
  late EnvironmentEffectiveDraft _effective;
  final _cageWidthController = TextEditingController();
  final _cageDepthController = TextEditingController();
  final _cageHeightController = TextEditingController();
  final _beddingController = TextEditingController();
  final _wheelController = TextEditingController();
  final _wheelFocus = FocusNode();
  final _wheelFieldKey = GlobalKey();
  bool _wheelGuideScheduled = false;
  final _accessoryNoteController = TextEditingController();

  final Set<String> _accessoryTags = <String>{};
  String? _temperatureControl;
  bool _accessoryTagsRecorded = false;
  bool _serverConfirmed = false;
  int _revision = 0;
  int? _targetRevision;
  Set<String> _correctionKeys = {};
  EnvironmentMutation? _pending;
  String? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.store ?? BreedingEnvironmentRepo();
    _effective = EnvironmentEffectiveDraft(_now);
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

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  bool _editable(String field) =>
      _pending == null &&
      _serverConfirmed &&
      !_isSaving &&
      (_targetRevision == null || _correctionKeys.contains(field));

  @override
  void dispose() {
    _cageWidthController.dispose();
    _cageDepthController.dispose();
    _cageHeightController.dispose();
    _beddingController.dispose();
    _wheelController.dispose();
    _wheelFocus.dispose();
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
      final load = await _repo.load();
      if (!mounted) return;
      _serverConfirmed = load.serverConfirmed;
      _revision = load.revision;
      _pending = load.pending;
      _loadError =
          load.serverConfirmed ? null : '現在の設定を確認できません。接続して再読み込みしてください。';
      _putEnvironment(load.environment);
      if (_pending != null) {
        final raw = {
          ...load.environment?.toMapForSave() ?? <String, dynamic>{},
          ..._pending!.values
        };
        _putEnvironment(BreedingEnvironment.fromMap(raw));
        _targetRevision = _pending!.targetRevision;
        _correctionKeys = _pending!.values.keys.toSet();
        if (_pending!.effective != null) {
          _effective.restore(_pending!.effective!);
        }
      }
    } catch (_) {
      _serverConfirmed = false;
      _loadError = '現在の設定を読み込めませんでした。再読み込みしてください。';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.focusWheelDiameter &&
            !_wheelGuideScheduled &&
            _editable('wheelDiameter')) {
          _wheelGuideScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final fieldContext = _wheelFieldKey.currentContext;
            if (!mounted || fieldContext == null) return;
            await Scrollable.ensureVisible(fieldContext,
                alignment: .4, duration: const Duration(milliseconds: 250));
            if (mounted && _editable('wheelDiameter')) {
              _wheelFocus.requestFocus();
            }
          });
        }
      }
    }
  }

  Widget _wheelDiameterField() {
    final field = _MetricField(
      controller: _wheelController,
      focusNode: _wheelFocus,
      enabled: _editable('wheelDiameter'),
      label: '車輪の直径',
      icon: Icons.tire_repair_rounded,
      validator: (value) =>
          _validateNumber(value, '車輪の直径', maxValue: _maxWheelCm),
      maxValue: _maxWheelCm,
      onChanged: (_) => _onDependentValueChanged(_wheelController, _maxWheelCm),
    );
    if (!widget.focusWheelDiameter) return field;
    return AnimatedShiningBorder(
      key: _wheelFieldKey,
      active: _positiveValue(_wheelController) == null,
      borderRadius: AppTheme.dataCardRadius,
      colors: const [AppTheme.envCaution, AppTheme.accent, AppTheme.envCaution],
      child: field,
    );
  }

  void _putEnvironment(BreedingEnvironment? env) {
    _cageWidthController.text = env?.cageWidth ?? '';
    _cageDepthController.text = env?.cageDepth ?? '';
    _cageHeightController.text = env?.cageHeight ?? '';
    _beddingController.text = env?.beddingThickness ?? '';
    _wheelController.text = env?.wheelDiameter ?? '';
    _temperatureControl = env?.temperatureControlRecorded == true
        ? env!.temperatureControl
        : null;
    _accessoryTags
      ..clear()
      ..addAll(env?.accessoryTags ?? const []);
    _accessoryTagsRecorded = env?.accessoryTagsRecorded ?? false;
    _accessoryNoteController.text = env?.accessoryNote ??
        (env?.accessoryTags.isEmpty == true ? env?.accessories ?? '' : '');
  }

  Future<void> _openHistory({bool selectCorrection = false}) async {
    var mutationAttempted = false;
    final entry = await Navigator.of(context).push<EnvironmentHistoryEntry>(
        MaterialPageRoute(
            builder: (_) => EnvironmentHistoryScreen(
                store: _repo,
                selectCorrection: selectCorrection,
                onMutationAttempted: () => mutationAttempted = true)));
    if (mounted && mutationAttempted) await _fetchExistingData();
    if (!mounted || entry == null) return;
    setState(() {
      _targetRevision = entry.targetRevision ?? entry.revision;
      _correctionKeys = entry.recordedFieldKeys
          .where((key) => key != 'cageFloorArea')
          .toSet();
      final controllers = {
        'cageWidth': _cageWidthController,
        'cageDepth': _cageDepthController,
        'cageHeight': _cageHeightController,
        'beddingThickness': _beddingController,
        'wheelDiameter': _wheelController
      };
      for (final field in _correctionKeys) {
        final after = entry.values[field] ??
            entry.changes[field]?.after ??
            const EnvironmentHistoryValue(null, null, 'unknown');
        if (controllers.containsKey(field)) {
          controllers[field]!.text =
              after.quality == 'known' ? after.value.toString() : '';
        }
        if (field == 'temperatureControl') {
          _temperatureControl =
              after.quality == 'known' ? after.value as String : null;
        }
        if (field == 'accessoryTags') {
          _accessoryTags
            ..clear()
            ..addAll(after.value is List
                ? (after.value as List).whereType<String>()
                : const []);
          _accessoryTagsRecorded = after.quality == 'known';
        }
      }
      _effective.restore(entry.effective);
    });
  }

  double? _numberOf(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value != null && value.isFinite ? value : null;
  }

  String? _validateNumber(String? value, String label, {double? maxValue}) {
    if ((value ?? '').trim().isEmpty) return null;
    final number = double.tryParse((value ?? '').trim());
    if (number == null || !number.isFinite || number <= 0) {
      return '$labelを入力してください';
    }
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
    if (!_serverConfirmed) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_effective.confirmed) {
      HamsterFeedbackPopup.show(context, message: '変更日か「不明」を選んでください');
      return;
    }
    setState(() => _isSaving = true);

    final env = BreedingEnvironment(
      cageWidth: _optionalNumber(_cageWidthController),
      cageDepth: _optionalNumber(_cageDepthController),
      cageHeight: _optionalNumber(_cageHeightController),
      beddingThickness: _optionalNumber(_beddingController),
      wheelDiameter: _optionalNumber(_wheelController),
      temperatureControl: _temperatureControl ?? '',
      temperatureControlRecorded: _temperatureControl != null,
      accessoryTags: _accessoryTags.toList()..sort(),
      accessoryTagsRecorded: _accessoryTagsRecorded,
      accessoryNote: _accessoryNoteController.text.trim().isEmpty
          ? null
          : _accessoryNoteController.text.trim(),
      accessories: _legacyAccessoriesValue(),
    );

    final values = env.toMapForSave();
    if (_targetRevision != null) {
      values.removeWhere((key, _) => !_correctionKeys.contains(key));
    }
    final mutation = EnvironmentMutation(
        mutationId: const Uuid().v4(),
        expectedRevision: _revision,
        operation: _targetRevision == null
            ? EnvironmentOperation.change
            : EnvironmentOperation.correction,
        targetRevision: _targetRevision,
        values: values,
        effective: _effective.toEffective());
    await _send(mutation);
  }

  String? _optionalNumber(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();
  Future<void> _send(EnvironmentMutation mutation) async {
    setState(() => _isSaving = true);
    try {
      final result = await _repo.save(mutation);
      if (!mounted) return;
      if (!result.confirmed) {
        setState(() => _pending = mutation);
        return;
      }
      _pending = null;
      _revision = result.revision ?? _revision;
      var profileConfirmed = true;
      try {
        if (widget.onSaved != null) {
          await widget.onSaved!();
        } else {
          await OnboardingStateRepo().markProfileCompleted('environment');
        }
      } catch (_) {
        profileConfirmed = false;
      }
      if (!mounted) return;
      HamsterFeedbackPopup.show(context,
          message: profileConfirmed
              ? '飼育環境を保存しました'
              : '飼育環境は保存しました。プロフィール完了の更新は未確認です。');
      Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final definitive = const {
        'invalid-argument',
        'failed-precondition',
        'aborted',
        'unauthenticated',
        'permission-denied',
        'not-found',
        'already-exists'
      }.contains(error.code);
      if (definitive) {
        _pending = null;
      } else {
        _pending = mutation;
      }
      if (error.code == 'aborted') {
        _serverConfirmed = false;
        _loadError = '別の変更が保存されました。最新の設定を再読み込みしてください。';
      }
      HamsterFeedbackPopup.show(context,
          message: error.code == 'aborted'
              ? '同時編集を検出しました。再読み込みしてください。'
              : definitive
                  ? '保存できませんでした。入力を確認してください。'
                  : '保存確認待ちです。同じ内容を再送してください。');
    } catch (_) {
      if (!mounted) return;
      _pending = mutation;
      HamsterFeedbackPopup.show(context,
          message: '保存を確認できませんでした。同じ内容を再送してください。');
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
        extendBodyBehindAppBar: false,
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
                      padding: AppTheme.dataPagePadding,
                      children: [
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                key: const ValueKey('environment-open-history'),
                                onPressed: _pending != null
                                    ? null
                                    : () => _openHistory(),
                                child: const Text('変更履歴'))),
                        if (_loadError != null) ...[
                          Text(_loadError!),
                          TextButton(
                              key: const ValueKey('environment-reload'),
                              onPressed: () async {
                                setState(() {
                                  _isLoading = true;
                                  _targetRevision = null;
                                  _correctionKeys = {};
                                  _effective = EnvironmentEffectiveDraft(_now);
                                });
                                await _fetchExistingData();
                              },
                              child: const Text('最新の設定を再読み込み')),
                        ],
                        if (_pending != null) ...[
                          const Text('保存確認待ちです。接続後に同じ内容を再送できます。'),
                          FilledButton(
                              key: const ValueKey('environment-retry'),
                              onPressed:
                                  _isSaving ? null : () => _send(_pending!),
                              child: const Text('同じ内容を再送')),
                          const SizedBox(height: 16),
                        ],
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
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          ChoiceChip(
                              label: const Text('環境の変更'),
                              selected: _targetRevision == null,
                              onSelected: _pending != null || _isSaving
                                  ? null
                                  : (_) async {
                                      _targetRevision = null;
                                      _correctionKeys = {};
                                      _effective =
                                          EnvironmentEffectiveDraft(_now);
                                      await _fetchExistingData();
                                    }),
                          ChoiceChip(
                              label: const Text('入力の訂正'),
                              selected: _targetRevision != null,
                              onSelected: _pending != null || _isSaving
                                  ? null
                                  : (_) =>
                                      _openHistory(selectCorrection: true)),
                        ]),
                        const SizedBox(height: 18),
                        if (widget.focusWheelDiameter) ...[
                          _wheelDiameterField(),
                          const SizedBox(height: 18),
                        ],
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
                                enabled: _editable('cageWidth'),
                                label: '横幅',
                                icon: Icons.width_normal_rounded,
                                validator: (value) => _editable('cageWidth')
                                    ? _validateNumber(value, '横幅',
                                        maxValue: 200)
                                    : null,
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
                                enabled: _editable('cageDepth'),
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
                                enabled: _editable('cageHeight'),
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
                            if (!widget.focusWheelDiameter) ...[
                              const SizedBox(width: 12),
                              Expanded(child: _wheelDiameterField()),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MetricField(
                          controller: _beddingController,
                          enabled: _editable('beddingThickness'),
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
                          children: <String>[
                            ..._temperatureOptions,
                            if (_temperatureControl != null &&
                                !_temperatureOptions
                                    .contains(_temperatureControl))
                              _temperatureControl!
                          ]
                              .map(
                                (option) => ChoiceChip(
                                  label: Text(option),
                                  selected: _temperatureControl == option,
                                  onSelected: !_editable('temperatureControl')
                                      ? null
                                      : (_) => setState(
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
                                  onSelected: !_editable('accessoryTags')
                                      ? null
                                      : (selected) => setState(() {
                                            _accessoryTagsRecorded = true;
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
                          enabled: _editable('accessoryNote'),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'そのほかのグッズ（任意）',
                            hintText: '例：見守りカメラ、コルクマット',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (_revision == 0)
                          Text('初回は現在の設定として確認します。',
                              style: Theme.of(context).textTheme.bodySmall),
                        EnvironmentEffectiveInput(
                            draft: _effective,
                            today: _now,
                            onChanged: () => setState(() {})),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          key: const ValueKey('environment-save'),
                          onPressed:
                              _isSaving || _pending != null || !_serverConfirmed
                                  ? null
                                  : _submitForm,
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
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final double? maxValue;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: ValueKey('environment-$label'),
        enabled: enabled,
        focusNode: focusNode,
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
