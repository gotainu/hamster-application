import 'package:flutter/material.dart';

/// A compact entry to the record calendar; it does not load reward state.
class RecordCalendarAction extends StatelessWidget {
  const RecordCalendarAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: '記録カレンダー',
        constraints: const BoxConstraints(
          minWidth: kMinInteractiveDimension,
          minHeight: kMinInteractiveDimension,
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_today_outlined),
      );
}
