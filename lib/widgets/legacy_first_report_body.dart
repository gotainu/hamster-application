import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_analytics.dart';
import '../services/legacy_first_reports_repo.dart';
import '../models/legacy_first_report.dart';
import '../viewmodels/legacy_first_report_view_model.dart';
import '../theme/app_theme.dart';
import 'report_continuation_link.dart';

class LegacyFirstReportBody extends StatefulWidget {
  const LegacyFirstReportBody(
      {super.key,
      this.autoPresented = false,
      this.onReportViewed,
      this.source,
      this.logView,
      this.expectedOwnerUid,
      this.missingBuilder});
  final bool autoPresented;
  final String? expectedOwnerUid;
  final FutureOr<void> Function()? onReportViewed;
  final LegacyFirstReportSource? source;
  final Future<void> Function(String ownerUid, int revision)? logView;
  final WidgetBuilder? missingBuilder;
  @override
  State<LegacyFirstReportBody> createState() => _LegacyFirstReportBodyState();
}

class _LegacyFirstReportBodyState extends State<LegacyFirstReportBody> {
  late LegacyFirstReportSource _source;
  late Stream<LegacyFirstReportState> _stream;
  LegacyFirstReportState? _current;
  String? _loggedPresentationKey;
  final _scheduled = <String>{};
  int _readVersion = 0;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _source = widget.source ?? LegacyFirstReportsRepo();
    _stream = _source.watchFirstReport();
  }

  @override
  void didUpdateWidget(covariant LegacyFirstReportBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.expectedOwnerUid != widget.expectedOwnerUid) {
      _readVersion++;
      _current = null;
      _bind();
    }
  }

  void _retry() => setState(() {
        _readVersion++;
        _current = null;
        _stream = _source.watchFirstReport();
      });
  void _logDisplayed(
      LegacyFirstReportState state, LegacyFirstReportSnapshot frozen) {
    final owner = state.ownerUid;
    final report = state.report!;
    final revision = frozen.analysisRevision;
    final generation = report['generation'] as Map;
    final key = '$owner:main_pet:first:$revision:${generation['generatedAt']}';
    final readVersion = _readVersion;
    final route = ModalRoute.of(context);
    if (owner == null ||
        _loggedPresentationKey == key ||
        _scheduled.contains(key)) {
      return;
    }
    _scheduled.add(key);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool current() {
        final displayed = _current?.report;
        final displayedGeneration = displayed?['generation'];
        return mounted &&
            _readVersion == readVersion &&
            _current?.phase == LegacyFirstReportPhase.available &&
            _current?.ownerUid == owner &&
            displayed?['analysisRevision'] == report['analysisRevision'] &&
            displayedGeneration is Map &&
            displayedGeneration['generatedAt'] == generation['generatedAt'] &&
            _source.currentUid == owner &&
            (widget.expectedOwnerUid == null ||
                widget.expectedOwnerUid == owner) &&
            route?.isCurrent != false;
      }

      try {
        if (!current()) return;
        try {
          await widget.onReportViewed?.call();
        } catch (_) {}
        if (!current()) return;
        _loggedPresentationKey = key;
        if (widget.logView != null) {
          await widget.logView!(owner, revision);
        } else {
          await AppAnalytics.logAnalysisReportViewed(
              reportId: 'first',
              petId: 'main_pet',
              revision: revision,
              presentationId: '${DateTime.now().microsecondsSinceEpoch}',
              autoPresented: widget.autoPresented,
              expectedUserId: owner);
        }
      } finally {
        _scheduled.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LegacyFirstReportState>(
      key: ValueKey(_readVersion),
      stream: _stream,
      builder: (context, snapshot) {
        final incoming = snapshot.hasError
            ? const LegacyFirstReportState.unavailable(null)
            : snapshot.data ?? const LegacyFirstReportState.loading(null);
        final initialLoading =
            incoming.phase == LegacyFirstReportPhase.loading &&
                incoming.ownerUid == null;
        final state = widget.expectedOwnerUid == null ||
                incoming.ownerUid == widget.expectedOwnerUid ||
                initialLoading
            ? incoming
            : LegacyFirstReportState.unavailable(widget.expectedOwnerUid);
        _current = state;
        if (state.phase == LegacyFirstReportPhase.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.phase == LegacyFirstReportPhase.missing) {
          if (widget.missingBuilder != null) {
            return widget.missingBuilder!(context);
          }
          return const Center(child: Text('初回レポートはまだありません'));
        }
        if (state.phase == LegacyFirstReportPhase.unavailable ||
            state.ownerUid != _source.currentUid) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('レポートを取得できませんでした。'),
            TextButton(onPressed: _retry, child: const Text('再試行'))
          ]));
        }
        final report = state.report!;
        final generation = report['generation'];
        if (generation is! Map || generation['status'] != 'generated') {
          return const Center(child: Text('初回レポートを準備しています。'));
        }
        final frozen = LegacyFirstReportSnapshot.fromMap(report);
        final vm = LegacyFirstReportViewModel(frozen);
        _logDisplayed(state, frozen);
        return DecoratedBox(
          decoration: AppTheme.dataPageDecoration(context),
          child: ListView(padding: AppTheme.dataPagePadding, children: [
            Text('初回分析の記録', style: Theme.of(context).textTheme.titleLarge),
            if (vm.generatedAtLabel != null) ...[
              const SizedBox(height: 8),
              Text('作成 ${vm.generatedAtLabel}',
                  style: AppTheme.dataCaptionStyle(context)),
            ],
            const SizedBox(height: 16),
            for (final metric in frozen.metrics)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('この時点で個体別分析の準備が整いました。'),
                      if (metric.validRecordCount != null)
                        Text('有効記録 ${metric.validRecordCount}件',
                            style: AppTheme.dataCaptionStyle(context)),
                      if (metric.startDateKey != null &&
                          metric.endDateKey != null)
                        Text('${metric.startDateKey}〜${metric.endDateKey}',
                            style: AppTheme.dataCaptionStyle(context)),
                    ]),
              ),
            const Text('生成時点の記録を保存したレポートです。'),
            const SizedBox(height: 8),
            Text('この初回レポートには体重や活動量の数値は保存されていません。',
                style: AppTheme.dataCaptionStyle(context)),
            const SizedBox(height: AppTheme.dataContentGap),
            const ReportContinuationLink(),
          ]),
        );
      });
}
