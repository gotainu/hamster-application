import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/personality_report.dart';
import '../services/personality_report_view_service.dart';
import '../services/personality_reports_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/status_card.dart';
import 'personality_report_screen.dart';
import 'personalized_report_screen.dart';

/// Owner-read-only immutable snapshots. Only actual detail drawing marks a view.
class PersonalityReportHistoryScreen extends StatefulWidget {
  const PersonalityReportHistoryScreen(
      {super.key, this.repo, this.viewService});
  final PersonalityReportsHistorySource? repo;
  final PersonalityReportViewService? viewService;
  @override
  State<PersonalityReportHistoryScreen> createState() =>
      _PersonalityReportHistoryScreenState();
}

class _PersonalityReportHistoryScreenState
    extends State<PersonalityReportHistoryScreen> {
  late PersonalityReportsHistorySource _repo;
  late PersonalityReportViewService _views;
  StreamSubscription<String?>? _ownerSubscription;
  String? _owner;
  bool _bound = false;
  int _version = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  List<PersonalityHistoryEntry> _entries = [];
  PersonalityHistoryCursor? _cursor;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _repo = widget.repo ?? PersonalityReportsRepo();
    _views = widget.viewService ?? PersonalityReportViewService.production();
    _ownerSubscription = _repo.watchOwnerUid().listen(_bindOwner,
        onError: (Object error, StackTrace stack) {
      if (!mounted) return;
      setState(() {
        _version++;
        _owner = null;
        _entries = [];
        _cursor = null;
        _loading = false;
        _loadingMore = false;
        _error = true;
      });
    });
  }

  void _bindOwner(String? uid) {
    if (!mounted || (_bound && uid == _owner)) return;
    setState(() {
      _bound = true;
      _owner = uid;
      _version++;
      _entries = [];
      _cursor = null;
      _loading = uid != null;
      _loadingMore = false;
      _error = uid == null;
    });
    if (uid != null) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PersonalityReportHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repo != widget.repo ||
        oldWidget.viewService != widget.viewService) {
      _version++;
      _bound = false;
      _owner = null;
      _entries = [];
      _cursor = null;
      _loading = true;
      _error = false;
      unawaited(_ownerSubscription?.cancel());
      _bind();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (!mounted ||
        _owner == null ||
        (more && (_loadingMore || _cursor == null))) {
      return;
    }
    final owner = _owner!;
    final version = ++_version;
    final after = more ? _cursor : null;
    setState(() {
      _error = false;
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _entries = [];
        _cursor = null;
      }
    });
    try {
      final page = await _repo.fetchHistory(after: after);
      if (!mounted ||
          version != _version ||
          owner != _owner ||
          page.ownerUid != owner) {
        return;
      }
      setState(() {
        _entries = more ? [..._entries, ...page.entries] : page.entries;
        _cursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || version != _version || owner != _owner) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = true;
      });
    }
  }

  Future<void> _open(PersonalityReport selected) async {
    final owner = _owner;
    if (owner == null) return;
    final presentation =
        'personality_history_${DateTime.now().microsecondsSinceEpoch}';
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PersonalityReportScreen(
            repo: _repo,
            reportId: selected.reportId,
            expectedOwnerUid: owner,
            onReportViewed: (report) async {
              if (_owner != owner) return;
              final marked = await _views.recordView(
                  ownerUid: owner,
                  reportId: report.reportId,
                  petId: report.petId,
                  schemaVersion: report.schemaVersion,
                  presentationId: presentation);
              if (marked && mounted && _owner == owner) {
                setState(() {
                  _entries = _entries
                      .map((entry) => entry.report.reportId == report.reportId
                          ? PersonalityHistoryEntry(entry.report,
                              isViewed: true)
                          : entry)
                      .toList();
                });
              }
            })));
  }

  Future<void> _openFirst() async {
    final owner = _owner;
    if (owner == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PersonalizedReportScreen(
            expectedOwnerUid: owner,
            onReportViewed: () => _views.recordLegacyView(ownerUid: owner))));
  }

  @override
  void dispose() {
    _version++;
    unawaited(_ownerSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('レポート履歴')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('作成時点の記録を、そのまま振り返れます。',
            style: TextStyle(color: AppTheme.secondaryText(context))),
        const SizedBox(height: 14),
        if (_owner != null)
          StatusCard(
              level: StatusCardLevel.neutral,
              radius: 24,
              padding: const EdgeInsets.all(16),
              onTap: _openFirst,
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insights_rounded),
                  title: const Text('初回コンディションレポート'),
                  subtitle: const Text('最初に準備できた指標のスナップショット'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openFirst)),
        const SizedBox(height: 14),
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator()))
        else if (_entries.isEmpty && !_error)
          const Padding(
              padding: EdgeInsets.all(20), child: Text('個性レポートはまだ届いていません。')),
        for (final entry in _entries)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryTile(
                  entry: entry, onOpen: () => _open(entry.report))),
        if (_error)
          Column(children: [
            const Text('レポート履歴を取得できませんでした。'),
            TextButton(
                onPressed: () =>
                    _load(more: _entries.isNotEmpty && _cursor != null),
                child: const Text('再試行'))
          ]),
        if (_loadingMore)
          const Center(child: CircularProgressIndicator())
        else if (_cursor != null && !_error)
          TextButton.icon(
              onPressed: () => _load(more: true),
              icon: const Icon(Icons.expand_more),
              label: const Text('さらに読み込む')),
      ]));
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onOpen});
  final PersonalityHistoryEntry entry;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final report = entry.report;
    final date = DateFormat('yyyy年M月d日')
        .format(report.generatedAt.toUtc().add(const Duration(hours: 9)));
    final metric = report.type == PersonalityReportType.both
        ? '体重・活動量'
        : report.body != null
            ? '体重'
            : '活動量';
    final values = [
      if (report.body != null) '体重 ${report.body!.median.round()}g',
      if (report.activity != null) '活動量 ${report.activity!.median.round()}m/日'
    ].join(' / ');
    return StatusCard(
        level: StatusCardLevel.neutral,
        radius: 24,
        padding: const EdgeInsets.all(16),
        onTap: onOpen,
        child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: onOpen,
            title: Text(report.isDaily ? '日次の個性レポート' : '個性レポート'),
            subtitle: Text('$date\n対象: $metric\n$values'),
            isThreeLine: true,
            trailing: Text(entry.isViewed ? '閲覧済み' : '未読',
                style: TextStyle(
                    color: entry.isViewed
                        ? AppTheme.secondaryText(context)
                        : AppTheme.accent))));
  }
}
