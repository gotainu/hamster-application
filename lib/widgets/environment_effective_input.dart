import 'package:flutter/material.dart';
import '../models/environment_history.dart';
import '../viewmodels/environment_history_view_model.dart';
import '../theme/app_theme.dart';

/// A date on first render is a suggestion. Only an explicit selection confirms it.
class EnvironmentEffectiveInput extends StatelessWidget {
  const EnvironmentEffectiveInput(
      {super.key,
      required this.draft,
      required this.onChanged,
      required this.today});
  final EnvironmentEffectiveDraft draft;
  final VoidCallback onChanged;
  final DateTime today;
  Future<void> _chooseDay(BuildContext context) async {
    final selected = await showDatePicker(
        context: context,
        initialDate:
            draft.displayDate.isAfter(today) ? today : draft.displayDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(today.year, today.month, today.day));
    if (selected != null) {
      draft.confirmDate(selected);
      onChanged();
    }
  }

  Future<void> _chooseTime(BuildContext context) async {
    final selected = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
    if (selected == null) return;
    final day = draft.displayDate;
    final time =
        DateTime(day.year, day.month, day.day, selected.hour, selected.minute);
    if (time.isAfter(today)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('未来の時刻は指定できません')));
      }
      return;
    }
    draft.confirmInstant(time);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        '${draft.displayDate.year}/${draft.displayDate.month.toString().padLeft(2, '0')}/${draft.displayDate.day.toString().padLeft(2, '0')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('変更時期', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppTheme.dataContentGap),
      Wrap(
          spacing: AppTheme.dataSmallGap,
          runSpacing: AppTheme.dataSmallGap,
          children: [
            ChoiceChip(
                key: const ValueKey('environment-date-confirm'),
                label: Text(
                    '$label${draft.confirmed && !draft.unknown ? '' : 'を確認'}'),
                selected: draft.confirmed && !draft.unknown,
                onSelected: (_) {
                  draft.confirmDate(draft.displayDate);
                  onChanged();
                }),
            TextButton(
                key: const ValueKey('environment-date-picker'),
                onPressed: () => _chooseDay(context),
                child: const Text('日付を変更')),
            ChoiceChip(
                key: const ValueKey('environment-date-unknown'),
                label: const Text('不明'),
                selected: draft.unknown,
                onSelected: (_) {
                  draft.confirmUnknown();
                  onChanged();
                }),
          ]),
      if (draft.confirmed && !draft.unknown)
        TextButton(
            key: const ValueKey('environment-time-picker'),
            onPressed: () => _chooseTime(context),
            child: Text(draft.toEffective().precision ==
                    EnvironmentPrecision.instant
                ? '変更時刻 ${TimeOfDay.fromDateTime(draft.toEffective().occurredAt!.toLocal()).format(context)}'
                : '時刻も指定する（任意）')),
      if (!draft.confirmed)
        Text('日付か「不明」を選んでください',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.secondaryText(context))),
    ]);
  }
}
