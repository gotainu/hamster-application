// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/daily_status_summary_service.dart
import '../models/activity_summary.dart';
import '../models/environment_assessment.dart';
import '../models/sensor_evaluation.dart';
import 'sensor_evaluation_service.dart';

class DailyStatusSummaryService {
  final SensorEvaluationService _sensorEvaluationService;

  const DailyStatusSummaryService({
    SensorEvaluationService sensorEvaluationService =
        const SensorEvaluationService(),
  }) : _sensorEvaluationService = sensorEvaluationService;

  SensorEvaluation buildSensorEvaluation({
    required EnvironmentAssessment assessment,
    required ActivitySummary activitySummary,
  }) {
    return _sensorEvaluationService.build(
      avgTemp: assessment.avgTemp,
      avgHum: assessment.avgHum,
      activitySummary: activitySummary,
    );
  }
}
