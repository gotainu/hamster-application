import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

enum HealthAssessmentState {
  unknown,
  good,
  stable,
  changed,
  caution,
  alert,
  insufficientData,
}

enum HealthAssessmentConfidence {
  insufficient,
  low,
  medium,
  high,
}

class HealthAssessment {
  final String dateKey;
  final String featureDateKey;
  final HealthAssessmentDomains domains;
  final HealthOverallAssessment overall;
  final HealthAssessmentDataQuality dataQuality;
  final HealthAiAdvisorContext? aiAdvisorContext;
  final int evaluatorVersion;
  final DateTime? evaluatedAt;

  const HealthAssessment({
    required this.dateKey,
    required this.featureDateKey,
    required this.domains,
    required this.overall,
    required this.dataQuality,
    required this.aiAdvisorContext,
    required this.evaluatorVersion,
    required this.evaluatedAt,
  });

  factory HealthAssessment.fromMap(
    Json map, {
    required String fallbackDateKey,
  }) {
    return HealthAssessment(
      dateKey: _string(map['dateKey']) ?? fallbackDateKey,
      featureDateKey: _string(map['featureDateKey']) ?? fallbackDateKey,
      domains: HealthAssessmentDomains.fromMap(
        _json(map['domains']),
      ),
      overall: HealthOverallAssessment.fromMap(
        _json(map['overall']),
      ),
      dataQuality: HealthAssessmentDataQuality.fromMap(
        _json(map['dataQuality']),
      ),
      aiAdvisorContext: map['aiAdvisorContext'] == null
          ? null
          : HealthAiAdvisorContext.fromMap(
              _json(map['aiAdvisorContext']),
            ),
      evaluatorVersion: _integer(map['evaluatorVersion']) ?? 1,
      evaluatedAt: _dateTime(map['evaluatedAt']),
    );
  }

  bool get hasMeaningfulAssessment =>
      overall.observedState != HealthAssessmentState.unknown ||
      overall.flags.isNotEmpty ||
      domains.hasAnyKnownDomain;

  Json toMap() {
    return {
      'dateKey': dateKey,
      'featureDateKey': featureDateKey,
      'domains': domains.toMap(),
      'overall': overall.toMap(),
      'dataQuality': dataQuality.toMap(),
      if (aiAdvisorContext != null)
        'aiAdvisorContext': aiAdvisorContext!.toMap(),
      'evaluatorVersion': evaluatorVersion,
      if (evaluatedAt != null) 'evaluatedAt': evaluatedAt,
    };
  }
}

class HealthAssessmentDomains {
  final HealthDomainAssessment environment;
  final HealthDomainAssessment activity;
  final HealthDomainAssessment body;
  final HealthDomainAssessment condition;
  final HealthDomainAssessment nutrition;

  const HealthAssessmentDomains({
    required this.environment,
    required this.activity,
    required this.body,
    required this.condition,
    required this.nutrition,
  });

  factory HealthAssessmentDomains.fromMap(Json map) {
    return HealthAssessmentDomains(
      environment: HealthDomainAssessment.fromMap(
        _json(map['environment']),
      ),
      activity: HealthDomainAssessment.fromMap(
        _json(map['activity']),
      ),
      body: HealthDomainAssessment.fromMap(
        _json(map['body']),
      ),
      condition: HealthDomainAssessment.fromMap(
        _json(map['condition']),
      ),
      nutrition: HealthDomainAssessment.fromMap(
        _json(map['nutrition']),
      ),
    );
  }

  bool get hasAnyKnownDomain => [
        environment,
        activity,
        body,
        condition,
        nutrition,
      ].any(
        (domain) =>
            domain.state != HealthAssessmentState.unknown &&
            domain.state != HealthAssessmentState.insufficientData,
      );

  Json toMap() {
    return {
      'environment': environment.toMap(),
      'activity': activity.toMap(),
      'body': body.toMap(),
      'condition': condition.toMap(),
      'nutrition': nutrition.toMap(),
    };
  }
}

class HealthScoreComponent {
  final int? score;
  final HealthAssessmentState state;
  final String summary;
  final List<String> flags;

  const HealthScoreComponent({
    required this.score,
    required this.state,
    required this.summary,
    required this.flags,
  });

  factory HealthScoreComponent.fromMap(Json map) {
    return HealthScoreComponent(
      score: _integer(map['score']),
      state: parseHealthAssessmentState(map['state']),
      summary: _string(map['summary']) ?? '',
      flags: _stringList(map['flags']),
    );
  }

  Json toMap() {
    return {
      'score': score,
      'state': state.name,
      'summary': summary,
      'flags': flags,
    };
  }
}

class HealthDomainAssessment {
  final HealthAssessmentState state;
  final int? score;
  final List<String> flags;
  final String summary;
  final List<String> recommendedActions;
  final DateTime? sourceUpdatedAt;
  final Map<String, HealthScoreComponent> components;

  const HealthDomainAssessment({
    required this.state,
    required this.score,
    required this.flags,
    required this.summary,
    required this.recommendedActions,
    required this.sourceUpdatedAt,
    required this.components,
  });

  factory HealthDomainAssessment.fromMap(Json map) {
    final componentMap = _json(map['components']);

    return HealthDomainAssessment(
      state: parseHealthAssessmentState(map['state']),
      score: _integer(map['score']),
      flags: _stringList(map['flags']),
      summary: _string(map['summary']) ?? '',
      recommendedActions: _stringList(map['recommendedActions']),
      sourceUpdatedAt: _dateTime(map['sourceUpdatedAt']),
      components: componentMap.map(
        (key, value) => MapEntry(
          key,
          HealthScoreComponent.fromMap(_json(value)),
        ),
      ),
    );
  }

