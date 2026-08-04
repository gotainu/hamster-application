import 'package:flutter/material.dart';

import '../services/daily_checkin_repo.dart';
import '../theme/app_theme.dart';

class DailyConditionInputCard extends StatefulWidget {
  final DailyCheckinRepo? repo;
  final DateTime? date;
  final VoidCallback? onSaved;

  const DailyConditionInputCard({
    super.key,
    this.repo,
    this.date,
    this.onSaved,
  });

  @override
  State<DailyConditionInputCard> createState() =>
      _DailyConditionInputCardState();
}

class _DailyConditionInputCardState extends State<DailyConditionInputCard> {
  late final DailyCheckinRepo _repo;
  late final DateTime _date;

  final _memoCtrl = TextEditingController();

  DailyCondition? _condition;
  DailyCheckin? _savedCheckin;
  final Set<String> _selectedTags = <String>{};

  bool _isEditing = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  bool _isErrorMessage = false;

  static const _concernTags = <_ConcernTag>[
    _ConcernTag(id: 'appetite', label: '食欲'),
    _ConcernTag(id: 'water', label: '水'),
    _ConcernTag(id: 'poop', label: 'うんち'),
    _ConcernTag(id: 'movement', label: '動き'),
    _ConcernTag(id: 'breathing', label: '呼吸'),
    _ConcernTag(id: 'chewing', label: 'かじり'),
    _ConcernTag(id: 'other', label: 'その他'),
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? DailyCheckinRepo();
    _date = widget.date ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _isErrorMessage = false;
    });

    try {
      final checkin = await _repo.fetchByDate(_date);

      if (!mounted) return;

      if (checkin != null) {
        setState(() {
          _savedCheckin = checkin;
          _condition = checkin.condition;
          _isEditing = false;
          _selectedTags
            ..clear()
            ..addAll(checkin.concernTags);
          _memoCtrl.text = checkin.memo;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '読み込みに失敗しました: $e';
        _isErrorMessage = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _showConcernFields {
    return _condition == DailyCondition.slightlyConcerned ||
        _condition == DailyCondition.veryConcerned;
  }

  bool get _canSave {
    return !_isLoading && !_isSaving && _condition != null;
  }

  String _conditionLabel(DailyCondition condition) {
    switch (condition) {
      case DailyCondition.normal:
        return 'いつも通り';
      case DailyCondition.slightlyConcerned:
        return '少し気になる';
      case DailyCondition.veryConcerned:
        return 'かなり心配';
    }
  }

  IconData _conditionIcon(DailyCondition condition) {
    switch (condition) {
      case DailyCondition.normal:
        return Icons.check_circle_outline_rounded;
      case DailyCondition.slightlyConcerned:
        return Icons.help_outline_rounded;
      case DailyCondition.veryConcerned:
        return Icons.warning_amber_rounded;
    }
  }

  Color _conditionColor(BuildContext context, DailyCondition condition) {
    switch (condition) {
      case DailyCondition.normal:
        return AppTheme.envGood;
      case DailyCondition.slightlyConcerned:
        return AppTheme.envCaution;
      case DailyCondition.veryConcerned:
        return AppTheme.envDanger;
    }
  }

  void _selectCondition(DailyCondition condition) {
    setState(() {
      _condition = condition;
      _message = null;
      _isErrorMessage = false;

      if (condition == DailyCondition.normal) {
        _selectedTags.clear();
        _memoCtrl.clear();
      }
    });
  }

  void _toggleTag(String id) {
    setState(() {
      if (_selectedTags.contains(id)) {
        _selectedTags.remove(id);
      } else {
        _selectedTags.add(id);
      }
      _message = null;
      _isErrorMessage = false;
    });
  }

  Future<void> _save() async {
    final condition = _condition;

    if (condition == null) {
      setState(() {
        _message = '今日の様子を選んでください。';
        _isErrorMessage = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _message = null;
      _isErrorMessage = false;
    });

    try {
      await _repo.saveDailyCheckin(
        date: _date,
        condition: condition,
        concernTags: _showConcernFields ? _selectedTags.toList() : const [],
        memo: _showConcernFields ? _memoCtrl.text : '',
      );

      if (!mounted) return;

      setState(() {
        _savedCheckin = DailyCheckin(
          dayKey: _repo.dateKeyLocal(_date),
          date: _repo.normalizeLocalDay(_date),
          condition: condition,
          concernTags: _showConcernFields ? _selectedTags.toList() : const [],
          memo: _showConcernFields ? _memoCtrl.text.trim() : '',
        );
        _isEditing = false;
        _message = '今日の様子を保存しました';
        _isErrorMessage = false;
      });

      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = '保存に失敗しました: $e';
        _isErrorMessage = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _concernTagLabel(String id) {
    for (final tag in _concernTags) {
      if (tag.id == id) return tag.label;
    }
    return id;
  }

  Widget _buildSavedSummary(BuildContext context) {
    final checkin = _savedCheckin!;
    final color = _conditionColor(context, checkin.condition);
    final secondary = AppTheme.secondaryText(context);

    final tagText = checkin.concernTags.isEmpty
        ? ''
        : checkin.concernTags.map(_concernTagLabel).join('・');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.chipFill(
              color,
              context,
              opacity: AppTheme.isDark(context) ? 0.12 : 0.08,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.26),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _conditionIcon(checkin.condition),
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日の様子：${_conditionLabel(checkin.condition)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                    ),
                    if (tagText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '気になる内容：$tagText',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: secondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    if (checkin.memo.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        checkin.memo.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: secondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    _message = null;
                    _isErrorMessage = false;
                  });
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                  Icons.favorite_border_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日の様子',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '30秒で今日の状態を残せます。気になる時だけ詳しく入力してください。',
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
          if (_isLoading)
            const LinearProgressIndicator()
          else if (_savedCheckin != null && !_isEditing)
            _buildSavedSummary(context)
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DailyCondition.values.map((condition) {
                final selected = _condition == condition;
                final color = _conditionColor(context, condition);

                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => _selectCondition(condition),
                  avatar: Icon(
                    _conditionIcon(condition),
                    size: 18,
                    color: selected ? color : secondary,
                  ),
                  label: Text(_conditionLabel(condition)),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? color : null,
                  ),
                  selectedColor: color.withValues(alpha: 0.16),
                  side: BorderSide(
                    color: selected
                        ? color.withValues(alpha: 0.55)
                        : AppTheme.quickActionBorder(context),
                  ),
                );
              }).toList(),
            ),
            if (_showConcernFields) ...[
              const SizedBox(height: 18),
              Text(
                '気になる内容',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _concernTags.map((tag) {
                  final selected = _selectedTags.contains(tag.id);

                  return FilterChip(
                    selected: selected,
                    onSelected: (_) => _toggleTag(tag.id),
                    label: Text(tag.label),
                    selectedColor: AppTheme.accent.withValues(alpha: 0.16),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.accent.withValues(alpha: 0.50)
                          : AppTheme.quickActionBorder(context),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _memoCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  hintText: '例：夜あまり出てこなかった',
                  border: OutlineInputBorder(),
                ),
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
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? '保存中…' : '今日の様子を保存'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConcernTag {
  final String id;
  final String label;

  const _ConcernTag({
    required this.id,
    required this.label,
  });
}
