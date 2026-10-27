import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/checkin_insight.dart';
import '../models/current_weight_analysis.dart' show weightAnalysisDateKeyJst;
import 'current_weight_analysis_repo.dart';

abstract interface class CheckinInsightsSource {
  Stream<CurrentCheckinAnalysis?> watchCurrent();
}

abstract interface class CurrentCheckinReadSource {
  String? get currentOwnerId;
  Stream<String?> watchOwnerId();
  Stream<WeightAnalysisDocument> watchUserDocument(
      String ownerId, String collection, String documentId);
}

/// Reuses metadata-aware document reads, without subscribing to weight,
/// profile, baseline readiness or any research reference.
class FirebaseCurrentCheckinReadSource implements CurrentCheckinReadSource {
  CurrentWeightReadSource? _reads;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _db;
  FirebaseCurrentCheckinReadSource({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth,
        _db = db;
  CurrentWeightReadSource get _source =>
      _reads ??= FirebaseCurrentWeightReadSource(auth: _auth, db: _db);
  @override
  String? get currentOwnerId => _source.currentOwnerId;
  @override
  Stream<String?> watchOwnerId() async* {
    yield* _source.watchOwnerId();
  }

  @override
  Stream<WeightAnalysisDocument> watchUserDocument(
          String ownerId, String collection, String documentId) =>
      _source.watchUserDocument(ownerId, collection, documentId);
}

/// Exact-day committed Silver and current Gold only. Reports, write APIs,
/// entitlement and research are deliberately absent.
class CurrentCheckinInsightsRepo implements CheckinInsightsSource {
  final CurrentCheckinReadSource _source;
  final DateTime Function() _now;
  final Stream<DateTime>? _evaluationTicks;
  CurrentCheckinInsightsRepo({
    CurrentCheckinReadSource? source,
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    DateTime Function()? now,
    Stream<DateTime>? evaluationTicks,
  })  : _source =
            source ?? FirebaseCurrentCheckinReadSource(auth: auth, db: db),
        _now = now ?? DateTime.now,
        _evaluationTicks = evaluationTicks;

  @override
  Stream<CurrentCheckinAnalysis?> watchCurrent() {
    late StreamController<CurrentCheckinAnalysis?> controller;
    StreamSubscription<String?>? ownerSubscription;
    StreamSubscription<DateTime>? ticks;
    final subscriptions = <StreamSubscription<WeightAnalysisDocument>>[];
    Timer? timer;
    String? owner;
    var day = weightAnalysisDateKeyJst(_now());
    var generation = 0;
    var cancelled = false;
    WeightAnalysisDocument? silver, gold;

    bool current(int token) =>
        !cancelled &&
        generation == token &&
        owner != null &&
        owner == _source.currentOwnerId;
    void emit(CurrentCheckinAnalysis? value) {
      if (!cancelled) controller.add(value);
    }

    void clear() {
      generation++;
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      subscriptions.clear();
      silver = null;
      gold = null;
    }

    void publish(int token) {
      if (!current(token)) return;
      final s = silver, g = gold;
      if (s == null ||
          g == null ||
          !s.serverConfirmed ||
          !g.serverConfirmed ||
          !s.exists ||
          !g.exists ||
          s.data == null ||
          g.data == null) {
        emit(null);
        return;
      }
      try {
        emit(CurrentCheckinAnalysis.fromDocuments(
            ownerId: owner!,
            evaluationDateKey: day,
            silver: s.data!,
            gold: g.data!));
      } on FormatException {
        emit(null);
      }
    }

    void start(String? nextOwner) {
      clear();
      owner = nextOwner;
      emit(null);
      if (owner == null) return;
      final token = generation;
      subscriptions.add(_source
          .watchUserDocument(owner!, 'daily_health_features', day)
          .listen((value) {
        if (!current(token)) return;
        silver = value;
        publish(token);
      }, onError: (Object error, StackTrace trace) {
        if (!current(token)) return;
        silver = null;
        emit(null);
      }));
      subscriptions.add(_source
          .watchUserDocument(owner!, 'individual_insights', day)
          .listen((value) {
        if (!current(token)) return;
        gold = value;
        publish(token);
      }, onError: (Object error, StackTrace trace) {
        if (!current(token)) return;
        gold = null;
        emit(null);
      }));
    }

    void tick(DateTime instant) {
      final next = weightAnalysisDateKeyJst(instant);
      if (next == day) return;
      day = next;
      start(_source.currentOwnerId);
    }

    controller = StreamController<CurrentCheckinAnalysis?>(onListen: () {
      emit(null);
      ownerSubscription = _source.watchOwnerId().distinct().listen(start,
          onError: (Object error, StackTrace trace) {
        clear();
        owner = null;
        emit(null);
      });
      if (_evaluationTicks != null) {
        ticks = _evaluationTicks.listen(tick);
      } else {
        timer =
            Timer.periodic(const Duration(seconds: 30), (_) => tick(_now()));
      }
    }, onCancel: () async {
      cancelled = true;
      timer?.cancel();
      clear();
      await ownerSubscription?.cancel();
      await ticks?.cancel();
    });
    return controller.stream;
  }
}
