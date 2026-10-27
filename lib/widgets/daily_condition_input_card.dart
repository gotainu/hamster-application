import 'dart:ui';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/observation_catalog.dart';
import '../models/daily_observation_history.dart';
import '../viewmodels/observation_input_view_model.dart';
import 'observation_timing_input.dart';
import '../models/care_action_catalog.dart';
import '../services/daily_care_actions_repo.dart';
import '../services/care_continuity_repo.dart';
import '../models/daily_care_actions.dart';
import '../viewmodels/care_action_input_view_model.dart';
import 'care_action_input_fields.dart';
import '../services/app_analytics.dart';
import '../services/daily_checkin_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../theme/app_theme.dart';

class DailyConditionInputCard extends StatefulWidget {
  final DailyCheckinStore? repo;
  final DateTime? date;
  final VoidCallback? onSaved;
  final List<ObservationCatalogItem> catalog;
  final CareActionStore? careRepo;
  final List<CareActionCatalogItem> careCatalog;
  final VoidCallback? onCareSaved;
  final CareContinuitySource? continuitySource;

  const DailyConditionInputCard({
    super.key,
    this.repo,
    this.date,
    this.onSaved,
    this.catalog = observationCatalog,
    this.careRepo,
    this.careCatalog = careActionCatalog,
    this.onCareSaved,
    this.continuitySource,
  });

  @override
  State<DailyConditionInputCard> createState() =>
      _DailyConditionInputCardState();
}

class _DailyConditionInputCardState extends State<DailyConditionInputCard> {
  late final DailyCheckinStore _repo;
  late final DateTime _date;
  late final CareActionStore _careRepo;
  late final CareActionInputViewModel _care;
  bool _healthDirty = false;
  ObservationInputViewModel? _observation;
  bool _healthLoadFailed = false;
  String? _careMessage;
  bool _careLoadFailed = false;
  CareActionMutation? _rewardRetry;

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

  List<_ObservationChoice> get _observations => [
        for (final item in activeObservationItems(catalog: widget.catalog))
          _ObservationChoice(
            id: item.id,
            label: item.label,
            icon: _observationIcon(item.id),
          ),
      ];

  // Presentation only: labels, ordering and available items come from Catalog.
  static IconData _observationIcon(String id) => switch (id) {
        'appetite' => Icons.restaurant_rounded,
        'water' => Icons.water_drop_rounded,
        'elimination' => Icons.grain_rounded,
        'breathing' => Icons.air_rounded,
        'movement' => Icons.directions_run_rounded,
        'eyesNose' => Icons.visibility_rounded,
        'coatSkin' => Icons.auto_awesome_rounded,
        _ => Icons.more_horiz_rounded,
      };

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? DailyCheckinRepo();
    _date = widget.date ?? DateTime.now();
    if (_repo is DailyObservationStore) {
      _observation = ObservationInputViewModel(
          date: _repo.normalizeLocalDay(_date),
          dayKey: _repo.dateKeyLocal(_date));
    }
    _careRepo = widget.careRepo ?? DailyCareActionsRepo();
    _care = CareActionInputViewModel(
        dayKey: _repo.dateKeyLocal(_date), catalog: widget.careCatalog);
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
      DailyCheckin? checkin;
      if (_repo is DailyObservationStore) {
        final loaded =
            await (_repo as DailyObservationStore).loadObservation(_date);
        _observation!.load(loaded);
        _healthLoadFailed = !loaded.serverConfirmed;
        checkin = loaded.current;
      } else {
        checkin = await _repo.fetchByDate(_date);
      }
      if (!mounted) return;

