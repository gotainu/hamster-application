import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../screens/breeding_environment_edit_screen.dart';
import '../services/distance_records_repo.dart';
import '../theme/app_theme.dart';

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

  final _wheelCtrl = TextEditingController();

  double? _distance;
  bool _loadingWheel = true;
  bool _saving = false;
  String? _message;
  bool _isErrorMessage = false;
  int _calcSeq = 0;

  @override
  void initState() {
    super.initState();

    _repo = widget.distanceRepo ?? DistanceRecordsRepo();
    _selectedRecordDate = widget.initialDate ?? DateTime.now();

    _wheelCtrl.addListener(() => _recalcDistance(_wheelCtrl.text));
    _refreshWheelDiameter();
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    super.dispose();
  }

  bool get _wheelReady => _repo.cachedWheelDiameterCm != null;

  int? get _rotations {
    final text = _wheelCtrl.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  bool get _canSave {
    return !_loadingWheel && _wheelReady && _rotations != null && !_saving;
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

  Future<void> _recalcDistance(String value) async {
    final seq = ++_calcSeq;

    final rotations = int.tryParse(value.trim());
    if (rotations == null) {
      if (!mounted) return;
      setState(() => _distance = null);
      return;
    }

    final dist = await _repo.previewDistanceFromRotations(rotations);

    if (!mounted) return;
    if (seq != _calcSeq) return;

    setState(() {
      _distance = dist;
    });
  }

  Future<void> _pickRecordDate() async {
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
  }

  Future<void> _openEnvironmentSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BreedingEnvironmentEditScreen(),
      ),
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
      await _repo.addWheelRotationRecord(
        rotations: rotations,
        date: _selectedRecordDate,
      );

      final savedDistance =
          _distance ?? await _repo.previewDistanceFromRotations(rotations);

      if (!mounted) return;

      setState(() {
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
        _message = '保存に失敗しました: $e';
        _isErrorMessage = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '-';

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }

    return '${meters.toStringAsFixed(0)} m';
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickRecordDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
            enabled: !_loadingWheel && _wheelReady,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
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
                Icon(
                  Icons.straighten_rounded,
                  size: 20,
                  color: secondary,
                ),
                const SizedBox(width: 10),
                Text(
                  '推定走行距離',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                ),
                const Spacer(),
                Text(
                  _formatDistance(_distance),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          if (!_loadingWheel && !_wheelReady) ...[
            const SizedBox(height: 12),
            Text(
              '車輪の直径が未設定です。回転数から距離を計算するために、先に飼育環境を設定してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondary,
                  ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openEnvironmentSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('飼育環境を設定する'),
            ),
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
      ),
    );
  }
}
