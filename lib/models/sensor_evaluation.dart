// /Users/gota/local_dev/flutter_projects/hamster_project/lib/models/sensor_evaluation.dart

enum MetricState {
  unknown,
  good,
  caution,
  alert,
}

enum EvaluationFlag {
  tempLow,
  tempHigh,
  humidityLow,
  humidityHigh,
  activityMissing,
  activityLow,
  activityHigh,
  activityDrop,
}

class EnvironmentMetricEvaluation {
  final double? value;
  final int score;
  final MetricState state;
  final List<EvaluationFlag> flags;
  final String reason;

  const EnvironmentMetricEvaluation({
    required this.value,
    required this.score,
    required this.state,
    required this.flags,
    required this.reason,
  });
}

class ActivityMetricEvaluation {
  final double todayDistanceMeters;
  final double avg7DistanceMeters;
  final double deltaPct;
  final int score;
  final MetricState state;
  final List<EvaluationFlag> flags;
  final String reason;

  const ActivityMetricEvaluation({
    required this.todayDistanceMeters,
    required this.avg7DistanceMeters,
    required this.deltaPct,
    required this.score,
    required this.state,
    required this.flags,
    required this.reason,
  });
}

class SensorEvaluation {
  final EnvironmentMetricEvaluation temperature;
  final EnvironmentMetricEvaluation humidity;
  final ActivityMetricEvaluation activity;
  final int overallScore;
  final MetricState overallState;
  final List<EvaluationFlag> flags;
  final String summary;

  const SensorEvaluation({
    required this.temperature,
    required this.humidity,
    required this.activity,
    required this.overallScore,
    required this.overallState,
    required this.flags,
    required this.summary,
  });
}
