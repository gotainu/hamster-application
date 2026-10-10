import 'package:intl/intl.dart';

import '../models/personality_report.dart';

/// Presentation of a committed Gold snapshot. This never reads current records,
/// recomputes a baseline, or changes the server's population applicability.
class PersonalityReportViewModel {
  PersonalityReportViewModel(this.report)
      : body = report.body == null
            ? null
            : PersonalityMetricViewModel(report.body!, isBody: true),
        activity = report.activity == null
            ? null
            : PersonalityMetricViewModel(report.activity!, isBody: false);

  final PersonalityReport report;
  final PersonalityMetricViewModel? body;
  final PersonalityMetricViewModel? activity;

  List<String> get discoveries => List.unmodifiable([
        if (body?.discovery != null) body!.discovery!,
        if (activity?.discovery != null) activity!.discovery!,
      ]);

  /// One introductory sentence adds observation context without repeating the
  /// numerical or population comparisons shown in the metric cards.
  String get overviewSummary {
    final metrics = [
      if (body != null) body!.snapshot,
      if (activity != null) activity!.snapshot,
    ];
    final first = metrics.first;
    final commonPeriod = metrics.every((metric) =>
        metric.firstDateKey == first.firstDateKey &&
        metric.lastDateKey == first.lastDateKey &&
        metric.spanDays == first.spanDays);
    return commonPeriod
        ? '${first.spanDays}日間の観察から見える、この子らしさ。'
        : '記録から見える、この子の体重と活動量。';
  }

  /// Display the saved instant in HamCare's Japanese release timezone without
  /// depending on the device or Golden Test host's local timezone.
  String get generatedAtLabel {
    final jst = report.generatedAt.toUtc().add(const Duration(hours: 9));
    return '${jst.year}/${jst.month}/${jst.day} '
        '${jst.hour.toString().padLeft(2, '0')}:'
        '${jst.minute.toString().padLeft(2, '0')} JST';
  }

  String get headerLabel => switch (report.type) {
        PersonalityReportType.weightOnly => '体重の記録で見えてきた個性',
        PersonalityReportType.activityOnly => '走る記録で見えてきた個性',
        PersonalityReportType.both => '体重と走る記録で見えてきた個性',
      };

  bool get isDaily => report.isDaily;
  String get evaluationDateLabel => report.evaluationDateKey;
  String? get cutoffDateLabel => report.cutoffDateKey;
  String get silverDateLabel => report.silverDateKey;

  List<String> get limitations => List.unmodifiable({
        ...report.limitations,
        ...?report.body?.population?.limitations,
        ...?report.activity?.population?.limitations,
      });

  /// Known saved notices have shorter display equivalents. Unrecognized study
  /// qualifications remain verbatim; the original Gold notices are untouched.
  List<String> get detailsLimitations => List.unmodifiable({
        for (final text in limitations) ..._conciseNotices(text),
        if (report.body?.population != null) _referenceNormalNote,
        if (report.body?.population?.sampleSizeCaution == true)
          _genericSampleNote,
      });
}

/// Unit, rounding and short wording for one saved ready metric. Differences are
/// presentation arithmetic on stored values, not a new statistical calculation.
class PersonalityMetricViewModel {
  const PersonalityMetricViewModel(this.snapshot, {required this.isBody});

  final PersonalityMetricSnapshot snapshot;
  final bool isBody;

  String get title => isBody ? '体重' : '活動量';
  String get value => _number(snapshot.median, digits: isBody ? 1 : 0);
  String get unit => isBody ? 'g' : 'm / 日';
  String get spokenValue => isBody ? '$valueグラム' : '$valueメートル/日';
  String get caption => isBody ? 'この子の普段の体重' : '日別記録から見える普段の走行距離';
  String get baselineValueLabel => '$value${snapshot.unit}';
  String get latestValueLabel => snapshot.latestValue == null
      ? '未記録'
      : '${_number(snapshot.latestValue!, digits: isBody ? 1 : 0)}${snapshot.unit}';

  bool get populationApplicable =>
      isBody && snapshot.population?.isApplicable == true;

  /// The compact comparison is arithmetic on two saved Gold values. Missing
  /// applicability or latest data withholds the pill instead of implying zero.
  double? get _comparisonDelta {
    if (isBody) {
      final reference = snapshot.population?.median;
      return populationApplicable && reference != null
          ? snapshot.median - reference
          : null;
    }
    final latest = snapshot.latestValue;
    return latest == null ? null : latest - snapshot.median;
  }

  String? get comparisonDeltaValue {
    final delta = _comparisonDelta;
    if (delta == null) return null;
    if (delta == 0) return isBody ? '0g' : '±0m';
    final absolute = _differenceLabel(delta);
    return isBody ? absolute : '${delta < 0 ? '−' : '+'}$absolute';
  }

  String? get comparisonDeltaCaption {
    final delta = _comparisonDelta;
    if (delta == null) return null;
    if (delta == 0) return isBody ? '同じ水準' : '普段と同じ';
    return isBody
        ? (delta < 0 ? '軽め' : '重め')
        : (delta < 0 ? '普段より短い' : '普段より長い');
  }

  String? get comparisonDeltaContext {
    final delta = _comparisonDelta;
    if (!isBody || delta == null) return null;
    return delta == 0 ? '参考中央値と' : '参考中央値より';
  }

  String get summary {
    if (isBody) {
      if (!populationApplicable) return 'この子の記録から見える普段の体重';
      final reference = snapshot.population!.median!;
      if (snapshot.median == reference) return '同種の参考中央値と同じ水準';
      final difference = _differenceLabel(snapshot.median - reference);
      return '同種の参考中央値より$difference'
          '${snapshot.median < reference ? '軽め' : '重め'}';
    }
    return latestComparison ?? caption;
  }

