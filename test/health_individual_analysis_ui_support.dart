import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/activity_summary.dart';
import 'package:hamster_project/models/anomaly_detection.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/health_assessment.dart';
import 'package:hamster_project/screens/daily_status_detail.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'package:hamster_project/services/weight_trend_evaluation_service.dart';
import 'package:hamster_project/theme/app_theme.dart';

import 'health_analysis_test_support.dart';
import 'personality_report_v3_test_support.dart';

/// Synthetic sources never initialize Firebase, fetch accounts or write data.
class HealthScreenAnalysisSource implements WeightAnalysisSource {
  HealthScreenAnalysisSource(this.current);
  CurrentWeightAnalysis? current;
  final changes =
      StreamController<CurrentWeightAnalysis?>.broadcast(sync: true);
  int reads = 0;

  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() {
    reads++;
    return Stream.multi((sink) {
      sink.add(current);
      final subscription =
          changes.stream.listen(sink.add, onError: sink.addError);
      sink.onCancel = subscription.cancel;
    });
  }

  void emit(CurrentWeightAnalysis? value) {
    current = value;
    changes.add(value);
  }

  void emitError() => changes.addError(StateError('synthetic read failure'));
  Future<void> close() => changes.close();
}

DailyStatusDetailData healthScreenDataFixture({
  CurrentWeightAnalysis? analysis,
  HealthAssessment? assessment,
  bool confirmed = true,
  String? ownerId = 'synthetic-owner',
}) {
  final current = analysis ?? healthAnalysisFixture();
  final health = assessment ?? healthAssessmentFixture(analysis: current);
  return DailyStatusDetailData(
    ownerId: ownerId,
    healthAssessmentServerConfirmed: confirmed,
    healthAssessment: health,
    healthHistory: [health],
    assessment: null,
    history: const [],
    activitySummary: ActivitySummary.empty(),
    distanceSeries: const [],
    sensorEvaluation: null,
    anomalyDetection: AnomalyDetectionResult(
      anomalies: const [],
      windowDays: 14,
      detectedAt: DateTime.utc(2026, 10, 11, 2),
    ),
    activityReferenceDate: DateTime(2026, 10, 10),
    weightRecords: const [],
    weightEvaluation: const WeightTrendEvaluationService()
        .evaluate(const [], now: DateTime(2026, 10, 11)),
  );
}

const healthAnalysisGoldenRoot = ValueKey('health-analysis-golden-root');

Future<void> showHealthAnalysisUi(
  WidgetTester tester,
  Widget screen, {
  bool dark = true,
  Size size = const Size(393, 852),
  double textScale = 1,
  bool golden = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  if (golden) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: personalityV3GoldenFont),
      primaryTextTheme:
          theme.primaryTextTheme.apply(fontFamily: personalityV3GoldenFont),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle
            ?.copyWith(fontFamily: personalityV3GoldenFont),
      ),
    );
  }
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ja', 'JP'),
    supportedLocales: const [Locale('ja', 'JP')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: RepaintBoundary(
          key: healthAnalysisGoldenRoot,
          child:
              ColoredBox(color: theme.scaffoldBackgroundColor, child: child!)),
    ),
    home: screen,
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Widget healthTestBackground(Widget child) => child;
