import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/care_continuity.dart';

abstract interface class CareContinuitySource {
  Stream<CareContinuityState> watch();
  Future<CareContinuityState> refresh();
  Future<List<CareContinuityDay>> calendar(
      {String? startDateKey, String? endDateKey});
  Future<CareRewardRetryResult> retryCareReward(
      {required String dayKey, required String mutationId});
}

class CareContinuityRepo implements CareContinuitySource {
  CareContinuityRepo(
      {FirebaseFirestore? db,
      FirebaseAuth? auth,
      FirebaseFunctions? functions,
      String? Function()? owner,
      Future<Map<String, dynamic>> Function()? refreshServer,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)? retryServer})
      : _db = db,
        _auth = auth,
        _functions = functions,
        _ownerOverride = owner,
        _refreshOverride = refreshServer,
        _retryOverride = retryServer;
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  final String? Function()? _ownerOverride;
  final Future<Map<String, dynamic>> Function()? _refreshOverride;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      _retryOverride;
  FirebaseFirestore get _firestore => _db ?? FirebaseFirestore.instance;
  FirebaseFunctions get _callable =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast1');
  String _owner() {
    final uid = _ownerOverride != null
        ? _ownerOverride()
        : (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) throw StateError('sign_in_required');
    return uid;
  }

  final _updates = StreamController<CareContinuityState>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _watch;
  CareContinuityState? _latest;
  String? _watchedOwner;
  Future<CareContinuityState>? _inFlight;
  bool _refreshAgain = false;
  int _listeners = 0;
  Object? _lastStamp;
  @override
  Future<CareContinuityState> refresh() {
    final running = _inFlight;
    if (running != null) return running;
    final future = _readServer();
    _inFlight = future;
    unawaited(future.then((_) => _finishRefresh(),
        onError: (Object _, StackTrace __) => _finishRefresh()));
    return future;
  }

  void _finishRefresh() {
    _inFlight = null;
    if (_refreshAgain) {
      _refreshAgain = false;
      unawaited(refresh().then((_) {}, onError: (Object _, StackTrace __) {}));
    }
  }

  Future<CareContinuityState> _readServer() async {
    try {
      final owner = _owner();
      final read = _refreshOverride;
      final data = read != null
          ? await read()
          : (await _callable.httpsCallable('refreshCareContinuity').call())
              .data;
      if (owner != _owner()) {
        throw StateError('owner_changed');
      }
      final state =
          CareContinuityState.fromMap(Map<String, dynamic>.from(data as Map));
      _latest = state;
      _updates.add(state);
      return state;
    } catch (error, stack) {
      _latest = null;
      if (_updates.hasListener) {
        _updates.addError(error, stack);
      }
      rethrow;
    }
  }

  void _startWatch() {
    final owner = _owner();
    if (_watch != null && _watchedOwner == owner) return;
    unawaited(_watch?.cancel());
    _latest = null;
    _watchedOwner = owner;
    _lastStamp = null;
    _watch = _firestore
        .doc('users/$owner/rewards/continuity')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        return;
      }
      final stamp = snapshot.data()?['updatedAt'];
      if (stamp == _lastStamp) return;
      _lastStamp = stamp;
      if (_inFlight != null) {
        _refreshAgain = true;
        return;
      }
      unawaited(refresh().then((_) {}, onError: (Object _, StackTrace __) {}));
    }, onError: (Object error, StackTrace stack) {
      _latest = null;
      if (_updates.hasListener) {
        _updates.addError(error, stack);
      }
    });
  }

  @override
  Stream<CareContinuityState> watch() => Stream.multi((sink) {
        final subscription =
            _updates.stream.listen(sink.add, onError: sink.addError);
        _listeners++;
        try {
          _startWatch();
          if (_latest != null) sink.add(_latest!);
          unawaited(
              refresh().then((_) {}, onError: (Object _, StackTrace __) {}));
        } catch (error, stack) {
          sink.addError(error, stack);
        }
        sink.onCancel = () async {
          await subscription.cancel();
          _listeners--;
          if (_listeners == 0) {
            await _watch?.cancel();
            _watch = null;
          }
        };
      });
  @override
  Future<List<CareContinuityDay>> calendar(
      {String? startDateKey, String? endDateKey}) async {
    final owner = _owner();
    Query<Map<String, dynamic>> query =
        _firestore.collection('users/$owner/continuity_days');
    if (startDateKey != null || endDateKey != null) {
      if (startDateKey == null ||
          endDateKey == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(startDateKey) ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(endDateKey) ||
          startDateKey.compareTo(endDateKey) > 0) {
        throw ArgumentError('Invalid calendar interval');
      }
      query = query
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateKey)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDateKey);
    } else {
      query = query.limit(60);
    }
    final result = await query
        .orderBy(FieldPath.documentId, descending: startDateKey == null)
        .get(const GetOptions(source: Source.server));
    if (owner != _owner()) throw StateError('owner_changed');
    return List.unmodifiable(result.docs
        .map((doc) => CareContinuityDay.fromMap(doc.data(), id: doc.id)));
  }

  @override
  Future<CareRewardRetryResult> retryCareReward(
      {required String dayKey, required String mutationId}) async {
    final owner = _owner();
    final payload = {'dayKey': dayKey, 'mutationId': mutationId};
    final retry = _retryOverride;
    final data = retry != null
        ? await retry(payload)
        : (await _callable
                .httpsCallable('retryDailyCareActionReward')
                .call(payload))
            .data;
    if (owner != _owner()) throw StateError('owner_changed');
    final reply = data as Map;
    final reward = reply['reward'];
    final continuity = reply['continuity'];
    if (continuity is Map) {
      final state =
          CareContinuityState.fromMap(Map<String, dynamic>.from(continuity));
      _latest = state;
      if (_updates.hasListener) {
        _updates.add(state);
      }
    }
    return CareRewardRetryResult(
      status:
          reward is Map ? reward['status'] as String? ?? 'failed' : 'failed',
      confirmationPending:
          continuity is Map && continuity['confirmationPending'] == true,
    );
  }
}
