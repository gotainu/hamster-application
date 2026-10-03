import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/app_analytics.dart';
import '../services/daily_checkin_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../theme/app_theme.dart';

class DailyConditionInputCard extends StatefulWidget {
  final DailyCheckinStore? repo;
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
  late final DailyCheckinStore _repo;
  late final DateTime _date;

  final _memoCtrl = TextEditingController();
  final Set<String> _selectedTags = <String>{};

  DailyCondition? _condition;
  DailyCheckin? _savedCheckin;
  bool _isEditing = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _memoExpanded = false;
  String? _message;

  static const _brandAsset = 'store_assets/icons/google_play_icon_512.png';

  static const _observations = <_ObservationChoice>[
    _ObservationChoice(
      id: 'appetite',
      label: '食欲',
      icon: Icons.restaurant_rounded,
    ),
    _ObservationChoice(
      id: 'water',
      label: '飲水',
      icon: Icons.water_drop_rounded,
    ),
    _ObservationChoice(
      id: 'elimination',
      label: '排泄',
      icon: Icons.grain_rounded,
    ),
    _ObservationChoice(
      id: 'breathing',
      label: '呼吸',
      icon: Icons.air_rounded,
    ),
    _ObservationChoice(
      id: 'movement',
      label: '姿勢・動き',
      icon: Icons.directions_run_rounded,
    ),
    _ObservationChoice(
      id: 'eyesNose',
      label: '目・鼻',
      icon: Icons.visibility_rounded,
    ),
    _ObservationChoice(
      id: 'coatSkin',
      label: '被毛・皮膚',
      icon: Icons.auto_awesome_rounded,
    ),
    _ObservationChoice(
      id: 'other',
      label: 'その他',
      icon: Icons.more_horiz_rounded,
    ),
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
          _memoExpanded = checkin.memo.trim().isNotEmpty;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '読み込みに失敗しました');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _showConcernFields =>
      _condition == DailyCondition.slightlyConcerned ||
      _condition == DailyCondition.veryConcerned;

  bool get _canSave =>
      !_isLoading &&
      !_isSaving &&
      _condition != null &&
      (!_showConcernFields || _selectedTags.isNotEmpty);

  bool get _showSafetyGuidance =>
      _condition == DailyCondition.veryConcerned ||
      _selectedTags.contains('breathing');

  String _conditionLabel(DailyCondition condition) => switch (condition) {
        DailyCondition.normal => 'いつも通り',
        DailyCondition.slightlyConcerned => '少し違う',
        DailyCondition.veryConcerned => '心配',
      };

  Color _conditionColor(BuildContext context, DailyCondition condition) {
    return switch (condition) {
      DailyCondition.normal => AppTheme.envGood,
      DailyCondition.slightlyConcerned =>
        AppTheme.environmentAccentForContext(context, '注意'),
      DailyCondition.veryConcerned => AppTheme.envDanger,
    };
  }

