import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/weight_record.dart';
import '../services/weight_records_repo.dart';
import '../theme/app_theme.dart';

typedef WeightSavedCallback = void Function(WeightRecord record);

class WeightInputCard extends StatefulWidget {
  final WeightRecordsRepo? repo;
  final DateTime? initialDate;
  final WeightSavedCallback? onSaved;

  const WeightInputCard({
    super.key,
    this.repo,
    this.initialDate,
    this.onSaved,
  });

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
    return !_loading && !_saving && value != null && value > 0 && value <= 1000;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
      _error = false;
    });

    try {
      final results = await Future.wait([
        _repo.fetchByDate(_selectedDate),
        _repo.fetchLatestBefore(_selectedDate),
      ]);

      if (!mounted) return;

      final saved = results[0];
      final previous = results[1];

      setState(() {
        _savedRecord = saved;
        _previousRecord = previous;
        _editing = saved == null;

        _weightController.text =
            saved == null ? '' : _formatWeight(saved.weightGrams);
        _memoController.text = saved?.memo ?? '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '読み込みに失敗しました: $error';
        _error = true;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDate() async {
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

    setState(() => _selectedDate = picked);
    await _load();
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
      await _repo.save(
        date: _selectedDate,
        weightGrams: weight,
        memo: _memoController.text,
      );

      final record = WeightRecord(
        dayKey: DateFormat('yyyy-MM-dd').format(_selectedDate),
        date: _selectedDate,
        weightGrams: weight,
        memo: _memoController.text.trim(),
      );

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
        _message = '保存に失敗しました: $error';
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatWeight(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String? _comparisonText(WeightRecord record) {
    final previous = _previousRecord;
    if (previous == null) return null;

    final difference = record.weightGrams - previous.weightGrams;
    if (difference.abs() < 0.05) return '前回と同じ体重です';

    final sign = difference > 0 ? '+' : '';
    return '前回比 $sign${difference.toStringAsFixed(1)}g';
  }

  Widget _savedSummary(BuildContext context) {
    final record = _savedRecord!;
    final comparison = _comparisonText(record);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.24),
        ),
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
            onPressed: () => setState(() => _editing = true),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _pickDate,
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '例：食事前に測定',
                border: OutlineInputBorder(),
              ),
            ),
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
