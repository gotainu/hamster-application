import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/app_analytics.dart';

enum LegacyFirstReportPhase { loading, missing, available, unavailable }

class LegacyFirstReportState {
  final String? ownerUid;
  final LegacyFirstReportPhase phase;
  final Map<String, dynamic>? report;
  const LegacyFirstReportState.loading(this.ownerUid)
      : phase = LegacyFirstReportPhase.loading,
        report = null;
  const LegacyFirstReportState.missing(this.ownerUid)
      : phase = LegacyFirstReportPhase.missing,
        report = null;
  const LegacyFirstReportState.unavailable(this.ownerUid)
      : phase = LegacyFirstReportPhase.unavailable,
        report = null;
  const LegacyFirstReportState.available(this.ownerUid, this.report)
      : phase = LegacyFirstReportPhase.available;
}

abstract interface class LegacyFirstReportSource {
  String? get currentUid;
  Stream<LegacyFirstReportState> watchFirstReport();
}

/// A small owner-bound reader for the existing frozen first document. Cache
/// absence is not treated as a server-confirmed missing report.
class _LegacyFirstReportRepo implements LegacyFirstReportSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  @override
  String? get currentUid => _auth.currentUser?.uid;
  @override
  Stream<LegacyFirstReportState> watchFirstReport() {
    late StreamController<LegacyFirstReportState> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? reportSub;
    String? owner;
    var bound = false;
    var version = 0;
    var cancelled = false;
    void add(LegacyFirstReportState state) {
      if (!cancelled) controller.add(state);
    }

    void bind(String? uid) {
      if (cancelled || (bound && owner == uid)) return;
      bound = true;
      owner = uid;
      final generation = ++version;
      unawaited(reportSub?.cancel());
      reportSub = null;
      add(LegacyFirstReportState.loading(uid));
      if (uid == null) {
        add(const LegacyFirstReportState.unavailable(null));
        return;
      }
      reportSub = _db
          .collection('users')
          .doc(uid)
          .collection('personalized_reports')
          .doc('first')
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
        if (cancelled || generation != version || currentUid != uid) return;
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          add(LegacyFirstReportState.loading(uid));
          return;
        }
        final data = snapshot.data();
        add(data == null
            ? LegacyFirstReportState.missing(uid)
            : LegacyFirstReportState.available(uid, data));
      }, onError: (Object error, StackTrace stack) {
        if (!cancelled && generation == version) {
          add(LegacyFirstReportState.unavailable(uid));
        }
      });
    }

    controller = StreamController<LegacyFirstReportState>(onListen: () {
      authSub = _auth.authStateChanges().listen((user) => bind(user?.uid),
          onError: (Object error, StackTrace stack) {
        version++;
        unawaited(reportSub?.cancel());
        add(LegacyFirstReportState.unavailable(owner));
      });
      bind(currentUid);
    }, onCancel: () async {
      cancelled = true;
      version++;
      await Future.wait([
        if (authSub != null) authSub!.cancel(),
        if (reportSub != null) reportSub!.cancel()
      ]);
    });
    return controller.stream;
  }
}

class PersonalizedReportScreen extends StatefulWidget {
  const PersonalizedReportScreen(
      {super.key,
      this.autoPresented = false,
      this.onReportViewed,
      this.source,
      this.logView,
      this.expectedOwnerUid});
  final bool autoPresented;
  final String? expectedOwnerUid;
  final FutureOr<void> Function()? onReportViewed;
  final LegacyFirstReportSource? source;
  final Future<void> Function(String ownerUid, int revision)? logView;
  @override
  State<PersonalizedReportScreen> createState() =>
      _PersonalizedReportScreenState();
}

