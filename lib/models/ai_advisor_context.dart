import 'package:hamster_project/models/anomaly_detection.dart';
import 'package:hamster_project/models/environment_assessment.dart';
import 'package:hamster_project/models/sensor_evaluation.dart';
import 'package:hamster_project/models/weight_trend_evaluation.dart';

class AiAdvisorContext {
  final EnvironmentAssessment? environment;
  final SensorEvaluation? sensorEvaluation;
  final AnomalyDetectionResult? anomalyDetection;
  final WeightTrendEvaluation? weightTrend;
  final String promptText;

  const AiAdvisorContext({
    required this.environment,
    required this.sensorEvaluation,
    required this.anomalyDetection,
    this.weightTrend,
    required this.promptText,
  });

  bool get hasAnyContext => promptText.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'environment': environment == null
          ? null
          : {
              'status': environment!.status,
              'level': environment!.level,
              'headline': environment!.headline,
              'todayAction': environment!.todayAction,
              'why': environment!.why,
              'avgTemp': environment!.avgTemp,
              'avgHum': environment!.avgHum,
              'tempRatio': environment!.tempRatio,
              'humRatio': environment!.humRatio,
              'tempState': environment!.tempState,
              'humState': environment!.humState,
              'tempInterpretation': environment!.tempInterpretation,
              'humInterpretation': environment!.humInterpretation,
              'evidence': environment!.evidence,
              'notes': environment!.notes,
            },
      'sensorEvaluation': sensorEvaluation == null
          ? null
          : {
              'overallState': sensorEvaluation!.overallState.name,
              'flags': sensorEvaluation!.flags.map((e) => e.name).toList(),
            },
      'weightTrend': weightTrend == null
          ? null
          : {
              'state': weightTrend!.state.name,
              'latestWeightGrams': weightTrend!.latest?.weightGrams,
              'latestDate': weightTrend!.latest?.date.toIso8601String(),
              'previousDifferenceGrams': weightTrend!.previousDifferenceGrams,
              'previousChangeRate': weightTrend!.previousChangeRate,
              'periodChangeRate': weightTrend!.periodChangeRate,
              'recordCount': weightTrend!.records.length,
              'daysSinceLatest': weightTrend!.daysSinceLatest,
              'headline': weightTrend!.headline,
              'message': weightTrend!.message,
            },
      'anomalyDetection': anomalyDetection == null
          ? null
          : {
              'hasAnomaly': anomalyDetection!.hasAnomaly,
              'topAnomaly': anomalyDetection!.topAnomaly == null
                  ? null
                  : {
                      'flag': anomalyDetection!.topAnomaly!.flag.name,
                      'severity': anomalyDetection!.topAnomaly!.severity.name,
                      'title': anomalyDetection!.topAnomaly!.title,
                      'description': anomalyDetection!.topAnomaly!.description,
                    },
            },
    };
  }
}
