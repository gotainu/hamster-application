import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/weight_record.dart';
import '../services/weight_records_repo.dart';
import '../services/measurement_history_client.dart';
import '../services/onboarding_state_repo.dart';
import '../theme/app_theme.dart';
import '../viewmodels/measurement_input_view_model.dart';

typedef WeightSavedCallback = void Function(WeightRecord record);

class WeightInputCard extends StatefulWidget {
  final WeightRecordsRepo? repo;
  final DateTime? initialDate;
  final WeightSavedCallback? onSaved;

  const WeightInputCard({super.key, this.repo, this.initialDate, this.onSaved});

  @override
  State<WeightInputCard> createState() => _WeightInputCardState();
}

class _WeightInputCardState extends State<WeightInputCard> {
  late final WeightRecordsRepo _repo;
  late DateTime _selectedDate;

  final _weightController = TextEditingController();
  final _memoController = TextEditingController();

  WeightRecord? _savedRecord;
  WeightRecord? _previousRecord;

  bool _loading = true;
  bool _saving = false;
  bool _editing = true;
  String? _message;
  bool _error = false;
  bool _loadFailed = false;
  bool _legacyConfirmed = false;
  Map<String, dynamic>? _timing;
  Map<String, dynamic>? _pending;
  String? _originalDayKey;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? WeightRecordsRepo();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _weightController.addListener(_handleWeightChanged);
    _load();
  }

  void _handleWeightChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _weightController.removeListener(_handleWeightChanged);
    _weightController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  double? get _weight {
    final normalized = _weightController.text.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  bool get _canSave {
    final value = _weight;
    return !_loadFailed &&
        !_loading &&
        !_saving &&
        _pending == null &&
        _timing != null &&
        (_savedRecord?.subjectId != null ||
            _savedRecord == null ||
            _legacyConfirmed) &&
        value != null &&
        value > 0 &&
        value <= 1000;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _message = null;
      _error = false;
    });

    try {
      final pending = await _repo.history.pending();
      _pending = pending;
      if (pending != null) {
        _selectedDate = DateTime.parse(pending['dayKey'] as String);
      }
      final results = await Future.wait([
        _repo.fetchByDate(_selectedDate),
        _repo.fetchLatestBefore(_selectedDate),
      ]);

      if (!mounted) return;

      final saved = results[0];
      final previous = results[1];

      setState(() {
        _savedRecord = saved;
        _pending = pending;
        _originalDayKey = null;
        _legacyConfirmed = false;
        _timing = saved?.timing;
        if (pending != null) {
          _timing = pending['timing'] is Map
              ? Map<String, dynamic>.from(pending['timing'] as Map)
              : null;
        }
        _previousRecord = previous;
        _editing = saved == null || pending != null;

        _weightController.text =
            saved == null ? '' : _formatWeight(saved.weightGrams);
        _memoController.text = pending?['memo'] as String? ?? saved?.memo ?? '';
        if (pending?['weightGrams'] is num) {
          _weightController.text =
              _formatWeight((pending!['weightGrams'] as num).toDouble());
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _message = '読み込みに失敗しました: $error';
        _error = true;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDate({bool correction = false}) async {
    if (_saving || _pending != null) return;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: '体重を測定した日',
      locale: const Locale('ja'),
    );

    if (picked == null) return;

    if (correction && _savedRecord != null) {
      setState(() {
        _originalDayKey = _savedRecord!.dayKey;
        _selectedDate = picked;
        if (_timing?['precision'] == 'date_only' ||
            _timing?['timePrecision'] == 'date_only') {
          _timing = measurementDateTiming(_repo.dateKeyLocal(picked));
        }
      });
    } else {
      setState(() => _selectedDate = picked);
      await _load();
    }
  }

  Future<void> _save() async {
    final weight = _weight;
    if (weight == null || weight <= 0 || weight > 1000) {
      setState(() {
        _message = '体重を1〜1000gの範囲で入力してください。';
        _error = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _message = null;
      _error = false;
    });

    try {
      final record = await _repo.saveRecord(
        date: _selectedDate,
        weightGrams: weight,
        memo: _memoController.text,
        expectedRecord: _savedRecord,
        timing: _timing,
        legacyConfirmed: _legacyConfirmed,
        originalDayKey: _originalDayKey,
      );
      // The confirmed measurement receipt remains authoritative if this auxiliary update fails.
      try {
        await OnboardingStateRepo().recordFirstMonitoringData('weight');
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _savedRecord = record;
        _editing = false;
        _message = '体重を記録しました。';
      });

      widget.onSaved?.call(record);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = MeasurementInputViewModel.failureMessage(error);
        _error = true;
      });
    } finally {
      _pending = await _repo.history.pending();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviewLatest() async {
    if (_saving || _pending != null) return;
    setState(() => _saving = true);
    try {
      final sourceDate = _originalDayKey == null
          ? _selectedDate
          : DateTime.parse(_originalDayKey!);
      final latest = await _repo.fetchByDate(sourceDate);
      if (!mounted) return;
      setState(() => _saving = false);
      final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('最新の記録を確認'),
                  content: Text(latest == null
                      ? 'この日の記録は現在ありません。入力を残して、新しい記録として保存できます。'
                      : '最新の体重: ${_formatWeight(latest.weightGrams)}g\n入力を残して、この最新記録を訂正できます。'),
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
          if (latest == null) _originalDayKey = null;
          _legacyConfirmed = false;
          _loadFailed = false;
          _message = '最新の記録を確認しました。入力は残しています。';
          _error = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = '最新の記録を確認できませんでした。入力は残しています。';
          _error = true;
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
      final current = await _repo.fetchByDate(day);
      if (!mounted) return;
      _selectedDate = day;
      _savedRecord = current;
      _originalDayKey = null;
      _timing = current?.timing;
      _weightController.text =
          current == null ? '' : _formatWeight(current.weightGrams);
      _memoController.text = current?.memo ?? '';
      _editing = current == null;
      if (current != null) widget.onSaved?.call(current);
      _message = '保存を確認しました。';
      _error = false;
    } catch (error) {
      _message = MeasurementInputViewModel.failureMessage(error);
      _error = true;
    } finally {
      _pending = await _repo.history.pending();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelRecord() async {
    if (_savedRecord == null || _savedRecord!.subjectId == null) {
      setState(() {
        _message = '旧記録は現在のハムスターの記録として確認・保存してから取り消せます。';
        _error = true;
      });
      return;
    }
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('体重の記録を取り消しますか？'),
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
      _weightController.clear();
      _memoController.clear();
      _editing = true;
      _timing = null;
      _message = '記録を取り消しました。';
      _error = false;
    } catch (error) {
      _message = MeasurementInputViewModel.failureMessage(error);
      _error = true;
    } finally {
      _pending = await _repo.history.pending();
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatWeight(double value) =>
      MeasurementInputViewModel.formatWeight(value);
  String? _comparisonText(WeightRecord record) =>
      MeasurementInputViewModel.weightComparison(record, _previousRecord);

  Widget _savedSummary(BuildContext context) {
    final record = _savedRecord!;
    final comparison = _comparisonText(record);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatWeight(record.weightGrams)}g',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('yyyy/M/d').format(record.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                ),
                if (comparison != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    comparison,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => setState(() => _editing = true),
            child: const Text('編集'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTheme.secondaryText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '体重',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '毎日ではなく、週1回程度を目安に記録します。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed:
                    _saving || _pending != null ? null : () => _pickDate(),
                tooltip: '測定日を変更',
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LinearProgressIndicator()
          else if (_savedRecord != null && !_editing)
            _savedSummary(context)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    enabled: !_saving && _pending == null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,4}([.,]\d{0,1})?$'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: '体重',
                      hintText: '例：142.5',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    DateFormat('M/d').format(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              enabled: !_saving && _pending == null,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '例：食事前に測定',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_pending == null) ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('weight-timing'),
                isExpanded: true,
                value: MeasurementInputViewModel.timingChoice(_timing),
                decoration: const InputDecoration(labelText: '測定時期の確認'),
                items: [
                  if (MeasurementInputViewModel.timingChoice(_timing) ==
                      'instant')
                    const DropdownMenuItem(
                        value: 'instant', child: Text('保存済みの測定時刻を維持')),
                  DropdownMenuItem(
                      value: 'date_only', child: Text('選んだ日に測定（時刻は不要）')),
                  DropdownMenuItem(value: 'unknown', child: Text('測定時期は不明'))
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _timing = value == 'instant'
                        ? _timing
                        : value == 'date_only'
                            ? measurementDateTiming(
                                _repo.dateKeyLocal(_selectedDate))
                            : {...unknownMeasurementTiming}),
              ),
              if (_savedRecord != null && _savedRecord!.subjectId == null)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('現在のハムスターの記録であることを確認'),
                    value: _legacyConfirmed,
                    onChanged: _saving
                        ? null
                        : (value) =>
                            setState(() => _legacyConfirmed = value ?? false)),
              if (_savedRecord != null)
                Wrap(children: [
                  TextButton(
                      onPressed:
                          _saving ? null : () => _pickDate(correction: true),
                      child: const Text('日付を訂正')),
                  TextButton(
                      onPressed: _saving || _savedRecord!.subjectId == null
                          ? null
                          : _cancelRecord,
                      child: const Text('この記録を取り消す')),
                ]),
            ] else ...[
              const Text('同期待ちの記録があります。同じ内容で再送します。'),
              TextButton(
                  onPressed: _saving ? null : _retry,
                  child: const Text('同じ内容を再送')),
            ],
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _error
                          ? Theme.of(context).colorScheme.error
                          : AppTheme.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            if (_error && _pending == null)
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
                label: Text(_saving ? '保存中…' : '体重を保存'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