  HealthScoreComponent? component(String key) => components[key];

  Json toMap() {
    return {
      'state': state.name,
      'score': score,
      'flags': flags,
      'summary': summary,
      'recommendedActions': recommendedActions,
      if (sourceUpdatedAt != null) 'sourceUpdatedAt': sourceUpdatedAt,
      if (components.isNotEmpty)
        'components': components.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
    };
  }
}

class HealthOverallAssessment {
  final HealthAssessmentState state;
  final int? score;
  final HealthAssessmentState observedState;
  final int? observedScore;
  final HealthAssessmentConfidence confidence;
  final bool isProvisional;
  final List<String> flags;
  final String summary;
  final List<String> recommendedActions;
  final String? primaryFactor;

  const HealthOverallAssessment({
    required this.state,
    required this.score,
    required this.observedState,
    required this.observedScore,
    required this.confidence,
    required this.isProvisional,
    required this.flags,
    required this.summary,
    required this.recommendedActions,
    required this.primaryFactor,
  });

  factory HealthOverallAssessment.fromMap(Json map) {
    final state = parseHealthAssessmentState(map['state']);
    final score = _integer(map['score']);

    return HealthOverallAssessment(
      state: state,
      score: score,
      observedState: map.containsKey('observedState')
          ? parseHealthAssessmentState(map['observedState'])
          : state,
      observedScore: map.containsKey('observedScore')
          ? _integer(map['observedScore'])
          : score,
      confidence: parseHealthAssessmentConfidence(map['confidence']),
      isProvisional: _boolean(map['isProvisional']) ?? false,
      flags: _stringList(map['flags']),
      summary: _string(map['summary']) ?? '',
      recommendedActions: _stringList(map['recommendedActions']),
      primaryFactor: _string(map['primaryFactor']),
    );
  }

  bool get hasPublishableScore => score != null;

  Json toMap() {
    return {
      'state': state.name,
      'score': score,
      'observedState': observedState.name,
      'observedScore': observedScore,
      'confidence': confidence.name,
      'isProvisional': isProvisional,
      'flags': flags,
      'summary': summary,
      'recommendedActions': recommendedActions,
      'primaryFactor': primaryFactor,
    };
  }
}

class HealthAssessmentDataQuality {
  final double completeness;
  final List<String> availableDomains;
  final List<String> missingDomains;
  final List<String> staleDomains;

  const HealthAssessmentDataQuality({
    required this.completeness,
    required this.availableDomains,
    required this.missingDomains,
    required this.staleDomains,
  });

  factory HealthAssessmentDataQuality.fromMap(Json map) {
    return HealthAssessmentDataQuality(
      completeness: _double(map['completeness']) ?? 0,
      availableDomains: _stringList(map['availableDomains']),
      missingDomains: _stringList(map['missingDomains']),
      staleDomains: _stringList(map['staleDomains']),
    );
  }

  Json toMap() {
    return {
      'completeness': completeness,
      'availableDomains': availableDomains,
      'missingDomains': missingDomains,
      'staleDomains': staleDomains,
    };
  }
}

class HealthAiAdvisorContext {
  final String status;
  final String priority;
  final String summary;
  final String promptText;
  final int version;
  final DateTime? generatedAt;

  const HealthAiAdvisorContext({
    required this.status,
    required this.priority,
    required this.summary,
    required this.promptText,
    required this.version,
    required this.generatedAt,
  });

  factory HealthAiAdvisorContext.fromMap(Json map) {
    return HealthAiAdvisorContext(
      status: _string(map['status']) ?? 'unavailable',
      priority: _string(map['priority']) ?? 'normal',
      summary: _string(map['summary']) ?? '',
      promptText: _string(map['promptText']) ?? '',
      version: _integer(map['version']) ?? 1,
      generatedAt: _dateTime(map['generatedAt']),
    );
  }

  Json toMap() {
    return {
      'status': status,
      'priority': priority,
      'summary': summary,
      'promptText': promptText,
      'version': version,
      if (generatedAt != null) 'generatedAt': generatedAt,
    };
  }
}

HealthAssessmentState parseHealthAssessmentState(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase();

  switch (normalized) {
    case 'good':
    case 'healthy':
    case 'normal':
      return HealthAssessmentState.good;
    case 'stable':
      return HealthAssessmentState.stable;
    case 'changed':
    case 'change':
      return HealthAssessmentState.changed;
    case 'caution':
    case 'warning':
      return HealthAssessmentState.caution;
    case 'alert':
    case 'danger':
    case 'critical':
      return HealthAssessmentState.alert;
    case 'insufficientdata':
    case 'insufficient_data':
    case 'unavailable':
    case 'missing':
      return HealthAssessmentState.insufficientData;
    default:
      return HealthAssessmentState.unknown;
  }
}

HealthAssessmentConfidence parseHealthAssessmentConfidence(
  dynamic value,
) {
  final normalized = value?.toString().trim().toLowerCase();

  switch (normalized) {
    case 'high':
      return HealthAssessmentConfidence.high;
    case 'medium':
      return HealthAssessmentConfidence.medium;
    case 'low':
      return HealthAssessmentConfidence.low;
    case 'insufficient':
    default:
      return HealthAssessmentConfidence.insufficient;
  }
}

Json _json(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _boolean(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return null;
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
