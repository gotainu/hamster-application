import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String healthIncidentDocumentId(String incidentId) {
  final normalized = incidentId.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]+'),
    '__',
  );
  return normalized.length <= 180 ? normalized : normalized.substring(0, 180);
}

class HealthIncident {
  const HealthIncident({
    required this.incidentId,
    required this.status,
    required this.domain,
    required this.conditionType,
    required this.severity,
    required this.state,
    required this.score,
    required this.occurrenceCount,
  });

  final String incidentId;
  final String status;
  final String domain;
  final String conditionType;
  final String severity;
  final String state;
  final num? score;
  final int occurrenceCount;

  bool get isResolved => status == 'resolved';

  factory HealthIncident.fromMap(Map<String, dynamic> data) {
    return HealthIncident(
      incidentId: data['incidentId'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      domain: data['domain'] as String? ?? '',
      conditionType: data['conditionType'] as String? ?? '',
      severity: data['currentSeverity'] as String? ?? 'medium',
      state: data['currentState'] as String? ?? 'changed',
      score: data['currentScore'] as num?,
      occurrenceCount: data['occurrenceCount'] as int? ?? 1,
    );
  }
}

class HealthIncidentAction {
  const HealthIncidentAction({
    this.acknowledgedAt,
    this.snoozedUntil,
  });

  final DateTime? acknowledgedAt;
  final DateTime? snoozedUntil;

  bool get isAcknowledged => acknowledgedAt != null;
  bool get isSnoozed =>
      snoozedUntil != null && snoozedUntil!.isAfter(DateTime.now());

  factory HealthIncidentAction.fromMap(Map<String, dynamic>? data) {
    return HealthIncidentAction(
      acknowledgedAt: (data?['acknowledgedAt'] as Timestamp?)?.toDate(),
      snoozedUntil: (data?['snoozedUntil'] as Timestamp?)?.toDate(),
    );
  }
}

class HealthIncidentService {
  HealthIncidentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _incidentRef(String incidentId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('ログインユーザーが見つかりません。');
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('health_incidents')
        .doc(healthIncidentDocumentId(incidentId));
  }

  DocumentReference<Map<String, dynamic>> _actionRef(String incidentId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('ログインユーザーが見つかりません。');
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('health_incident_actions')
        .doc(healthIncidentDocumentId(incidentId));
  }

  Stream<HealthIncident?> watchIncident(String incidentId) {
    try {
      return _incidentRef(incidentId).snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : HealthIncident.fromMap(data);
      });
    } on StateError {
      return Stream.value(null);
    }
  }

  Stream<HealthIncidentAction> watchAction(String incidentId) {
    try {
      return _actionRef(incidentId).snapshots().map(
            (snapshot) => HealthIncidentAction.fromMap(snapshot.data()),
          );
    } on StateError {
      return Stream.value(const HealthIncidentAction());
    }
  }

  Future<void> acknowledge(String incidentId) async {
    await _actionRef(incidentId).set(
      {
        'incidentId': incidentId,
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'snoozedUntil': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> snoozeFor24Hours(String incidentId) async {
    await _actionRef(incidentId).set(
      {
        'incidentId': incidentId,
        'snoozedUntil': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
