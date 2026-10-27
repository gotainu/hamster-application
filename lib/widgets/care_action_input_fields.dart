import 'package:flutter/material.dart';
import '../models/care_action_catalog.dart';
import '../models/daily_care_actions.dart';
import '../theme/app_theme.dart';
import '../viewmodels/care_action_input_view_model.dart';

/// Catalog-driven care inputs. Selection only updates the local draft.
class CareActionInputFields extends StatelessWidget {
  const CareActionInputFields(
      {super.key,
      required this.model,
      required this.onChanged,
      this.enabled = true});
  final CareActionInputViewModel model;
  final VoidCallback onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final interactive = enabled && model.pending == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('今日やったこと',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      for (final item in activeCareActionItems(catalog: model.catalog)) ...[
        const SizedBox(height: AppTheme.careContentGap),
        Row(children: [
          Expanded(
              child: Text(item.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
          if (!model.isUnconfirmed(item.id) &&
              model.actions[item.id]?.answer != CareActionAnswer.unanswered)
            TextButton(
                key: ValueKey('care-clear-${item.id}'),
                onPressed: interactive
                    ? () {
                        model.select(item.id, CareActionAnswer.unanswered);
                        onChanged();
                      }
                    : null,
                child: const Text('解除')),
        ]),
        if (item.inputType == 'cleaning_choice')
          _CleaningChoices(
              item: item,
              model: model,
              enabled: interactive,
              onChanged: onChanged)
        else if (item.inputType == 'duration_minutes')
          CareDurationSlider(
              item: item,
              model: model,
              enabled: interactive,
              onChanged: onChanged)
        else
          _LegacyChoices(
              item: item,
              model: model,
              enabled: interactive,
              onChanged: onChanged),
      ],
      if (model.detailError != null)
        Text(model.detailError!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error)),
    ]);
  }
}

class _CleaningChoices extends StatelessWidget {
  const _CleaningChoices(
      {required this.item,
      required this.model,
      required this.enabled,
      required this.onChanged});
  final CareActionCatalogItem item;
  final CareActionInputViewModel model;
  final bool enabled;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final primary = model.definition(item.id, 'cleaning_type');
    final bedding = model.definition(item.id, 'bedding_replacement');
    final choice = model.cleaningChoice(item.id);
    final action = model.actions[item.id]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CareCompactChoiceSelector(
          choices: [
            const CareActionDetailOption(id: 'none', label: 'なし'),
            ...?primary?.values
          ],
          selected: choice,
          keyPrefix: 'care-${item.id}',
          enabled: enabled,
          onSelected: (value) {
            model.selectCleaning(item.id, value);
            onChanged();
          }),
      if (choice == null)
        Text(
            action.answer == CareActionAnswer.performed
                ? '以前の記録：掃除済み（詳しい区分は不明）'
                : '未回答',
            style: AppTheme.dataCaptionStyle(context)),
      if (bedding != null && bedding.isApplicable(action.details)) ...[
        const SizedBox(height: AppTheme.careContentGap),
        Row(children: [
          Expanded(
              child: Text('${bedding.label}（任意）',
                  style: Theme.of(context).textTheme.bodySmall)),
          if (action.details.containsKey(bedding.key))
            TextButton(
                onPressed: enabled
                    ? () {
                        model.detail(item.id, null, key: bedding.key);
                        onChanged();
                      }
                    : null,
                child: const Text('解除')),
        ]),
        CareCompactChoiceSelector(
            choices: bedding.values,
            selected: action.details[bedding.key] as String?,
            keyPrefix: 'care-${item.id}-${bedding.key}',
            enabled: enabled,
            onSelected: (value) {
              model.detail(item.id, value, key: bedding.key);
              onChanged();
            }),
      ],
    ]);
  }
}

/// Small categorical selections shared by cleaning and optional bedding.
class CareCompactChoiceSelector extends StatelessWidget {
  const CareCompactChoiceSelector(
      {super.key,
      required this.choices,
      required this.selected,
      required this.keyPrefix,
      required this.onSelected,
      this.enabled = true});
  final List<CareActionDetailOption> choices;
  final String? selected;
  final String keyPrefix;
  final ValueChanged<String> onSelected;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: AppTheme.careChoiceGap,
          runSpacing: AppTheme.careChoiceGap,
          children: [
            for (final option in choices)
              ChoiceChip(
                  key: ValueKey('$keyPrefix-${option.id}'),
                  label: Text(option.label),
                  labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected == option.id
                          ? AppTheme.careChoiceSelectedForeground(context)
                          : AppTheme.careChoiceUnselectedForeground(context)),
                  selectedColor: AppTheme.careChoiceSelectedSurface(context),
                  backgroundColor: AppTheme.quickRecordChoiceSurface(context),
                  labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.dataSmallGap),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  selected: selected == option.id,
                  onSelected: enabled ? (_) => onSelected(option.id) : null),
          ]);
}

