import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../screens/breeding_environment_edit_screen.dart';
import '../services/distance_records_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../theme/app_theme.dart';
import '../viewmodels/measurement_input_view_model.dart';
import 'status_card.dart';

typedef WheelRotationSavedCallback = void Function({
  required DateTime date,
  required int rotations,
  double? distanceMeters,
});

class WheelRotationInputCard extends StatefulWidget {
  final DistanceRecordsRepo? distanceRepo;
  final DateTime? initialDate;
  final String title;
  final String subtitle;
  final bool compact;
  final WheelRotationSavedCallback? onSaved;

  const WheelRotationInputCard({
    super.key,
    this.distanceRepo,
    this.initialDate,
    this.title = '今日の走った記録',
    this.subtitle = '回し車の回転数を入れると、走行距離に換算して保存できます。',
    this.compact = false,
    this.onSaved,
  });

  @override
  State<WheelRotationInputCard> createState() => _WheelRotationInputCardState();
}

class _WheelRotationInputCardState extends State<WheelRotationInputCard> {
  late final DistanceRecordsRepo _repo;
  late DateTime _selectedRecordDate;

  DateTime _defaultRecordDate() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day);
  }

  final _wheelCtrl = TextEditingController();
  final _diameterCtrl = TextEditingController();

  double? _distance;
  DailyDistanceRecord? _savedRecord;
  bool _isEditing = true;

  bool _loadingWheel = true;
  bool _loadingRecord = true;
  bool _recordLoadFailed = false;
  bool _saving = false;
  String? _message;
  bool _isErrorMessage = false;
  int _calcSeq = 0;
  Map<String, dynamic>? _pending;
  bool _legacyConfirmed = false, _diameterCorrection = false;
  double? _correctedDiameter;
  double? get _editingDiameter =>
      _correctedDiameter ??
      (_savedRecord == null
          ? _repo.cachedWheelDiameterCm
          : _savedRecord!.wheelDiameterCm);

  @override
  void initState() {
    super.initState();

    _repo = widget.distanceRepo ?? DistanceRecordsRepo();
    _selectedRecordDate = widget.initialDate ?? _defaultRecordDate();

    _wheelCtrl.addListener(() => _recalcDistance(_wheelCtrl.text));
    _refreshWheelDiameter();
    _loadSavedRecord();
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _diameterCtrl.dispose();
    super.dispose();
  }

  bool get _wheelReady => _editingDiameter != null;

  int? get _rotations {
    final text = _wheelCtrl.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  bool get _canSave {
    return !_recordLoadFailed &&
        !_loadingWheel &&
        !_loadingRecord &&
        _wheelReady &&
        _rotations != null &&
        !_saving &&
        _pending == null &&
        (_savedRecord == null ||
            _savedRecord!.subjectId != null ||
            _legacyConfirmed);
  }

  Future<void> _refreshWheelDiameter() async {
    setState(() {
      _loadingWheel = true;
      _message = null;
      _isErrorMessage = false;
    });

    await _repo.refreshWheelDiameter();

    if (!mounted) return;

    setState(() {
      _loadingWheel = false;
    });

    _recalcDistance(_wheelCtrl.text);
  }

  Future<void> _loadSavedRecord() async {
    setState(() {
      _loadingRecord = true;
      _recordLoadFailed = false;
    });

    try {
      final pending = await _repo.history.pending();
      _pending = pending;
      if (pending != null) {
        _selectedRecordDate = DateTime.parse(pending['dayKey'] as String);
      }
      final record = await _repo.fetchDailyRecord(_selectedRecordDate);

      if (!mounted) return;

      setState(() {
        _savedRecord = record;
        _pending = pending;
        _legacyConfirmed = false;
        _diameterCorrection = false;
        _correctedDiameter = null;
        _isEditing = record == null || pending != null;

        if (record != null) {
          _wheelCtrl.text = record.rotations?.toString() ?? '';
          _distance = record.distance;
        } else {
          _wheelCtrl.clear();
          _distance = null;
        }
        if (pending != null) {
          _wheelCtrl.text = pending['rotations']?.toString() ?? '';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordLoadFailed = true;
          _message = '記録を読み込めませんでした。入力は保存できません。';
          _isErrorMessage = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecord = false;
        });
      }
    }
  }

  Future<void> _recalcDistance(String value) async {
    final seq = ++_calcSeq;

    final rotations = int.tryParse(value.trim());
    if (rotations == null) {
      if (!mounted) return;
      setState(() => _distance = null);
      return;
    }

    final diameter = _editingDiameter;
    final dist = diameter == null
        ? null
        : await _repo.previewDistanceFromRotations(rotations,
            wheelDiameterCm: diameter);

    if (!mounted) return;
    if (seq != _calcSeq) return;

    setState(() {
      _distance = dist;
    });
  }

  Future<void> _pickRecordDate() async {
    if (_saving || _pending != null) return;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedRecordDate,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      helpText: '記録する日付を選択',
      locale: const Locale('ja'),
    );

    if (picked == null) return;

    setState(() {
      _selectedRecordDate = picked;
      _message = null;
      _isErrorMessage = false;
    });

    await _loadSavedRecord();
  }

  Future<void> _openEnvironmentSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const BreedingEnvironmentEditScreen(
                focusWheelDiameter: true,
              )),
    );

    if (!mounted) return;
    await _refreshWheelDiameter();
  }

  Future<void> _save() async {
    final rotations = _rotations;

    if (rotations == null) {
      setState(() {
        _message = '回転数を入力してください。';
        _isErrorMessage = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _message = null;
      _isErrorMessage = false;
    });

    try {
      final record = await _repo.saveRotationRecord(
        rotations: rotations,
        date: _selectedRecordDate,
        expectedRecord: _savedRecord,
        legacyConfirmed: _legacyConfirmed,
        diameterCorrection: _diameterCorrection,
        wheelDiameterCm: _correctedDiameter,
      );
      // The confirmed measurement receipt remains authoritative if this auxiliary update fails.
      try {
        await OnboardingStateRepo().recordFirstMonitoringData('wheel');
      } catch (_) {}

      final savedDistance = record.distance;

      if (!mounted) return;

      setState(() {
        _savedRecord = record;
        _isEditing = false;
        _message =
            '${DateFormat('yyyy/MM/dd').format(_selectedRecordDate)} の記録を保存しました';
        _isErrorMessage = false;
      });

      widget.onSaved?.call(
        date: _selectedRecordDate,
        rotations: rotations,
        distanceMeters: savedDistance,
      );
    } on MissingWheelDiameterException {
      if (!mounted) return;

      setState(() {
        _message = '車輪の直径が未設定です。先に飼育環境を設定してください。';
        _isErrorMessage = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = MeasurementInputViewModel.failureMessage(e);
        _isErrorMessage = true;
      });
    } finally {
      _pending = await _repo.history.pending();
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _correctDiameter() async {
    final controller = _diameterCtrl;
    controller.text = _editingDiameter?.toString() ?? '';
    final value = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('この記録の車輪直径を訂正'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('測定時に使った直径を確認して入力してください。この記録だけを再計算します。'),
                  TextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: '確認した直径', suffixText: 'cm'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('戻る')),
                  TextButton(
                      onPressed: () {
                        final d = double.tryParse(controller.text);
                        if (d != null && d.isFinite && d > 0 && d <= 100) {
                          Navigator.pop(context, d);
                        }
                      },
                      child: const Text('確認した直径を使う'))
                ]));
    if (value == null || !mounted) return;
    setState(() {
      _correctedDiameter = value;
      _diameterCorrection = true;
    });
    await _recalcDistance(_wheelCtrl.text);
  }

  Future<void> _reviewLatest() async {
    if (_saving || _pending != null) return;
    setState(() => _saving = true);
    try {
      final latest = await _repo.fetchDailyRecord(_selectedRecordDate);
      if (!mounted) return;
      setState(() => _saving = false);
      final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('最新の記録を確認'),
                  content: Text(latest == null
                      ? 'この日の記録は現在ありません。入力を残して、新しい記録として保存できます。'
                      : '最新の記録: ${latest.rotations?.toString() ?? '距離を直接入力'} / ${_formatDistance(latest.distance)}\n入力を残して、この最新記録を訂正できます。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('戻る')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('入力を残して続ける'))
                  ]));
      if (yes == true && mounted) {
        setState(() {
          _savedRecord = latest;
          _legacyConfirmed = false;
          _recordLoadFailed = false;
          _correctedDiameter = null;
          _diameterCorrection = false;
          _message = '最新の記録を確認しました。入力は残しています。';
          _isErrorMessage = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = '最新の記録を確認できませんでした。入力は残しています。';
          _isErrorMessage = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _saving = true);
    try {
      final result = await _repo.history.retryPending();
      final day = DateTime.parse(result['dayKey'] as String);
      final current = await _repo.fetchDailyRecord(day);
      if (!mounted) return;
      _selectedRecordDate = day;
      _savedRecord = current;
      _correctedDiameter = null;
      _diameterCorrection = false;
      _wheelCtrl.text = current?.rotations?.toString() ?? '';
      _distance = current?.distance;
      _isEditing = current == null;
      _message = '保存を確認しました。';
      _isErrorMessage = false;
    } catch (error) {
      _message = MeasurementInputViewModel.failureMessage(error);
      _isErrorMessage = true;
    } finally {
      _pending = await _repo.history.pending();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelRecord() async {
    if (_savedRecord == null || _savedRecord!.subjectId == null) {
      setState(() {
        _message = '旧記録は現在のハムスターの記録として確認・保存してから取り消せます。';
        _isErrorMessage = true;
      });
      return;
    }
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('走った記録を取り消しますか？'),
                content: const Text('訂正前の内容と取消の履歴は残ります。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('戻る')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('取り消す'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _repo.cancelRecord(_savedRecord!,
          legacyConfirmed: _legacyConfirmed);
      if (!mounted) return;
      _savedRecord = null;
      _wheelCtrl.clear();
      _distance = null;
      _isEditing = true;
      _message = '記録を取り消しました。';
      _isErrorMessage = false;
    } catch (error) {
      _message = MeasurementInputViewModel.failureMessage(error);
      _isErrorMessage = true;
    } finally {
      _pending = await _repo.history.pending();
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDistance(double? meters) =>
      MeasurementInputViewModel.formatDistance(meters);

  bool _isDefaultYesterday(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final y = DateTime(yesterday.year, yesterday.month, yesterday.day);

    final d = date.toLocal();
    final target = DateTime(d.year, d.month, d.day);

    return target == y;
  }

  Widget _buildSavedSummary(BuildContext context) {
    final record = _savedRecord!;
    final secondary = AppTheme.secondaryText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.chipFill(
              AppTheme.accent,
              context,
              opacity: AppTheme.isDark(context) ? 0.12 : 0.08,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDefaultYesterday(record.date)
                          ? '昨日の記録済み'
                          : '${DateFormat('M/d').format(record.date)}の記録済み',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (record.rotations != null) '${record.rotations}回',
                        _formatDistance(record.distance),
                      ].join(' / '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: secondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _isEditing = true;
                          _message = null;
                          _isErrorMessage = false;
                        });
                        _recalcDistance(_wheelCtrl.text);
                      },
                child: const Text('編集'),
              ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _isErrorMessage
                      ? Theme.of(context).colorScheme.error
                      : AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.cardSurface(context);
    final secondary = AppTheme.secondaryText(context);
    final dateLabel = DateFormat('yyyy/MM/dd').format(_selectedRecordDate);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? 16 : 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x1A000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.chipFill(
                    AppTheme.accent,
                    context,
                    opacity: AppTheme.isDark(context) ? 0.14 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingRecord)
            const LinearProgressIndicator()
          else if (_savedRecord != null && !_isEditing)
            _buildSavedSummary(context)
          else ...[
            InkWell(
              onTap:
                  _saving || _pending != null ? null : () => _pickRecordDate(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.chipFill(
                    AppTheme.accent,
                    context,
                    opacity: AppTheme.isDark(context) ? 0.10 : 0.07,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _wheelCtrl,
              enabled: !_loadingWheel && !_saving && _pending == null,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '回し車の回転数',
                hintText: '例：1200',
                suffixText: '回',
                helperText: _loadingWheel
                    ? '車輪設定を確認中…'
                    : _wheelReady
                        ? '入力すると距離を自動計算します'
                        : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.chipFill(
                  AppTheme.accent,
                  context,
                  opacity: AppTheme.isDark(context) ? 0.12 : 0.08,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.straighten_rounded, size: 20, color: secondary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    '推定走行距離',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondary),
                  )),
                  const SizedBox(width: 8),
                  Text(
                    _formatDistance(_distance),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
            if (!_loadingWheel && !_wheelReady && _savedRecord == null) ...[
              const SizedBox(height: 12),
              StatusCard(
                key: const ValueKey('wheel-diameter-guide'),
                level: StatusCardLevel.caution,
                emphasize: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('距離の計算に、車輪の直径が必要です。'),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _openEnvironmentSettings,
                      child: const Text('車輪の直径を設定する'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_pending == null) ...[
              if (_savedRecord != null && _savedRecord!.subjectId == null)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('現在のハムスターの記録であることを確認'),
                    value: _legacyConfirmed,
                    onChanged: _saving
                        ? null
                        : (value) =>
                            setState(() => _legacyConfirmed = value ?? false)),
              if (_savedRecord != null) ...[
                const SizedBox(height: 8),
                Text(
                    _editingDiameter == null
                        ? 'この記録の車輪直径は不明です。確認した直径を入力してください。'
                        : 'この記録の車輪直径: ${_editingDiameter!.toStringAsFixed(1)} cm',
                    style: Theme.of(context).textTheme.bodySmall),
                Wrap(children: [
                  TextButton(
                      onPressed: _saving ? null : _correctDiameter,
                      child: Text(
                          _editingDiameter == null ? '直径を確認して入力' : '直径を訂正')),
                  TextButton(
                      onPressed: _saving || _savedRecord!.subjectId == null
                          ? null
                          : _cancelRecord,
                      child: const Text('この記録を取り消す'))
                ]),
              ],
            ] else ...[
              const Text('同期待ちの記録があります。同じ内容で再送します。'),
              TextButton(
                  onPressed: _saving ? null : _retry,
                  child: const Text('同じ内容を再送')),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isErrorMessage
                          ? Theme.of(context).colorScheme.error
                          : AppTheme.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            if (_isErrorMessage && _pending == null)
              TextButton(
                  onPressed: _saving ? null : _reviewLatest,
                  child: const Text('入力を残して最新の記録を確認')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? '保存中…' : 'この日付で保存'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
