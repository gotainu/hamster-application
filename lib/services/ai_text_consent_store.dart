import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiTextConsentStorageFailure implements Exception {
  const AiTextConsentStorageFailure();

  @override
  String toString() => 'AI text consent storage is unavailable.';
}

/// A withdrawal invalidates a dialog or write which began before it.
class AiTextConsentChanged implements Exception {
  const AiTextConsentChanged();
}

/// Device-local permission, separate from authentication and AI entitlements.
class AiTextConsentStore {
  AiTextConsentStore({FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const FlutterSecureStorage(),
      _now = now ?? DateTime.now;

  static const disclosureVersion = '2026-10-25-v1';
  static const _providers = ['openai', 'pinecone'];
  static const _purposes = ['answer_generation', 'knowledge_search'];
  static final _operations = <String, Future<void>>{};
  static final _generations = <String, int>{};
  static final _revokedOwners = <String>{};

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  static String _key(String uid) => 'ai_text_processing_consent_v1_$uid';

  int generationFor(String uid) => _generations[uid] ?? 0;

  Future<T> _serial<T>(String uid, Future<T> Function() operation) {
    if (uid.trim().isEmpty) {
      return Future<T>.error(const AiTextConsentStorageFailure());
    }
    final previous = _operations[uid] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final done = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _operations[uid] = done;
    unawaited(
      done.then((_) {
        if (identical(_operations[uid], done)) _operations.remove(uid);
      }),
    );
    return result;
  }

  bool _matchesList(Object? value, List<String> expected) =>
      value is List &&
      value.length == expected.length &&
      List.generate(
        expected.length,
        (i) => value[i] == expected[i],
      ).every((matches) => matches);

  Future<bool> hasAccepted(String uid) => _serial(uid, () async {
    try {
      final value = await _storage.read(key: _key(uid));
      if (_revokedOwners.contains(uid) || value == null) return false;
      final record = jsonDecode(value);
      if (record is! Map) throw const AiTextConsentStorageFailure();
      return record['schemaVersion'] == 1 &&
          record['ownerUid'] == uid &&
          record['disclosureVersion'] == disclosureVersion &&
          record['accepted'] == true &&
          record['acceptedAtDeviceUtc'] is String &&
          DateTime.tryParse(record['acceptedAtDeviceUtc'] as String) != null &&
          _matchesList(record['providers'], _providers) &&
          _matchesList(record['purposes'], _purposes);
    } catch (_) {
      throw const AiTextConsentStorageFailure();
    }
  });

  Future<void> accept(String uid, {int? expectedGeneration}) {
    final generation = expectedGeneration ?? generationFor(uid);
    return _serial(uid, () async {
      if (generationFor(uid) != generation) throw const AiTextConsentChanged();
      try {
        await _storage.write(
          key: _key(uid),
          value: jsonEncode({
            'schemaVersion': 1,
            'ownerUid': uid,
            'disclosureVersion': disclosureVersion,
            'accepted': true,
            'providers': _providers,
            'purposes': _purposes,
            'acceptedAtDeviceUtc': _now().toUtc().toIso8601String(),
          }),
        );
      } catch (_) {
        throw const AiTextConsentStorageFailure();
      }
      if (generationFor(uid) != generation) throw const AiTextConsentChanged();
      _revokedOwners.remove(uid);
    });
  }

  Future<void> revoke(String uid) {
    _generations[uid] = generationFor(uid) + 1;
    _revokedOwners.add(uid);
    return _serial(uid, () async {
      try {
        await _storage.delete(key: _key(uid));
      } catch (_) {
        throw const AiTextConsentStorageFailure();
      }
    });
  }
}