  void _selectCondition(DailyCondition condition) {
    setState(() {
      _condition = condition;
      _message = null;

      if (condition == DailyCondition.normal) {
        _selectedTags.clear();
        _memoCtrl.clear();
        _memoExpanded = false;
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
    });
  }

  Future<void> _save() async {
    final condition = _condition;
    if (condition == null || (_showConcernFields && _selectedTags.isEmpty)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _message = null;
    });

    final tags = _showConcernFields
        ? _selectedTags.toList(growable: false)
        : const <String>[];
    final observationLevels = buildDailyObservationLevels(
      condition: condition,
      concernTags: tags,
    );
    final memo = _showConcernFields ? _memoCtrl.text.trim() : '';

    try {
      await _repo.saveDailyCheckin(
        date: _date,
        condition: condition,
        concernTags: tags,
        observationLevels: observationLevels,
        memo: memo,
      );
      if (!mounted) return;

      setState(() {
        _savedCheckin = DailyCheckin(
          dayKey: _repo.dateKeyLocal(_date),
          date: _repo.normalizeLocalDay(_date),
          condition: condition,
          concernTags: tags,
          observationLevels: observationLevels,
          memo: memo,
        );
        _isEditing = false;
      });

      // 進捗記録が失敗しても、ユーザーの大切な日次記録は失敗扱いにしない。
      try {
        await OnboardingStateRepo().recordFirstMonitoringData('daily_checkin');
      } catch (_) {}

      await AppAnalytics.logDailyInputComplete(
        condition: condition.name,
        concernTagCount: tags.length,
        hasMemo: memo.isNotEmpty,
      );
      widget.onSaved?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '保存に失敗しました');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _observationLabel(String id) {
    for (final observation in _observations) {
      if (observation.id == id) return observation.label;
    }
    return switch (id) {
      'poop' => '排泄',
      'chewing' => 'かじり方',
      _ => id,
    };
  }

  Widget _buildSavedSummary(BuildContext context) {
    final checkin = _savedCheckin!;
    final color = _conditionColor(context, checkin.condition);
    final tagText = checkin.concernTags
        .map(_observationLabel)
        .where((label) => label.isNotEmpty)
        .join('・');

    return Semantics(
      liveRegion: true,
      label: '今日の観察を保存しました',
      child: Container(
        key: const ValueKey('saved-summary'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppTheme.quickRecordObjectSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.42)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.done_rounded, color: color, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '記録しました',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    tagText.isEmpty
                        ? _conditionLabel(checkin.condition)
                        : '${_conditionLabel(checkin.condition)}・$tagText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isEditing = true;
                _message = null;
              }),
              child: const Text('編集'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Column(
      key: const ValueKey('checkin-editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: DailyCondition.values.map((condition) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: condition == DailyCondition.veryConcerned ? 0 : 7,
                ),
                child: _ConditionChoiceCard(
                  label: _conditionLabel(condition),
                  color: _conditionColor(context, condition),
                  selected: _condition == condition,
                  onTap: () => _selectCondition(condition),
                ),
              ),
            );
          }).toList(),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: !_showConcernFields
              ? const SizedBox.shrink(key: ValueKey('no-concern-fields'))
              : Padding(
                  key: const ValueKey('concern-fields'),
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '気になるところ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = (constraints.maxWidth - 8) / 2;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _observations.map((observation) {
                              return SizedBox(
                                width: itemWidth,
                                child: _ObservationTile(
                                  observation: observation,
                                  selected:
                                      _selectedTags.contains(observation.id),
                                  onTap: () => _toggleTag(observation.id),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      if (_showSafetyGuidance) ...[
                        const SizedBox(height: 10),
                        const _SafetyGuidance(),
                      ],
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _memoExpanded = !_memoExpanded),
                        icon: Icon(
                          _memoExpanded
                              ? Icons.remove_rounded
                              : Icons.add_rounded,
                        ),
                        label: Text(_memoExpanded ? 'メモを閉じる' : 'メモ（任意）'),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: !_memoExpanded
                            ? const SizedBox.shrink(
                                key: ValueKey('memo-closed'),
                              )
                            : Padding(
                                key: const ValueKey('memo-open'),
                                padding: const EdgeInsets.only(top: 2),
                                child: TextField(
                                  controller: _memoCtrl,
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 240,
                                  decoration: InputDecoration(
                                    hintText: 'メモ',
                                    filled: true,
                                    fillColor:
                                        AppTheme.quickRecordObjectSurface(
                                      context,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 10),
          Text(
            _message!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _canSave ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSaving ? '保存中…' : '記録する'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(26));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.quickRecordObjectSurface(context),
            borderRadius: radius,
            border:
                Border.all(color: AppTheme.quickRecordObjectBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      _brandAsset,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '今日の様子は？',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const LinearProgressIndicator()
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _savedCheckin != null && !_isEditing
                      ? _buildSavedSummary(context)
                      : _buildEditor(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionChoiceCard extends StatelessWidget {
  const _ConditionChoiceCard({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 72,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: AppTheme.isDark(context) ? 0.22 : 0.15)
              : AppTheme.quickRecordChoiceSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.72)
                : AppTheme.quickRecordObjectBorder(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 22 : 10,
                    height: selected ? 5 : 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.38),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
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

class _ObservationTile extends StatelessWidget {
  const _ObservationTile({
    required this.observation,
    required this.selected,
    required this.onTap,
  });

  final _ObservationChoice observation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.quickRecordGlow(context);

    return Semantics(
      button: true,
      selected: selected,
      label: observation.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        height: 52,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: AppTheme.isDark(context) ? 0.20 : 0.13)
              : AppTheme.quickRecordChoiceSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.68)
                : AppTheme.quickRecordObjectBorder(context),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    observation.icon,
                    color: selected ? accent : AppTheme.secondaryText(context),
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      observation.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.done_rounded, color: accent, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyGuidance extends StatelessWidget {
  const _SafetyGuidance();

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.envDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.isDark(context) ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital_outlined, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '強い異変がある場合は動物病院へ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationChoice {
  final String id;
  final String label;
  final IconData icon;

  const _ObservationChoice({
    required this.id,
    required this.label,
    required this.icon,
  });
}