/// Daily total. The slider is a short range; direct input preserves larger totals.
class CareDurationSlider extends StatelessWidget {
  const CareDurationSlider(
      {super.key,
      required this.item,
      required this.model,
      required this.enabled,
      required this.onChanged});
  final CareActionCatalogItem item;
  final CareActionInputViewModel model;
  final bool enabled;
  final VoidCallback onChanged;
  Future<void> _input(BuildContext context) async {
    final controller =
        TextEditingController(text: model.minutes(item.id)?.toString() ?? '');
    final max = model.definition(item.id, 'daily_total')?.max?.toInt();
    var error = false;
    final result = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('散歩時間（1日合計）'),
                  content: TextField(
                      key: ValueKey('care-detail-${item.id}'),
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          suffixText: '分',
                          helperText: '0〜$max分',
                          errorText: error ? '範囲内の整数を入力してください' : null)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('戻る')),
                    TextButton(
                        onPressed: () {
                          final value = int.tryParse(controller.text.trim());
                          if (value == null ||
                              value < 0 ||
                              (max != null && value > max)) {
                            setDialogState(() => error = true);
                            return;
                          }
                          Navigator.pop(context, value);
                        },
                        child: const Text('入力する'))
                  ],
                )));
    // A dialog can still be completing its reverse animation when it returns.
    if (result != null && context.mounted) {
      model.selectMinutes(item.id, result);
      onChanged();
    }
    // The TextField owns a listener until the dialog route is disposed.
    Future<void>.delayed(kThemeAnimationDuration, controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = model.minutes(item.id);
    final max = CareActionInputViewModel.sliderMaxMinutes;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton(
          key: ValueKey('care-duration-value-${item.id}'),
          onPressed: enabled ? () => _input(context) : null,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          child: minutes != null
              ? Text.rich(TextSpan(
                  text: '$minutes',
                  style: AppTheme.careDurationValueStyle(context),
                  children: [
                      TextSpan(
                          text: ' 分', style: AppTheme.dataBodyStyle(context))
                    ]))
              : Text(
                  minutes == null
                      ? (model.actions[item.id]?.answer ==
                              CareActionAnswer.unanswered
                          ? '未回答'
                          : '時間不明')
                      : '$minutes 分',
                  style: AppTheme.careDurationValueStyle(context))),
      SliderTheme(
          data: AppTheme.careInputSliderTheme(context),
          child: Slider(
              key: ValueKey('care-duration-slider-${item.id}'),
              min: 0,
              max: max.toDouble(),
              divisions: max,
              value: (minutes ?? 0).clamp(0, max).toDouble(),
              label: minutes == null ? '時間未入力' : '$minutes分',
              semanticFormatterCallback: (value) => '${value.round()}分',
              onChanged: enabled
                  ? (value) {
                      model.selectMinutes(item.id, value.round());
                      onChanged();
                    }
                  : null)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('0分', style: AppTheme.dataCaptionStyle(context)),
        Text('$max分', style: AppTheme.dataCaptionStyle(context))
      ]),
      TextButton(
          key: ValueKey('care-duration-unknown-${item.id}'),
          onPressed: enabled
              ? () {
                  model.selectMinutes(item.id, null);
                  onChanged();
                }
              : null,
          child: const Text('散歩した（時間不明）')),
      if (minutes != null && minutes > max)
        Text('スライダーの範囲を超える時間も、そのまま記録します。',
            style: AppTheme.dataCaptionStyle(context)),
    ]);
  }
}

class _LegacyChoices extends StatelessWidget {
  const _LegacyChoices(
      {required this.item,
      required this.model,
      required this.enabled,
      required this.onChanged});
  final CareActionCatalogItem item;
  final CareActionInputViewModel model;
  final bool enabled;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppTheme.careChoiceGap, children: [
        for (final answer in CareActionAnswer.values)
          ChoiceChip(
              key: ValueKey('care-${item.id}-${answer.wire}'),
              label: Text(answer.label),
              selected: model.actions[item.id]?.answer == answer,
              onSelected: enabled
                  ? (_) {
                      model.select(item.id, answer);
                      onChanged();
                    }
                  : null),
      ]);
}
