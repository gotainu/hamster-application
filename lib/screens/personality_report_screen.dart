import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/personality_report.dart';
import '../services/personality_reports_repo.dart';
import '../theme/app_theme.dart';
import '../viewmodels/personality_report_view_model.dart';
import '../widgets/metric_pair_comparison_bars.dart';
import '../widgets/metric_value_comparison.dart';
import '../widgets/status_card.dart';
import '../widgets/metric_comparison_bar.dart';

/// A free read-only presentation of an immutable generated snapshot.
class PersonalityReportScreen extends StatefulWidget {
  const PersonalityReportScreen(
      {super.key,
      this.repo,
      this.reportId,
      this.expectedOwnerUid,
      this.onReportViewed});
  final PersonalityReportsSource? repo;
  final String? reportId;

  /// When supplied, this route never displays another account's same-ID report.
  final String? expectedOwnerUid;
  final FutureOr<void> Function(PersonalityReport report)? onReportViewed;
  @override
  State<PersonalityReportScreen> createState() =>
      _PersonalityReportScreenState();
}

class _PersonalityReportScreenState extends State<PersonalityReportScreen> {
  late PersonalityReportsSource _repo;
  late Stream<PersonalityReportState> _stream;
  int _readVersion = 0;
  PersonalityReportState? _currentState;
  final _viewed = <String>{};
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _repo = widget.repo ?? PersonalityReportsRepo();
    _stream = _readStream();
  }

  Stream<PersonalityReportState> _readStream() {
    final id = widget.reportId;
    if (id == null) return _repo.watchLatest();
    final source = _repo;
    return source is PersonalitySpecificReportSource
        ? source.watchReport(id)
        : Stream.value(const PersonalityReportState.unavailable(null));
  }

  @override
  void didUpdateWidget(covariant PersonalityReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repo != widget.repo ||
        oldWidget.reportId != widget.reportId ||
        oldWidget.expectedOwnerUid != widget.expectedOwnerUid) {
      _readVersion++;
      _currentState = null;
      _bind();
    }
  }

  void _retry() => setState(() {
        _readVersion++;
        _currentState = null;
        _stream = _readStream();
      });
  bool _isExpectedOwner(PersonalityReportState state) =>
      widget.expectedOwnerUid == null ||
      state.ownerUid == widget.expectedOwnerUid;

  void _reportRendered(PersonalityReportState state) {
    final report = state.report!;
    final key = '${state.ownerUid}:${report.reportId}';
    if (_viewed.contains(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent == false ||
          !_isExpectedOwner(state) ||
          !identical(_currentState, state) ||
          _viewed.contains(key)) {
        return;
      }
      _viewed.add(key);
      try {
        await widget.onReportViewed?.call(report);
      } catch (_) {
        // Optional A3/Analytics persistence must never prevent reading a report.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to route visibility so a covered snapshot is counted only after
    // this route becomes current and actually renders again.
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('うちの子の個性レポート')),
      body: StreamBuilder<PersonalityReportState>(
        key: ValueKey(_readVersion),
        stream: _stream,
        builder: (context, snapshot) {
          final incoming = snapshot.hasError
              ? const PersonalityReportState.unavailable(null)
              : snapshot.data ?? const PersonalityReportState.loading(null);
          final initialLoading =
              incoming.phase == PersonalityReportPhase.loading &&
                  incoming.ownerUid == null;
          final state = _isExpectedOwner(incoming) || initialLoading
              ? incoming
              : PersonalityReportState.unavailable(widget.expectedOwnerUid);
          _currentState = state;
          if (state.phase == PersonalityReportPhase.available &&
              state.report != null) {
            if (isCurrentRoute) _reportRendered(state);
            return _ReportContent(report: state.report!);
          }
          return _StateContent(phase: state.phase, onRetry: _retry);
        },
      ),
    );
  }
}

class _StateContent extends StatelessWidget {
  const _StateContent({required this.phase, required this.onRetry});
  final PersonalityReportPhase phase;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final loading = phase == PersonalityReportPhase.loading;
    final learning = phase == PersonalityReportPhase.learning;
    return Center(
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (loading)
          const CircularProgressIndicator()
        else
          Icon(learning ? Icons.pets_rounded : Icons.cloud_off_rounded,
              size: 52, color: AppTheme.accent),
        const SizedBox(height: 24),
        Text(
            loading
                ? '個性レポートを確認しています'
                : learning
                    ? 'うちの子らしさを集めています'
                    : '個性レポートを確認できませんでした',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(
            loading
                ? '保存済みのレポートを読み込んでいます。'
                : learning
                    ? '体重や走った記録を重ねると、準備が整った指標からこの子の普段の特徴が見えてきます。'
                    : '通信状態を確認して、もう一度お試しください。',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppTheme.secondaryText(context), height: 1.6)),
        if (!loading && !learning) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('再試行')),
        ],
      ]),
    ));
  }
}

