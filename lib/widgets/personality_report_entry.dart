import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/personality_report.dart';
import '../services/personality_reports_repo.dart';
import '../theme/app_theme.dart';
import 'status_card.dart';

/// Only the latest server-confirmed unread report appears on Home.
class PersonalityReportEntry extends StatefulWidget {
  final void Function(PersonalityReport report) onOpen;
  final PersonalityUnreadReportsSource? source;
  const PersonalityReportEntry({super.key, required this.onOpen, this.source});
  @override
  State<PersonalityReportEntry> createState() => _PersonalityReportEntryState();
}

class _PersonalityReportEntryState extends State<PersonalityReportEntry> {
  late Stream<PersonalityReportState> _stream;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() =>
      _stream = (widget.source ?? PersonalityReportsRepo()).watchUnreadLatest();
  @override
  void didUpdateWidget(covariant PersonalityReportEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _version++;
      _bind();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PersonalityReportState>(
      key: ValueKey(_version),
      stream: _stream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final report = state?.report;
        if (snapshot.hasError ||
            state?.phase != PersonalityReportPhase.available ||
            report == null) {
          return const SizedBox.shrink();
        }
        final date = DateFormat('yyyy年M月d日')
            .format(report.generatedAt.toUtc().add(const Duration(hours: 9)));
        return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: StatusCard(
                level: StatusCardLevel.neutral,
                radius: 24,
                padding: const EdgeInsets.all(18),
                onTap: () => widget.onOpen(report),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.pets_rounded, color: AppTheme.accent),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('新しい個性レポートが届きました',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900)))
                      ]),
                      const SizedBox(height: 8),
                      Text('$date 作成',
                          style: TextStyle(
                              color: AppTheme.secondaryText(context))),
                      TextButton.icon(
                          onPressed: () => widget.onOpen(report),
                          icon: const Icon(Icons.auto_stories_outlined),
                          label: const Text('個性レポートを見る')),
                    ])));
      });
}