class _PersonalizedReportScreenState extends State<PersonalizedReportScreen> {
  late LegacyFirstReportSource _source;
  late Stream<LegacyFirstReportState> _stream;
  LegacyFirstReportState? _current;
  String? _loggedPresentationKey;
  final _scheduled = <String>{};
  int _readVersion = 0;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _source = widget.source ?? _LegacyFirstReportRepo();
    _stream = _source.watchFirstReport();
  }

  @override
  void didUpdateWidget(covariant PersonalizedReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.expectedOwnerUid != widget.expectedOwnerUid) {
      _readVersion++;
      _current = null;
      _bind();
    }
  }

  void _retry() => setState(() {
        _readVersion++;
        _current = null;
        _stream = _source.watchFirstReport();
      });
  void _logDisplayed(LegacyFirstReportState state) {
    final owner = state.ownerUid;
    final report = state.report!;
    final revision = (report['analysisRevision'] as num?)?.toInt() ?? 1;
    final generation = report['generation'] as Map;
    final key = '$owner:main_pet:first:$revision:${generation['generatedAt']}';
    final readVersion = _readVersion;
    final route = ModalRoute.of(context);
    if (owner == null ||
        _loggedPresentationKey == key ||
        _scheduled.contains(key)) {
      return;
    }
    _scheduled.add(key);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool current() {
        final displayed = _current?.report;
        final displayedGeneration = displayed?['generation'];
        return mounted &&
            _readVersion == readVersion &&
            _current?.phase == LegacyFirstReportPhase.available &&
            _current?.ownerUid == owner &&
            displayed?['analysisRevision'] == report['analysisRevision'] &&
            displayedGeneration is Map &&
            displayedGeneration['generatedAt'] == generation['generatedAt'] &&
            _source.currentUid == owner &&
            (widget.expectedOwnerUid == null ||
                widget.expectedOwnerUid == owner) &&
            route?.isCurrent != false;
      }

      try {
        if (!current()) return;
        try {
          await widget.onReportViewed?.call();
        } catch (_) {}
        if (!current()) return;
        _loggedPresentationKey = key;
        if (widget.logView != null) {
          await widget.logView!(owner, revision);
        } else {
          await AppAnalytics.logAnalysisReportViewed(
              reportId: 'first',
              petId: 'main_pet',
              revision: revision,
              presentationId: '${DateTime.now().microsecondsSinceEpoch}',
              autoPresented: widget.autoPresented,
              expectedUserId: owner);
        }
      } finally {
        _scheduled.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('個体別コンディションレポート')),
      body: StreamBuilder<LegacyFirstReportState>(
          key: ValueKey(_readVersion),
          stream: _stream,
          builder: (context, snapshot) {
            final incoming = snapshot.hasError
                ? const LegacyFirstReportState.unavailable(null)
                : snapshot.data ?? const LegacyFirstReportState.loading(null);
            final initialLoading =
                incoming.phase == LegacyFirstReportPhase.loading &&
                    incoming.ownerUid == null;
            final state = widget.expectedOwnerUid == null ||
                    incoming.ownerUid == widget.expectedOwnerUid ||
                    initialLoading
                ? incoming
                : LegacyFirstReportState.unavailable(widget.expectedOwnerUid);
            _current = state;
            if (state.phase == LegacyFirstReportPhase.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.phase == LegacyFirstReportPhase.missing) {
              return const Center(child: Text('初回レポートはまだありません'));
            }
            if (state.phase == LegacyFirstReportPhase.unavailable ||
                state.ownerUid != _source.currentUid) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('レポートを取得できませんでした。'),
                TextButton(onPressed: _retry, child: const Text('再試行'))
              ]));
            }
            final report = state.report!;
            final generation = report['generation'];
            if (generation is! Map || generation['status'] != 'generated') {
              return const Center(child: Text('初回レポートを準備しています。'));
            }
            _logDisplayed(state);
            final metrics = (report['readyMetrics'] as List?)
                    ?.map((item) => item == 'body' ? '体重' : '活動量')
                    .join('・') ??
                '';
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text('初回レポート', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text('対象指標: $metrics'),
              Text('分析仕様: ${report['analysisSpecVersion'] ?? 'unknown'}'),
              Text('改訂: ${report['analysisRevision'] ?? 1}'),
              const SizedBox(height: 20),
              const Text('準備が整った指標だけを対象にした、読み取り専用の初回レポートです。'),
            ]);
          }));
}