  String? get discovery {
    if (isBody) {
      if (!populationApplicable) return null;
      final reference = snapshot.population!.median!;
      if (snapshot.median == reference) return '同種の参考中央値と同じ水準';
      return '同種の参考中央値より${snapshot.median < reference ? '軽め' : '重め'}';
    }
    final latest = snapshot.latestValue;
    if (latest == null) return null;
    if (latest == snapshot.median) return '走行距離は普段と同じ水準';
    return '走行距離は普段より${latest < snapshot.median ? '短め' : '長め'}';
  }

  String? get latestComparison {
    final latest = snapshot.latestValue;
    if (latest == null) return null;
    if (latest == snapshot.median) return '普段と同じ水準';
    final difference = _differenceLabel(latest - snapshot.median);
    final direction = isBody
        ? (latest < snapshot.median ? '軽め' : '重め')
        : (latest < snapshot.median ? '短い' : '長い');
    return '普段より$difference$direction';
  }

  /// A small real difference must not become "0g" or "0m" after display
  /// rounding. Equality wording is reserved for equal saved values.
  String _differenceLabel(double difference) {
    final absolute = difference.abs();
    final displayStep = isBody ? 0.1 : 1.0;
    if (absolute < displayStep) {
      return '${isBody ? '0.1' : '1'}${snapshot.unit}未満';
    }
    return '${_number(absolute, digits: isBody ? 1 : 0)}${snapshot.unit}';
  }

  String get medianValueDetail =>
      '${_detailNumber(snapshot.median)}${snapshot.unit}';
  String get madValueDetail => snapshot.mad == null
      ? '未算出'
      : '${_detailNumber(snapshot.mad!)}${snapshot.unit}';
  String get observationPeriodLabel =>
      '${snapshot.firstDateKey}〜${snapshot.lastDateKey}';
  String get observationCoverageLabel =>
      '${snapshot.recordCount}日 / ${snapshot.spanDays}日間';

  String get medianDetail => '中央値: $medianValueDetail';
  String get madDetail => 'MAD: $madValueDetail';
  String get recordDetail => '有効記録数: ${snapshot.recordCount}日';
  String get observationDetail =>
      '観察期間: $observationPeriodLabel（${snapshot.spanDays}日間）';

  String? get populationMedianDetail {
    final median = snapshot.population?.median;
    if (!populationApplicable || median == null) return null;
    return '同種の研究中央値: ${_detailNumber(median)}g';
  }

  String? get populationRangeDetail {
    final lower = snapshot.population?.p25;
    final upper = snapshot.population?.p75;
    if (!populationApplicable || lower == null || upper == null) return null;
    return '研究の中央50%: ${_detailNumber(lower)}〜${_detailNumber(upper)}g';
  }

  Uri? get referenceDoiUri {
    final doi = snapshot.population?.sourceDoi;
    if (doi == null ||
        !RegExp(r'^10\.\d{4,9}/[A-Za-z0-9._;()/:+\-]+$').hasMatch(doi)) {
      return null;
    }
    return Uri(scheme: 'https', host: 'doi.org', path: '/$doi');
  }
}

String _number(double value, {required int digits}) {
  final pattern = digits == 0 ? '0' : '0.${List.filled(digits, '#').join()}';
  return NumberFormat(pattern, 'en_US').format(value);
}

String _detailNumber(double value) => value != 0 && value.abs() < 0.01
    ? value.toStringAsPrecision(2)
    : _number(value, digits: 2);

String _conciseNotice(String text) =>
    const <String, String>{
      '観察記録に基づく特徴の説明です。肥満・健康・病気の診断ではありません。': '記録に基づく特徴です。肥満・健康・病気の診断ではありません。',
      '日別の活動記録から、夜型や深夜に活発かどうかは判断できません。': '日別記録から夜型や深夜の活動は判断できません。',
      '平滑化した値だけで、長期的な増減は断定できません。': 'EWMA（平滑化値）だけで長期的な増減は判断できません。',
      'MADが0でも、すべての記録が同じ値だったことを意味しません。': 'MADが0でも、全記録が同じ値とは限りません。',
      '2016年の英国の一次診療施設を受診したハムスターの記録であり、健康な個体だけの標準体重や日本の全個体を代表するものではありません。':
          '2016年の英国の一次診療の受診記録です。健康な個体の標準体重や日本の全個体を代表しません。',
      '論文は各個体の3か月超の体重記録の平均を集計しています。比較する個体のベースライン中央値とは測定のまとめ方が異なります。':
          '研究は3か月超の各個体の平均体重を集計。本レポートの中央値とは集計方法が異なります。',
      '表の種別総個体数は成人体重を解析した標本数ではありません。成人体重の種別解析数は公開表からは確認できません。':
          '種別総数は成体体重の標本数ではありません。体重の解析標本数は公開表では未確認です。',
    }[text] ??
    text;

const _referenceNormalNote = '研究集団の参考値です。健康上の正常範囲ではありません。';
const _genericSampleNote = '少数の種別集団のため、比較は慎重に扱ってください。';
const _percentileNote = '中央値と四分位点だけでは正確なパーセンタイルは求められません。';

Iterable<String> _conciseNotices(String text) {
  switch (text) {
    case '中央値と四分位点だけでは正確なパーセンタイルは計算できず、中央50%の範囲を健康・異常の判定に使うことはできません。':
    case '中央50%は健康・異常の基準ではありません。中央値と四分位点だけでは正確なパーセンタイルは求められません。':
      return const [_referenceNormalNote, _percentileNote];
    case '中央50%の範囲を健康・異常の判定に使うことはできません。':
    case '中央50%は健康・異常の基準ではありません。':
      return const [_referenceNormalNote];
    default:
      return [_conciseNotice(text)];
  }
}
