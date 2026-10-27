import 'package:flutter/material.dart';
import '../models/daily_observation_history.dart';
import '../viewmodels/observation_input_view_model.dart';

/// Small explicit choices; merely opening the form confirms no timing.
class ObservationTimingInput extends StatelessWidget {
  const ObservationTimingInput(
      {super.key,
      required this.model,
      required this.onChanged,
      this.enabled = true,
      this.now});
  final ObservationInputViewModel model;
  final VoidCallback onChanged;
  final bool enabled;
  final DateTime Function()? now;
  @override
  Widget build(BuildContext context) {
    final timing = model.timing;
    final clock = now ?? DateTime.now;
    final today = clock().toLocal();
    final isToday = model.date.year == today.year &&
        model.date.month == today.month &&
        model.date.day == today.day;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (model.hasExisting)
        Wrap(spacing: 8, children: [
          _choice(context,
              label: const Text('入力の訂正'),
              key: const ValueKey('observation-intent-correction'),
              selected: model.operation == ObservationOperation.correction,
              onSelected: enabled
                  ? (_) {
                      model.chooseOperation(ObservationOperation.correction);
                      onChanged();
                    }
                  : null),
          _choice(context,
              label: const Text('新しい観察'),
              key: const ValueKey('observation-intent-new'),
              selected: model.operation == ObservationOperation.newObservation,
              onSelected: enabled
                  ? (_) {
                      model
                          .chooseOperation(ObservationOperation.newObservation);
                      onChanged();
                    }
                  : null),
        ]),
      Text('観察したタイミング', style: Theme.of(context).textTheme.bodySmall),
      Wrap(spacing: 8, runSpacing: 4, children: [
        if (isToday)
          _choice(context,
              label: const Text('いまの様子'),
              key: const ValueKey('observation-time-now'),
              selected: timing?.confirmation == 'now_confirmed',
              onSelected: enabled
                  ? (_) {
                      model.confirmNow(clock());
                      onChanged();
                    }
                  : null),
        Semantics(
            label: model.dateAccessibilityLabel,
            child: _choice(context,
                label: Text(model.confirmedDateLabel),
                key: const ValueKey('observation-time-date'),
                selected:
                    timing?.precision == ObservationTimePrecision.dateOnly,
                onSelected: enabled
                    ? (_) {
                        model.confirmDate();
                        onChanged();
                      }
                    : null)),
        _choice(context,
            label: const Text('時期不明'),
            key: const ValueKey('observation-time-unknown'),
            selected: timing?.precision == ObservationTimePrecision.unknown,
            onSelected: enabled
                ? (_) {
                    model.confirmUnknown();
                    onChanged();
                  }
                : null),
        ActionChip(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            labelStyle: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            label: Text(timing?.confirmation == 'time_confirmed'
                ? '${timing!.observedAt!.toLocal().hour.toString().padLeft(2, '0')}:${timing.observedAt!.toLocal().minute.toString().padLeft(2, '0')}'
                : '時刻を指定'),
            key: const ValueKey('observation-time-select'),
            onPressed: enabled
                ? () async {
                    final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(clock()));
                    if (picked == null) return;
                    model.confirmTime(DateTime(
                        model.date.year,
                        model.date.month,
                        model.date.day,
                        picked.hour,
                        picked.minute));
                    onChanged();
                  }
                : null),
      ]),
    ]);
  }

  ChoiceChip _choice(BuildContext context,
      {required Widget label,
      required Key key,
      required bool selected,
      required ValueChanged<bool>? onSelected}) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    return ChoiceChip(
        key: key,
        label: label,
        selected: selected,
        onSelected: onSelected,
        selectedColor: colors.primaryContainer,
        backgroundColor: colors.surfaceContainerHighest,
        disabledColor: colors.surfaceContainer,
        checkmarkColor:
            enabled ? foreground : colors.onSurface.withValues(alpha: 0.38),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: enabled
                ? foreground
                : colors.onSurface.withValues(alpha: 0.38)));
  }
}