Future<void> _openDoi(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Optional external reference cannot interrupt reading an immutable report.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('研究の出典を開けませんでした。')),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});
  final PersonalityReport report;
  @override
  Widget build(BuildContext context) {
    final vm = PersonalityReportViewModel(report);
    return DecoratedBox(
      decoration: AppTheme.dataPageDecoration(context),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: AppTheme.dataPagePadding,
          children: [
            Text('作成 ${vm.generatedAtLabel}',
                style: AppTheme.dataCaptionStyle(context)),
            const SizedBox(height: AppTheme.dataSmallGap),
            Text(vm.overviewSummary,
                key: const ValueKey('personality-overview'),
                style: AppTheme.dataDiscoveryStyle(context)),
            const SizedBox(height: AppTheme.dataSectionGap),
            if (vm.body != null) _MetricCard(metric: vm.body!),
            if (vm.body != null && vm.activity != null)
              const SizedBox(height: AppTheme.dataSectionGap),
            if (vm.activity != null) _MetricCard(metric: vm.activity!),
            if (vm.body == null || vm.activity == null) ...[
              const SizedBox(height: AppTheme.dataSectionGap),
              Text(vm.body == null ? '体重はこれから' : '活動量はこれから',
                  style: AppTheme.dataBodyStyle(context)),
              Text('生成時点では準備中のため、このレポートには含まれていません。',
                  style: AppTheme.dataCaptionStyle(context)),
            ],
            const SizedBox(height: AppTheme.dataSectionGap),
            _Details(vm: vm),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final PersonalityMetricViewModel metric;
  @override
  Widget build(BuildContext context) {
    final snapshot = metric.snapshot;
    return StatusCard(
      key: ValueKey(metric.isBody
          ? 'personality-body-card'
          : 'personality-activity-card'),
      level: StatusCardLevel.neutral,
      dataSurface: true,
      radius: AppTheme.dataCardRadius,
      padding: AppTheme.dataCardPadding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppTheme.dataContentGap,
          children: [
            Text(metric.title, style: AppTheme.dataTitleStyle(context)),
            if (!metric.isBody)
              Text('記録日の中央値', style: AppTheme.dataCaptionStyle(context)),
          ],
        ),
        const SizedBox(height: AppTheme.dataValueGap),
        MetricValueComparison(
            value: metric.value,
            unit: metric.unit,
            semanticLabel: '${metric.caption}、${metric.spokenValue}',
            differenceKey: ValueKey(metric.isBody
                ? 'body-comparison-delta'
                : 'activity-comparison-delta'),
            differenceValue: metric.comparisonDeltaValue,
            differenceCaption: metric.comparisonDeltaCaption,
            differenceContext: metric.comparisonDeltaContext,
            inlineDifferenceCaption: metric.isBody),
        if (metric.isBody) ...[
          if (!metric.populationApplicable) ...[
            const SizedBox(height: AppTheme.dataSmallGap),
            Text('この子の記録を基準にしています。', style: AppTheme.dataCaptionStyle(context)),
          ],
          if (metric.populationApplicable) ...[
            const SizedBox(height: AppTheme.dataSmallGap),
            MetricComparisonBar(
                value: snapshot.median,
                referenceValue: snapshot.population!.median,
                valueLabel: 'この子',
                referenceLabel: '参考中央値',
                unit: 'g',
                semanticUnit: 'グラム',
                referenceStart: snapshot.population!.p25,
                referenceEnd: snapshot.population!.p75,
                rangeLabel: '中央50%',
                showAxisLabels: false,
                compact: true),
          ],
        ] else ...[
          const SizedBox(height: AppTheme.dataSmallGap),
          MetricPairComparisonBars(
              value: snapshot.latestValue,
              referenceValue: snapshot.median,
              valueLabel: '直近の記録',
              referenceLabel: '普段の基準',
              unit: 'm',
              semanticUnit: 'メートル',
              compact: true),
        ],
      ]),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.vm});
  final PersonalityReportViewModel vm;
  @override
  Widget build(BuildContext context) => StatusCard(
        level: StatusCardLevel.neutral,
        dataSurface: true,
        radius: AppTheme.dataCardRadius,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          key: const ValueKey('personality-report-details'),
          title: Text('記録の詳細・研究の出典', style: AppTheme.dataBodyStyle(context)),
          initiallyExpanded: false,
          tilePadding: AppTheme.dataDetailsPadding,
          childrenPadding: AppTheme.dataDetailsContentPadding,
          children: [
            DefaultTextStyle(
              style: AppTheme.dataCaptionStyle(context),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final metric in [vm.body, vm.activity])
                      if (metric != null) ...[
                        Text(metric.title,
                            style: AppTheme.dataTitleStyle(context)),
                        const SizedBox(height: AppTheme.dataSmallGap),
                        _DetailRow(
                            label: '中央値', value: metric.medianValueDetail),
                        _DetailRow(label: 'MAD', value: metric.madValueDetail),
                        _DetailRow(
                            label: '観察期間',
                            value: metric.observationPeriodLabel),
                        _DetailRow(
                            label: '有効記録数',
                            value: metric.observationCoverageLabel),
                        _DetailRow(
                            label: '直近の記録', value: metric.latestValueLabel),
                        if (metric.isBody && metric.latestComparison != null)
                          Text(metric.latestComparison!),
                        if (metric.snapshot.latestDateKey != null)
                          _DetailRow(
                              label: '最新記録日',
                              value: metric.snapshot.latestDateKey!),
                        const SizedBox(height: AppTheme.dataSectionGap),
                      ],
                    if (vm.body?.snapshot.population != null)
                      ..._referenceDetails(context, vm.body!),
                    _DetailRow(label: '評価日', value: vm.evaluationDateLabel),
                    if (vm.isDaily)
                      _DetailRow(
                          label: '採用最終日', value: vm.cutoffDateLabel ?? '未確認'),
                    _DetailRow(label: 'Silver基準日', value: vm.silverDateLabel),
                    const SizedBox(height: AppTheme.dataContentGap),
                    Text('生成時点の記録を保存しています。後日の記録では変わりません。'),
                    const SizedBox(height: AppTheme.dataContentGap),
                    for (final text in vm.detailsLimitations)
                      Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppTheme.dataSmallGap),
                          child: Text(text)),
                  ]),
            ),
          ],
        ),
      );
  List<Widget> _referenceDetails(
      BuildContext context, PersonalityMetricViewModel metric) {
    final population = metric.snapshot.population!;
    final uri = metric.referenceDoiUri;
    return [
      Text('研究の出典', style: AppTheme.dataTitleStyle(context)),
      const SizedBox(height: AppTheme.dataSmallGap),
      if (metric.populationApplicable) ...[
        if (metric.populationMedianDetail != null)
          Text(metric.populationMedianDetail!),
        if (metric.populationRangeDetail != null)
          Text(metric.populationRangeDetail!),
      ] else
        Text(population.expression),
      const SizedBox(height: AppTheme.dataSmallGap),
      Text(population.sourceTitle ?? '公開研究'),
      if (uri != null)
        Semantics(
            link: true,
            child: TextButton(
              onPressed: () => _openDoi(context, uri),
              child: Text('DOI: ${population.sourceDoi}',
                  softWrap: true,
                  textAlign: TextAlign.start,
                  style: AppTheme.dataBodyStyle(context)),
            ))
      else
        const Text('DOI: 未確認'),
      if (population.population != null) Text(population.population!),
      Text(
          '研究対象年: ${population.studyYear ?? '未確認'} ・ 公表年: ${population.sourceYear ?? '未確認'}'),
      Text(
          '種別総個体数: ${population.speciesPopulationSize ?? '未確認'} / 成体体重の標本数: ${population.weightSampleSize ?? '未公表'}'),
      const SizedBox(height: AppTheme.dataContentGap),
      Text('研究の適用条件', style: AppTheme.dataTitleStyle(context)),
      const SizedBox(height: AppTheme.dataSmallGap),
      const Text('対応する種別の成体（3か月超）で、観察開始時・評価時の年齢が確認できる場合に適用します。'),
      const SizedBox(height: AppTheme.dataSectionGap),
    ];
  }
}

/// Saved labels and values align at ordinary sizes; enlarged/narrow layouts
/// stack instead of truncating dates or reducing the user's text scale.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.dataDetailRowGap),
        child: LayoutBuilder(builder: (context, constraints) {
          final labelWidth = AppTheme.dataDetailLabelWidth *
              MediaQuery.textScalerOf(context).scale(1);
          final labelWidget = Text(label);
          final valueWidget = Text(value);
          if (constraints.maxWidth < labelWidth * 2) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelWidget, valueWidget]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: labelWidth, child: labelWidget),
            Expanded(child: valueWidget)
          ]);
        }),
      );
}