      final loadedCheckin = checkin;
      if (loadedCheckin != null) {
        setState(() {
          _savedCheckin = loadedCheckin;
          _condition = loadedCheckin.condition;
          _healthDirty = false;
          _isEditing = false;
          _selectedTags
            ..clear()
            ..addAll(normalizeObservationIds(
              loadedCheckin.concernTags,
              catalog: widget.catalog,
            ));
          _memoCtrl.text = loadedCheckin.memo;
          _memoExpanded = loadedCheckin.memo.trim().isNotEmpty;
        });
      }
      if (loadedCheckin == null &&
          (_observation?.state.serverConfirmed ?? true)) {
        setState(() {
          _savedCheckin = null;
          _condition = null;
          _healthDirty = false;
          _selectedTags.clear();
          _memoCtrl.clear();
          _memoExpanded = false;
          _isEditing = true;
        });
      }
      final pending = _observation?.state.pending;
      if (pending != null) {
        setState(() {
          _isEditing = true;
          _message = '今日の様子は同期待ちです。まだ保存確定ではありません。';
          if (pending.operation != ObservationOperation.cancel) {
            _condition = DailyCondition.values.byName(pending.condition!);
            _selectedTags
              ..clear()
              ..addAll(pending.concernTags);
            _memoCtrl.text = pending.memo;
            _memoExpanded = pending.memo.isNotEmpty;
            _healthDirty = true;
            _observation!.operation = pending.operation;
            _observation!.timing = pending.timing;
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _healthLoadFailed = true;
        _message = '今日の様子を確認できません。保存済みとして扱いません。';
      });
    } finally {
      try {
        final result = await _careRepo.load(_care.dayKey);
        if (mounted) {
          setState(() {
            _care.load(result);
            _careLoadFailed = false;
            _careMessage =
                result.pending != null ? 'ケア記録は同期待ちです。確定した報酬はまだありません。' : null;
            if ((result.record != null || result.pending != null) &&
                _observation?.state.pending == null) {
              _isEditing = false;
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _careLoadFailed = true;
            _careMessage = 'ケア記録を確認できません。今日の様子は保存できます。';
          });
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _showConcernFields =>
      _condition == DailyCondition.slightlyConcerned ||
      _condition == DailyCondition.veryConcerned;

  bool get _healthConfirmed =>
      !_healthLoadFailed && (_observation == null || _observation!.canSave);

  bool get _canSave =>
      !_isLoading &&
      !_isSaving &&
      ((_healthDirty &&
              _condition != null &&
              (!_showConcernFields || _selectedTags.isNotEmpty)) ||
          (!_careLoadFailed && _care.canConfirmAndSave)) &&
      (!_healthDirty ||
          (!_showConcernFields || _selectedTags.isNotEmpty) &&
              _healthConfirmed);

  bool get _canSaveHealthOnly =>
      !_isLoading &&
      !_isSaving &&
      _healthDirty &&
      _healthConfirmed &&
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
      _updateHealthDirty();
    });
  }

  void _updateHealthDirty() {
    final saved = _savedCheckin;
    if (saved == null) {
      _healthDirty = _condition != null;
      return;
    }
    final savedTags =
        normalizeObservationIds(saved.concernTags, catalog: widget.catalog)
            .toSet();
    _healthDirty = _condition != saved.condition ||
        _selectedTags.length != savedTags.length ||
        !_selectedTags.every(savedTags.contains) ||
        _memoCtrl.text.trim() != saved.memo.trim() ||
        (_observation?.operation == ObservationOperation.newObservation &&
            _observation?.timing != null) ||
        (_observation?.operation == ObservationOperation.correction &&
            _observation?.timing != null &&
            jsonEncode(_observation!.timing!.toMap()) !=
                jsonEncode(saved.timing?.toMap()));
  }

  void _toggleTag(String id) {
    setState(() {
      if (_selectedTags.contains(id)) {
        _selectedTags.remove(id);
      } else {
        _selectedTags.add(id);
      }
      _updateHealthDirty();
      _message = null;
    });
  }

  Future<void> _save(
      {bool retryCare = false,
      bool cancelCare = false,
      bool healthOnly = false}) async {
    if (_isSaving || _isLoading) return;
    final condition = _condition;
    final saveHealth =
        !retryCare && !cancelCare && _healthDirty && condition != null;
    if (!healthOnly &&
        !retryCare &&
        !cancelCare &&
        !_careLoadFailed &&
        (!_healthDirty || !_showConcernFields || _selectedTags.isNotEmpty)) {
      _care.confirmDefaults();
    }
    final saveCare = !healthOnly &&
        !_careLoadFailed &&
        (_care.canSave || retryCare || cancelCare);
    if ((!saveHealth && !saveCare) ||
        (saveHealth &&
            (!_healthConfirmed ||
                (_showConcernFields && _selectedTags.isEmpty)))) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _message = null;
      _careMessage = null;
    });
    var healthSaved = false;
    var careSaved = false;
    if (saveHealth) {
      final tags = _showConcernFields
          ? _selectedTags.toList(growable: false)
          : const <String>[];
      final levels = buildDailyObservationLevels(
          condition: condition, concernTags: tags, catalog: widget.catalog);
      final memo = _showConcernFields ? _memoCtrl.text.trim() : '';
      try {
        ObservationSaveResult? historyResult;
        if (_repo is DailyObservationStore) {
          historyResult = await (_repo as DailyObservationStore)
              .saveObservation(_observation!
                  .mutation(condition: condition, tags: tags, memo: memo));
          if (!historyResult.confirmed) {
            final state = _observation!.state;
            _observation!.state = ObservationLoadResult(
                current: state.current,
                pending: historyResult.mutation,
                revision: state.revision,
                subjectId: state.subjectId,
                hasProfile: state.hasProfile);
            if (mounted) {
              setState(() => _message = '今日の様子は同期待ちです。まだ保存確定ではありません。');
            }
          }
          healthSaved = historyResult.confirmed;
        } else {
          await _repo.saveDailyCheckin(
              date: _date,
              condition: condition,
              concernTags: tags,
              observationLevels: levels,
              memo: memo);
          healthSaved = true;
        }
        if (mounted && healthSaved) {
          if (historyResult != null) {
            await _applyHistoryResult(historyResult);
          } else {
            setState(() {
              _healthDirty = false;
              _savedCheckin = DailyCheckin(
                  dayKey: _repo.dateKeyLocal(_date),
                  date: _repo.normalizeLocalDay(_date),
                  condition: condition,
                  concernTags: tags,
                  observationLevels: levels,
                  memo: memo);
            });
          }
        }
        // Saved records and care submission must not wait for analytics or
        // onboarding connectivity. The same existing effects run separately.
        if (healthSaved) {
          unawaited(_recordHealthProgress(condition, tags, memo));
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _healthLoadFailed = _observation != null;
            _message = '今日の様子の保存に失敗しました。入力は残っています。';
          });
        }
      }
    }
    if (saveCare) {
      try {
        final result = await _careRepo.save(_care.mutation(cancel: cancelCare));
        careSaved = result.confirmed;
        if (mounted) {
          setState(() {
            _care.apply(result);
            _rewardRetry = result.confirmed &&
                    (result.rewardStatus == 'failed' ||
                        result.confirmationPending)
                ? result.mutation
                : null;
            _careMessage = !result.confirmed
                ? 'ケア記録は同期待ちです。確定した報酬はまだありません。'
                : cancelCare
                    ? 'ケア記録を取り消しました。今日の様子は変更していません。'
                    : result.rewardStatus == 'failed'
                        ? 'ケア記録は保存済みです。報酬だけ再確認できます。'
                        : result.confirmationPending
                            ? 'ケア記録は保存済みです。報酬は再確認待ちです。'
                            : result.achievementRecorded
                                ? 'ケア記録を保存しました。今日の継続達成を記録しました。'
                                : 'ケア記録を保存しました。';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _careMessage = 'ケア記録の保存に失敗しました。今日の様子の保存結果は変わりません。');
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (!_healthDirty && !_care.dirty) _isEditing = false;
    });
    if (healthSaved && (!saveCare || careSaved)) widget.onSaved?.call();
    if (careSaved && !cancelCare) widget.onCareSaved?.call();
  }

  Future<void> _applyHistoryResult(ObservationSaveResult result) async {
    ObservationLoadResult state;
    if (result.replayed) {
      // Receipt is immutable and may predate later edits. Do not present it as
      // the latest projection after a retry.
      try {
        state = await (_repo as DailyObservationStore).loadObservation(_date);
      } catch (_) {
        state = const ObservationLoadResult(serverConfirmed: false);
      }
    } else {
      state = ObservationLoadResult(
          current: result.projection == null
              ? null
              : DailyCheckin.fromJson(result.projection!,
                  fallbackDayKey: _repo.dateKeyLocal(_date)),
          revision: result.revision!,
          subjectId: result.subjectId,
          hasProfile: true);
    }
    if (!mounted) return;
    setState(() {
      _healthLoadFailed = !state.serverConfirmed;
      _observation!.load(state);
      _savedCheckin = state.current;
      _condition = state.current?.condition;
      _selectedTags
        ..clear()
        ..addAll(state.current?.concernTags ?? const []);
      _memoCtrl.text = state.current?.memo ?? '';
      _memoExpanded = _memoCtrl.text.isNotEmpty;
      _healthDirty = false;
      _isEditing = state.current == null;
      if (!state.serverConfirmed) {
        _message = '保存は受理済みですが、最新の様子を確認できません。再読み込みしてください。';
      }
    });
  }

  Future<void> _saveHistoryOnly({bool cancel = false}) async {
    if (_isSaving || _repo is! DailyObservationStore) return;
    final model = _observation!;
    final mutation = cancel
        ? model.mutation(
            condition: _condition!,
            tags: _selectedTags.toList(),
            memo: _memoCtrl.text,
            cancel: true)
        : model.state.pending;
    if (mutation == null) return;
    setState(() => _isSaving = true);
    try {
      final result =
          await (_repo as DailyObservationStore).saveObservation(mutation);
      if (!mounted) return;
      if (result.confirmed) {
        await _applyHistoryResult(result);
        if (!mounted) return;
        if (!_healthLoadFailed) {
          setState(
              () => _message = cancel ? '今日の様子を取り消しました。' : '今日の様子を保存しました。');
        }
        final current = _savedCheckin;
        if (!cancel && current != null) {
          unawaited(_recordHealthProgress(
              current.condition, current.concernTags, current.memo));
          widget.onSaved?.call();
        }
      } else {
        setState(() => _message = '今日の様子は同期待ちです。まだ保存確定ではありません。');
      }
    } catch (_) {
      if (mounted) setState(() => _message = '保存結果を確認できません。入力は残っています。');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _retryReward() async {
    final mutation = _rewardRetry;
    if (mutation == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final result = await (widget.continuitySource ?? CareContinuityRepo())
          .retryCareReward(
              dayKey: mutation.dayKey, mutationId: mutation.mutationId);
      if (mounted) {
        setState(() {
          if (result.confirmed) _rewardRetry = null;
          _careMessage = result.confirmationPending
              ? 'ケア記録は保存済みです。報酬は再確認待ちです。'
              : result.confirmed
                  ? '保存済みのケア記録の報酬を確認しました。'
                  : 'ケア記録は保存済みです。報酬の再確認は後でもできます。';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _careMessage = 'ケア記録は保存済みです。報酬の再確認は後でもできます。');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _recordHealthProgress(
      DailyCondition condition, List<String> tags, String memo) async {
    try {
      await OnboardingStateRepo().recordFirstMonitoringData('daily_checkin');
    } catch (_) {}
    try {
      await AppAnalytics.logDailyInputComplete(
          condition: condition.name,
          concernTagCount: tags.length,
          hasMemo: memo.isNotEmpty);
    } catch (_) {}
  }

  String _observationLabel(String id) =>
      observationLabel(id, catalog: widget.catalog);

  Widget _buildSavedSummary(BuildContext context) {
    final checkin = _savedCheckin;
    final color = checkin == null
        ? AppTheme.quickRecordGlow(context)
        : _conditionColor(context, checkin.condition);
    final tagText = (checkin?.concernTags ?? const <String>[])
        .map(_observationLabel)
        .where((label) => label.isNotEmpty)
        .join('・');

    return Semantics(
      liveRegion: true,
      label: checkin == null ? 'ケア記録の保存状態' : '今日の観察を保存しました',
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
                    _care.pending != null ? '同期待ち' : '記録しました',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    checkin == null
                        ? _care.draftSummary
                        : tagText.isEmpty
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
                _healthDirty = false;
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
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 340 &&
              MediaQuery.textScalerOf(context).scale(16) > 20;
          final choices = DailyCondition.values
              .map((condition) => _ConditionChoiceCard(
                  label: _conditionLabel(condition),
                  color: _conditionColor(context, condition),
                  selected: _condition == condition,
                  onTap: () => _selectCondition(condition)))
              .toList();
          if (stacked) {
            return Column(children: [
              for (final choice in choices)
                Padding(
                    padding: const EdgeInsets.only(bottom: 7), child: choice)
            ]);
          }
          return Row(children: [
            for (var index = 0; index < choices.length; index++)
              Expanded(
                  child: Padding(
                      padding: EdgeInsets.only(
                          right: index == choices.length - 1 ? 0 : 7),
                      child: choices[index]))
          ]);
        }),
        if (_observation != null && _condition != null) ...[
          const SizedBox(height: 8),
          ObservationTimingInput(
              model: _observation!,
              enabled: !_isSaving && !_healthLoadFailed,
              onChanged: () => setState(_updateHealthDirty)),
        ],
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
                                  onChanged: (_) =>
                                      setState(_updateHealthDirty),
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
        const SizedBox(height: 18),
        CareActionInputFields(
            model: _care,
            enabled: !_isSaving && !_careLoadFailed,
            onChanged: () => setState(() => _careMessage = null)),
        if (_observation != null && _savedCheckin != null)
          TextButton(
              onPressed: _isSaving || _observation!.state.pending != null
                  ? null
                  : () => _saveHistoryOnly(cancel: true),
              child: const Text('今日の様子を取り消す')),
        if (_observation?.state.pending != null)
          TextButton(
              onPressed: _isSaving ? null : () => _saveHistoryOnly(),
              child: const Text('今日の様子を再送する')),
        if (_healthLoadFailed)
          TextButton(
              onPressed: _isSaving ? null : _load,
              child: const Text('今日の様子を再読み込み')),
        if (_observation != null &&
            !_observation!.state.hasProfile &&
            !_healthLoadFailed)
          const Text('先にうちの子のプロフィールを登録してください。'),
        if (_care.confirmedSaved)
          TextButton(
              onPressed: _isSaving || _care.pending != null
                  ? null
                  : () => _save(cancelCare: true),
              child: const Text('ケア記録を取り消す')),
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
        const SizedBox(height: AppTheme.careContentGap),
        if (!_careLoadFailed && _care.pending == null)
          Text(_care.draftSummary,
              key: const ValueKey('care-confirmation-summary'),
              style: AppTheme.dataCaptionStyle(context)),
        const SizedBox(height: AppTheme.careContentGap),
        ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: 52, minWidth: double.infinity),
          child: FilledButton.icon(
            onPressed: _canSave ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSaving ? '保存中…' : 'この内容で記録'),
          ),
        ),
        Align(
            alignment: Alignment.center,
            child: TextButton(
                key: const ValueKey('health-only-save'),
                onPressed:
                    _canSaveHealthOnly ? () => _save(healthOnly: true) : null,
                child: const Text('様子だけ記録'))),
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
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  child: (_savedCheckin != null ||
                              _care.confirmedSaved ||
                              _care.pending != null) &&
                          !_isEditing
                      ? _buildSavedSummary(context)
                      : _buildEditor(context),
                ),
              if (_message != null && !_isEditing) Text(_message!),
              if (_careMessage != null) ...[
                const SizedBox(height: 8),
                Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: Text(_careMessage!,
                            key: ValueKey(_careMessage),
                            style: Theme.of(context).textTheme.bodySmall))),
              ],
              if (_rewardRetry != null)
                TextButton(
                    onPressed: _isSaving ? null : _retryReward,
                    child: const Text('報酬だけ再確認する')),
              if (_care.pending != null)
                TextButton(
                    onPressed: _isSaving ? null : () => _save(retryCare: true),
                    child: const Text('ケア記録を再送する')),
              if (_careLoadFailed)
                TextButton(
                    onPressed: _isSaving ? null : _load,
                    child: const Text('ケア記録を再読み込み')),
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
