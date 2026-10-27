import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/current_weight_analysis.dart';
import '../models/daily_health_features.dart';
import '../models/reference_weight_cohort.dart';
import '../models/weight_insight.dart';

abstract interface class WeightAnalysisSource {
  Stream<CurrentWeightAnalysis?> watchCurrent();
}

/// Only read operations are exposed, making source/owner sequencing testable
/// without Firestore writes or a live backend.
abstract interface class CurrentWeightReadSource {
  String? get currentOwnerId;
  Stream<String?> watchOwnerId();
  Stream<WeightAnalysisDocument> watchUserDocument(
      String ownerId, String collection, String documentId);
  Stream<WeightAnalysisDocument> watchReferenceDocument(String cohortId,
      {String? versionId});
}

class WeightAnalysisDocument {
  final bool exists;
  final Map<String, dynamic>? data;
  final bool isFromCache;
  final bool hasPendingWrites;
  const WeightAnalysisDocument({
    required this.exists,
    required this.data,
    this.isFromCache = false,
    this.hasPendingWrites = false,
  });
  bool get serverConfirmed => !isFromCache && !hasPendingWrites;
}

class FirebaseCurrentWeightReadSource implements CurrentWeightReadSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  FirebaseCurrentWeightReadSource({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;
  @override
  String? get currentOwnerId => _auth.currentUser?.uid;
  @override
  Stream<String?> watchOwnerId() async* {
    yield currentOwnerId;
    yield* _auth.authStateChanges().map((user) => user?.uid);
  }

  Stream<WeightAnalysisDocument> _watch(
          DocumentReference<Map<String, dynamic>> document) =>
      document.snapshots(includeMetadataChanges: true).map((snapshot) =>
          WeightAnalysisDocument(
              exists: snapshot.exists,
              data: snapshot.data(),
              isFromCache: snapshot.metadata.isFromCache,
              hasPendingWrites: snapshot.metadata.hasPendingWrites));

  @override
  Stream<WeightAnalysisDocument> watchUserDocument(
          String ownerId, String collection, String documentId) =>
      _watch(_db
          .collection('users')
          .doc(ownerId)
          .collection(collection)
          .doc(documentId));
  @override
  Stream<WeightAnalysisDocument> watchReferenceDocument(String cohortId,
          {String? versionId}) =>
      _watch(versionId == null
          ? _db.collection('reference_cohorts').doc(cohortId)
          : _db
              .collection('reference_cohorts')
              .doc(cohortId)
              .collection('versions')
              .doc(versionId));
}

/// Exact-day current Silver + current profile + versioned research reference.
/// Immutable reports, report pointers, health scores and write APIs are absent.
class CurrentWeightAnalysisRepo implements WeightAnalysisSource {
  final CurrentWeightReadSource _source;
  final DateTime Function() _now;
  final Stream<DateTime>? _evaluationTicks;

  /// Phase 2 may show the confirmed individual baseline even when the research
  /// reference is not available. The default preserves Phase 1 strict loading.
  final bool includeIndividualAnalysisWithoutReference;

  /// Opt-in exact-day server Gold; existing comparison subscriptions are kept.
  final bool includeInsights;
  CurrentWeightAnalysisRepo({
    CurrentWeightReadSource? source,
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    DateTime Function()? now,
    Stream<DateTime>? evaluationTicks,
    this.includeIndividualAnalysisWithoutReference = false,
    this.includeInsights = false,
  })  : _source = source ?? FirebaseCurrentWeightReadSource(auth: auth, db: db),
        _now = now ?? DateTime.now,
        _evaluationTicks = evaluationTicks;

  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() {
    late StreamController<CurrentWeightAnalysis?> controller;
    StreamSubscription<String?>? ownerSubscription;
    StreamSubscription<DateTime>? tickSubscription;
    final userSubscriptions = <StreamSubscription<WeightAnalysisDocument>>[];
    StreamSubscription<WeightAnalysisDocument>? rootSubscription;
    StreamSubscription<WeightAnalysisDocument>? versionSubscription;
    Timer? timer;
    String? owner;
    var evaluationKey = weightAnalysisDateKeyJst(_now());
    var generation = 0;
    var referenceGeneration = 0;
    var cancelled = false;
    WeightAnalysisDocument? featureDocument;
    WeightAnalysisDocument? profileDocument;
    WeightAnalysisDocument? insightDocument;
    ReferenceWeightCohort? reference;
    String? watchedCohort;
    String? watchedVersion;
    var rootConfirmed = false;
    var versionConfirmed = false;

    bool isCurrent(int token) =>
        !cancelled &&
        generation == token &&
        owner != null &&
        _source.currentOwnerId == owner;
    void add(CurrentWeightAnalysis? value) {
      if (!cancelled) controller.add(value);
    }

    void clearReference() {
      referenceGeneration++;
      unawaited(rootSubscription?.cancel());
      unawaited(versionSubscription?.cancel());
      rootSubscription = null;
      versionSubscription = null;
      watchedCohort = null;
      watchedVersion = null;
      rootConfirmed = false;
      versionConfirmed = false;
      reference = null;
    }

    void clearUser() {
      generation++;
      for (final subscription in userSubscriptions) {
        unawaited(subscription.cancel());
      }
      userSubscriptions.clear();
      featureDocument = null;
      profileDocument = null;
      insightDocument = null;
      clearReference();
    }

    CurrentWeightAnalysis? decode({bool withoutReference = false}) {
      final feature = featureDocument;
      final profile = profileDocument;
      if (owner == null ||
          feature == null ||
          profile == null ||
          !feature.serverConfirmed ||
          !profile.serverConfirmed ||
          !feature.exists ||
          feature.data == null ||
          feature.data!['dateKey'] is! String ||
          feature.data!['schemaVersion'] != 5) {
        return null;
      }
      try {
        final features = DailyHealthFeatures.fromMap(feature.data!,
            fallbackDateKey: evaluationKey);
        CurrentInsightSet? insights;
        final document = insightDocument;
        if (includeInsights &&
            document != null &&
            document.serverConfirmed &&
            document.exists &&
            document.data != null) {
          try {
            insights = CurrentInsightSet.fromMap(document.data!,
                features: features, evaluationDateKey: evaluationKey);
          } on FormatException {
            insights = null;
          }
        }
        return CurrentWeightAnalysis(
            ownerId: owner!,
            evaluationDateKey: evaluationKey,
            features: features,
            insights: insights,
            profile: CurrentWeightProfile.fromMap(
                profile.exists ? profile.data ?? {} : {}),
            reference: withoutReference ? null : reference);
      } catch (_) {
        return null;
      }
    }

    void publishWithoutReference() {
      if (includeIndividualAnalysisWithoutReference && isCurrent(generation)) {
        add(decode(withoutReference: true));
      } else {
        add(null);
      }
    }

    void invalidateVersion() {
      unawaited(versionSubscription?.cancel());
      versionSubscription = null;
      watchedVersion = null;
      versionConfirmed = false;
      reference = null;
    }

    late void Function() publish;
    void startReference(String cohortId, String species, int token) {
      clearReference();
      watchedCohort = cohortId;
      final referenceToken = referenceGeneration;
      bool stillCurrent() =>
          isCurrent(token) &&
          referenceGeneration == referenceToken &&
          watchedCohort == cohortId;
      rootSubscription =
          _source.watchReferenceDocument(cohortId).listen((document) {
        if (!stillCurrent()) return;
        rootConfirmed = document.serverConfirmed;
        if (!rootConfirmed) {
          invalidateVersion();
          publishWithoutReference();
          return;
        }
        final data = document.data;
        final version = data?['currentReferenceVersion'];
        if (!document.exists ||
            data == null ||
            data['speciesCode'] != species ||
            data['metric'] != 'weight' ||
            data['unit'] != 'g' ||
            data['sourceType'] != 'published_research' ||
            !isWeightReferenceVersionId(version)) {
          unawaited(versionSubscription?.cancel());
          versionSubscription = null;
          watchedVersion = null;
          reference = null;
          versionConfirmed = true;
          publish();
          return;
        }
        if (watchedVersion == version) {
          publish();
          return;
        }
        unawaited(versionSubscription?.cancel());
        watchedVersion = version as String;
        versionConfirmed = false;
        reference = null;
        publishWithoutReference();
        final expectedVersion = watchedVersion!;
        versionSubscription = _source
            .watchReferenceDocument(cohortId, versionId: expectedVersion)
            .listen((value) {
          if (!stillCurrent() || watchedVersion != expectedVersion) return;
          versionConfirmed = value.serverConfirmed;
          reference = null;
          if (versionConfirmed && value.exists && value.data != null) {
            try {
              reference = ReferenceWeightCohort.fromMap(value.data!,
                  expectedSpecies: species, expectedVersion: expectedVersion);
            } on FormatException {
              reference = null;
            }
          }
          publish();
        }, onError: (Object error, StackTrace trace) {
          if (!stillCurrent() || watchedVersion != expectedVersion) return;
          versionConfirmed = false;
          reference = null;
          publishWithoutReference();
        });
      }, onError: (Object error, StackTrace trace) {
        if (!stillCurrent()) return;
        rootConfirmed = false;
        invalidateVersion();
        publishWithoutReference();
      });
    }

    publish = () {
      final token = generation;
      if (!isCurrent(token)) {
        add(null);
        return;
      }
      final analysis = decode();
      if (analysis == null) {
        add(null);
        return;
      }
      final withoutReference = CurrentWeightAnalysis(
          ownerId: analysis.ownerId,
          evaluationDateKey: analysis.evaluationDateKey,
          features: analysis.features,
          profile: analysis.profile,
          reference: null,
          insights: analysis.insights);
      if (withoutReference.omissionReason != 'reference_unavailable') {
        clearReference();
        add(withoutReference);
        return;
      }
      final species = analysis.profile.speciesCode!;
      final cohort = '${species}_adult_weight';
      if (watchedCohort != cohort) {
        publishWithoutReference();
        startReference(cohort, species, token);
        return;
      }
      if (!rootConfirmed || !versionConfirmed) {
        publishWithoutReference();
        return;
      }
      add(decode());
    };

    void startUser(String? nextOwner) {
      clearUser();
      owner = nextOwner;
      add(null);
      if (nextOwner == null) return;
      final token = generation;
      userSubscriptions.add(_source
          .watchUserDocument(nextOwner, 'daily_health_features', evaluationKey)
          .listen((document) {
        if (!isCurrent(token)) return;
        featureDocument = document;
        publish();
      }, onError: (Object error, StackTrace trace) {
        if (!isCurrent(token)) return;
        featureDocument = null;
        add(null);
      }));
      if (includeInsights) {
        userSubscriptions.add(_source
            .watchUserDocument(nextOwner, 'individual_insights', evaluationKey)
            .listen((document) {
          if (!isCurrent(token)) return;
          insightDocument = document;
          publish();
        }, onError: (Object error, StackTrace trace) {
          if (!isCurrent(token)) return;
          insightDocument = null;
          publish();
        }));
      }
      userSubscriptions.add(_source
          .watchUserDocument(nextOwner, 'pet_profiles', 'main_pet')
          .listen((document) {
        if (!isCurrent(token)) return;
        profileDocument = document;
        publish();
      }, onError: (Object error, StackTrace trace) {
        if (!isCurrent(token)) return;
        profileDocument = null;
        add(null);
      }));
    }

    void tick(DateTime instant) {
      final key = weightAnalysisDateKeyJst(instant);
      if (key == evaluationKey) return;
      evaluationKey = key;
      startUser(_source.currentOwnerId);
    }

    controller = StreamController<CurrentWeightAnalysis?>(onListen: () {
      add(null);
      ownerSubscription = _source.watchOwnerId().distinct().listen(startUser,
          onError: (Object error, StackTrace trace) {
        clearUser();
        owner = null;
        add(null);
      });
      if (_evaluationTicks != null) {
        tickSubscription = _evaluationTicks.listen(tick);
      } else {
        timer =
            Timer.periodic(const Duration(seconds: 30), (_) => tick(_now()));
      }
    }, onCancel: () async {
      cancelled = true;
      timer?.cancel();
      clearUser();
      await ownerSubscription?.cancel();
      await tickSubscription?.cancel();
    });
    return controller.stream;
  }
}
