import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/environment_history.dart';
import '../services/breeding_environment_repo.dart';
import '../viewmodels/environment_history_view_model.dart';
import '../theme/app_theme.dart';
import '../widgets/status_card.dart';

class EnvironmentHistoryScreen extends StatefulWidget {
  const EnvironmentHistoryScreen(
      {super.key,
      required this.store,
      this.selectCorrection = false,
      this.onMutationAttempted});
  final EnvironmentStore store;
  final bool selectCorrection;
  final VoidCallback? onMutationAttempted;
  @override
  State<EnvironmentHistoryScreen> createState() =>
      _EnvironmentHistoryScreenState();
}

class _EnvironmentHistoryScreenState extends State<EnvironmentHistoryScreen> {
  final _entries = <EnvironmentHistoryEntry>[];
  bool _loading = true, _more = false, _saving = false;
  int? _cursor;
  String? _error;
  EnvironmentMutation? _pending;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await widget.store.history(beforeRevision: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _entries.clear();
        _entries.addAll(page.entries);
        _more = page.hasMore;
        _cursor = page.beforeRevision;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '履歴を読み込めませんでした');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(EnvironmentHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('この変更を取り消しますか？'),
                content: const Text('履歴を残して取り消します。後の変更は維持されます。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('戻る')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('取り消す'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    EnvironmentMutation? mutation;
    try {
      final current = await widget.store.load();
      if (!current.serverConfirmed || current.pending != null) {
        throw StateError('unconfirmed');
      }
      mutation = EnvironmentMutation(
          mutationId: const Uuid().v4(),
          expectedRevision: current.revision,
          operation: EnvironmentOperation.cancel,
          targetRevision: entry.targetRevision ?? entry.revision);
      widget.onMutationAttempted?.call();
      await _send(mutation);
    } catch (error) {
      if (mounted) {
        setState(() {
          final definitive = error is FirebaseFunctionsException &&
              const {
                'invalid-argument',
                'failed-precondition',
                'aborted',
                'unauthenticated',
                'permission-denied',
                'not-found',
                'already-exists'
              }.contains(error.code);
          if (mutation != null && !definitive) _pending = mutation;
          _error = '取消を確認できませんでした。設定画面から再確認してください。';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _send(EnvironmentMutation mutation) async {
    final result = await widget.store.save(mutation);
    if (!mounted) return;
    if (!result.confirmed) {
      setState(() {
        _pending = mutation;
        _error = '保存確認待ちです';
      });
      return;
    }
    setState(() => _pending = null);
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.selectCorrection ? '訂正する変更を選択' : '飼育環境の変更履歴')),
      body: DecoratedBox(
          decoration: AppTheme.dataPageDecoration(context),
          child: SafeArea(
              top: false,
              child: ListView(padding: AppTheme.dataPagePadding, children: [
                if (_error != null) Text(_error!),
                if (_pending != null)
                  FilledButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              try {
                                await _send(_pending!);
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _error = '保存確認待ちです');
                                }
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            },
                      child: const Text('同じ内容を再送')),
                if (_entries.isEmpty && !_loading)
                  const Text('保存すると、ここに変更履歴が残ります。'),
                for (final entry in _entries) ...[
                  _entryCard(entry),
                  const SizedBox(height: AppTheme.dataSectionGap),
                ],
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (!_loading && _more)
                  TextButton(
                      key: const ValueKey('environment-history-more'),
                      onPressed: () => _load(),
                      child: const Text('さらに表示')),
                if (!_loading && _error != null && _pending == null)
                  TextButton(
                      onPressed: () => _load(reset: true),
                      child: const Text('再読み込み')),
              ]))));
  Widget _entryCard(EnvironmentHistoryEntry entry) {
    final view = EnvironmentHistoryViewModel(entry);
    final cancelled = _entries.any((item) =>
        item.kind == 'cancel' &&
        item.targetRevision == (entry.targetRevision ?? entry.revision));
    final target = entry.targetRevision ?? entry.revision;
    final latest = _entries
        .where((item) =>
            (item.kind == 'change' && item.revision == target) ||
            (item.kind == 'correction' && item.targetRevision == target))
        .fold<int>(
            0,
            (revision, item) =>
                item.revision > revision ? item.revision : revision);
    final correctable =
        (entry.kind == 'change' || entry.kind == 'correction') &&
            !cancelled &&
            entry.revision == latest &&
            entry.recordedFieldKeys.any((key) => key != 'cageFloorArea');
    return StatusCard(
        level: StatusCardLevel.neutral,
        dataSurface: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(view.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTheme.dataContentGap),
          if (view.beforeCaption != null)
            Text(view.beforeCaption!,
                style: Theme.of(context).textTheme.bodySmall),
          if (view.changeLines.isEmpty && entry.auxiliaryFieldsChanged.isEmpty)
            Text(entry.kind == 'initial_snapshot'
                ? 'この時点の設定を保存しました'
                : entry.kind == 'cancel'
                    ? '以前の入力を取り消しました'
                    : entry.kind == 'correction'
                        ? '変更日の入力を訂正しました'
                        : '環境の変更を記録しました'),
          for (final line in view.changeLines)
            Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.dataValueGap),
                child: Text(line)),
          if (entry.auxiliaryFieldsChanged.isNotEmpty) const Text('グッズのメモを更新'),
          if (correctable)
            Wrap(spacing: AppTheme.dataSmallGap, children: [
              TextButton(
                  key: ValueKey('environment-correct-${entry.revision}'),
                  onPressed: _saving || _pending != null
                      ? null
                      : () => Navigator.pop(context, entry),
                  child: const Text('入力を訂正')),
              if (!widget.selectCorrection)
                TextButton(
                    onPressed: _saving || _pending != null
                        ? null
                        : () => _cancel(entry),
                    child: const Text('変更を取り消す')),
            ]),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('詳細'),
              children: [
                if (entry.kind == 'initial_snapshot')
                  for (final line in view.snapshotLines)
                    Align(alignment: Alignment.centerLeft, child: Text(line)),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        '履歴 revision ${entry.revision}${entry.targetRevision == null ? '' : ' · 対象 ${entry.targetRevision}'}')),
                if (view.acceptedLabel != null)
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text('保存確認 ${view.acceptedLabel}')),
              ]),
        ]));
  }
}
